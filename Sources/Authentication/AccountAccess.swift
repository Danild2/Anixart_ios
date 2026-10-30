import Foundation
import Observation

enum AccountAccessMode: Sendable, Equatable { case registration, restore }
struct AuthChallengeResponse: ServiceResponse {
    let code: Int
    var hash: String?
    var codeLength: Int?
    var codeTimeLeft: Double?
    var codeTimestampExpires: Double?
    var timestampExpires: Double?
    var suggestedLogins: [String]?
    var inputLength: Int { codeLength.flatMap { (4...5).contains($0) ? $0 : nil } ?? 4 }
    func nextRequestDate(now: Date = Date()) -> Date {
        if let seconds = codeTimeLeft, seconds.isFinite { return now.addingTimeInterval(max(0, seconds)) }
        if let timestamp = codeTimestampExpires ?? timestampExpires, timestamp.isFinite { return max(now, Date(timeIntervalSince1970: timestamp)) }
        return now
    }
}

extension AnixartRepository {
    func beginAccess(mode: AccountAccessMode, login: String, email: String, password: String) async throws -> AuthChallengeResponse {
        let fields = mode == .registration ? ["login": login, "email": email, "password": password] : ["data": login]
        return try await client.request(Endpoint(path: mode == .registration ? "auth/signUp" : "auth/restore", method: "POST",
            body: APIClient.form(fields), contentType: "application/x-www-form-urlencoded", isReadOnly: false,
            headers: ["X-Long-Code":"1"], acceptedCodes: Set(0...11)))
    }
    func resendAccess(mode: AccountAccessMode, login: String, email: String, password: String, hash: String) async throws -> AuthChallengeResponse {
        let fields = mode == .registration ? ["login":login, "email":email, "password":password, "hash":hash] : ["data":login, "password":password, "hash":hash]
        return try await client.request(Endpoint(path: mode == .registration ? "auth/resend" : "auth/restore/resend", method: "POST",
            body: APIClient.form(fields), contentType: "application/x-www-form-urlencoded", isReadOnly: false, headers: ["X-Long-Code":"1"]))
    }
    func verifyAccess(mode: AccountAccessMode, login: String, email: String, password: String, hash: String, code: String) async throws -> LoginResponse {
        let fields = mode == .registration ? ["login":login, "email":email, "password":password, "hash":hash, "code":code] : ["data":login, "password":password, "hash":hash, "code":code]
        return try await client.request(Endpoint(path: mode == .registration ? "auth/verify" : "auth/restore/verify", method: "POST",
            body: APIClient.form(fields), contentType: "application/x-www-form-urlencoded", isReadOnly: false))
    }
}

@MainActor @Observable final class AccountAccess {
    let mode: AccountAccessMode
    var login = ""
    var email = ""
    var password = ""
    var repeatedPassword = ""
    var termsAccepted = false
    var disseminationAccepted = false
    var code = ""
    private(set) var challenge: AuthChallengeResponse?
    private(set) var busy = false
    private(set) var error: String?
    private(set) var suggestions: [String] = []
    private(set) var retryAt = Date.distantPast
    init(mode: AccountAccessMode) { self.mode = mode }
    var canStart: Bool {
        !busy && !login.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !password.isEmpty && password == repeatedPassword
            && (mode == .restore || (!email.isEmpty && termsAccepted && disseminationAccepted))
    }
    var canVerify: Bool { !busy && challenge != nil && code.count == challenge?.inputLength && code.allSatisfy { "0123456789".contains($0) } }
    func start(repository: AnixartRepository) async {
        guard canStart else { return }
        busy = true; error = nil; suggestions = []
        defer { busy = false }
        login = login.trimmingCharacters(in: .whitespacesAndNewlines); email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let response = try await repository.beginAccess(mode: mode, login: login, email: email, password: password)
            try Task.checkCancellation()
            suggestions = response.suggestedLogins ?? []
            guard response.code == 0 || response.code == (mode == .registration ? 7 : 3) else { throw APIError.service(response.code) }
            guard let hash = response.hash, !hash.isEmpty else { throw APIError.malformed }
            challenge = response; retryAt = response.nextRequestDate(); code = ""
        } catch is CancellationError { }
        catch { self.error = message(error, operation: .start) }
    }
    func verify(repository: AnixartRepository, session: SessionStore) async -> Bool {
        guard canVerify, let hash = challenge?.hash else { return false }
        busy = true; error = nil
        defer { busy = false }
        do {
            let response = try await repository.verifyAccess(mode: mode, login: login, email: email, password: password, hash: hash, code: code)
            try Task.checkCancellation()
            try session.accept(response); clearSecrets(); return true
        } catch is CancellationError { return false }
        catch { self.error = message(error, operation: .verify); return false }
    }
    func resend(repository: AnixartRepository, now: Date = Date()) async {
        guard !busy, now >= retryAt, let hash = challenge?.hash else { return }
        busy = true; error = nil
        defer { busy = false }
        do {
            let response = try await repository.resendAccess(mode: mode, login: login, email: email, password: password, hash: hash)
            try Task.checkCancellation()
            retryAt = response.nextRequestDate(); code = ""
            if let length = response.codeLength { challenge?.codeLength = length }
        } catch is CancellationError { }
        catch { self.error = message(error, operation: .resend) }
    }
    func editDetails() { guard !busy else { return }; challenge = nil; code = ""; error = nil }
    func clearSecrets() { password = ""; repeatedPassword = ""; code = ""; challenge = nil }
    private enum Operation { case start, verify, resend }
    private func message(_ error: Error, operation: Operation) -> String {
        guard case APIError.service(let code) = error else { return error.localizedDescription }
        let keys: [Int: String]
        switch (mode, operation) {
        case (.registration, .start): keys = [2:"error_login_invalid",3:"error_email_invalid",4:"error_password_invalid",5:"error_login_already_taken",6:"error_email_already_taken",8:"error_code_cannot_send",9:"error_email_service_disallowed",10:"error_too_many_registrations"]
        case (.registration, .verify): keys = [2:"error_login_invalid",3:"error_email_invalid",4:"error_password_invalid",5:"error_login_already_taken",6:"error_email_already_taken",7:"error_code_invalid",8:"error_code_expired",9:"error_hash_invalid",10:"error_email_service_disallowed",11:"error_too_many_registrations"]
        case (.registration, .resend): keys = [2:"error_login_invalid",3:"error_email_invalid",4:"error_password_invalid",5:"error_hash_invalid",6:"error_code_cannot_send"]
        case (.restore, .start): keys = [2:"error_profile_not_found",4:"error_code_cannot_send"]
        case (.restore, .verify): keys = [2:"error_profile_not_found",3:"error_password_invalid",4:"error_code_invalid",5:"error_code_expired",6:"error_hash_invalid"]
        case (.restore, .resend): keys = [2:"error_profile_not_found",3:"error_hash_invalid",4:"error_code_cannot_send"]
        }
        return keys[code].map(OriginalCopy.text) ?? error.localizedDescription
    }
}
