import Foundation
import Security
import Observation

struct UserSession: Codable, Sendable {
    let token: String
    var profile: Profile
}

protocol SessionVault {
    func read() throws -> Data?
    func write(_ data: Data) throws
    func delete() throws
}

struct KeychainVault: SessionVault {
    let service = "local.anixartport.client.session.v1"
    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
         kSecAttrAccount as String: "current-session"]
    }
    func read() throws -> Data? {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw VaultError(status: status) }
        return item as? Data
    }
    func write(_ data: Data) throws {
        let update = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let result = SecItemAdd(item as CFDictionary, nil)
            guard result == errSecSuccess else { throw VaultError(status: result) }
        } else if status != errSecSuccess { throw VaultError(status: status) }
    }
    func delete() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw VaultError(status: status) }
    }
    struct VaultError: LocalizedError {
        let status: OSStatus
        var errorDescription: String? { "Не удалось обратиться к защищённому хранилищу (\(status))." }
    }
}

@MainActor @Observable final class SessionStore {
    private(set) var session: UserSession?
    private(set) var busy = false
    var error: String?
    private let vault: any SessionVault
    var token: String? { session?.token }
    var identity: String { session.map { String($0.profile.id) } ?? "guest" }

    init(vault: any SessionVault = KeychainVault()) {
        self.vault = vault
        do {
            if let data = try vault.read() { session = try JSONDecoder().decode(UserSession.self, from: data) }
        } catch { self.error = "Не удалось восстановить сессию. \(error.localizedDescription)" }
    }
    func signIn(login: String, password: String, repository: AnixartRepository) async {
        guard !busy else { return }
        busy = true; error = nil
        defer { busy = false }
        do {
            let response = try await repository.signIn(login: login, password: password)
            guard let token = response.profileToken?.token, !token.isEmpty, let profile = response.profile else {
                throw APIError.malformed
            }
            let next = UserSession(token: token, profile: profile)
            try vault.write(JSONEncoder().encode(next))
            session = next
        } catch is CancellationError { }
        catch { self.error = error.localizedDescription }
    }
    func refresh(repository: AnixartRepository) async {
        guard let current = session else { return }
        do {
            let profile = try await repository.profile(current.profile.id, token: current.token)
            guard session?.token == current.token else { return }
            let next = UserSession(token: current.token, profile: profile)
            try vault.write(JSONEncoder().encode(next)); session = next
        } catch APIError.unauthorized { signOut() }
        catch is CancellationError { }
        catch { self.error = error.localizedDescription }
    }
    func signOut() {
        do { try vault.delete(); session = nil; error = nil }
        catch { self.error = error.localizedDescription }
    }
}
