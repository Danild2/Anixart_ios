import SwiftUI
import Foundation

struct AccountAccessScreen: View {
    @Environment(\.repository) private var repository
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionStore.self) private var session
    @State private var flow: AccountAccess
    @State private var action: Task<Void, Never>?
    init(mode: AccountAccessMode) { _flow = State(initialValue: AccountAccess(mode: mode)) }
    var body: some View {
        @Bindable var flow = flow
        Form {
            if flow.challenge != nil {
                Section {
                    Text(OriginalCopy.format(flow.mode == .registration ? "auth_verify_code_sent_to" : "auth_verify_code_sent_to_profile", flow.mode == .registration ? flow.email : flow.login))
                    TextField(OriginalCopy.text("verification_code_hint"), text: $flow.code)
                        .keyboardType(.numberPad).textContentType(.oneTimeCode).disabled(flow.busy)
                        .accessibilityIdentifier("authVerificationCode")
                    Button(OriginalCopy.text("confirm")) {
                        action = Task { if await flow.verify(repository: repository, session: session) { dismiss() } }
                    }.disabled(!flow.canVerify)
                }
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let remaining = max(0, Int(ceil(flow.retryAt.timeIntervalSince(context.date))))
                    Button {
                        action = Task { await flow.resend(repository: repository) }
                    } label: {
                        HStack {
                            Text(OriginalCopy.text("auth_code_resend_action"))
                            Spacer()
                            if remaining > 0 { Text(String(format: "%d:%02d", remaining / 60, remaining % 60)).monospacedDigit() }
                        }
                    }.disabled(flow.busy || remaining > 0)
                }
                Button("Изменить данные") { flow.editDetails() }.disabled(flow.busy)
            } else {
                Section {
                    TextField(OriginalCopy.text(flow.mode == .registration ? "login" : "auth_email_or_nickname"), text: $flow.login)
                        .textContentType(.username).textInputAutocapitalization(.never).autocorrectionDisabled()
                    if flow.mode == .registration {
                        TextField(OriginalCopy.text("email"), text: $flow.email)
                            .keyboardType(.emailAddress).textContentType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                    }
                    SecureField(OriginalCopy.text(flow.mode == .registration ? "password" : "new_password"), text: $flow.password).textContentType(.newPassword)
                    SecureField(OriginalCopy.text("repeat_password"), text: $flow.repeatedPassword).textContentType(.newPassword)
                    if !flow.repeatedPassword.isEmpty && flow.password != flow.repeatedPassword {
                        Text(OriginalCopy.text("error_password_mismatch")).foregroundStyle(.red)
                    }
                }.disabled(flow.busy)
                if !flow.suggestions.isEmpty {
                    Section(OriginalCopy.text("login_suggestions_title")) {
                        ForEach(flow.suggestions, id: \.self) { login in Button(login) { flow.login = login } }
                    }
                }
                if flow.mode == .registration {
                    Section {
                        Toggle(OriginalCopy.text("auth_registration_terms_consent"), isOn: $flow.termsAccepted)
                            .accessibilityIdentifier("termsConsent")
                        Toggle(OriginalCopy.text("auth_registration_dissemination_consent"), isOn: $flow.disseminationAccepted)
                            .accessibilityIdentifier("disseminationConsent")
                        Link(OriginalCopy.text("auth_link_terms_nominative"), destination: URL(string: "https://anixart-app.com/terms")!)
                        Link(OriginalCopy.text("auth_link_privacy_dative"), destination: URL(string: "https://anixart-app.com/privacy")!)
                        Link(OriginalCopy.text("auth_link_personal_data_processing_consent"), destination: URL(string: "https://anixart-app.com/consent")!)
                        Link(OriginalCopy.text("auth_link_personal_data_dissemination_consent"), destination: URL(string: "https://anixart-app.com/consent-dissemination")!)
                    }.font(.footnote).disabled(flow.busy)
                }
                Button(OriginalCopy.text(flow.mode == .registration ? "create_profile" : "text_continue")) {
                    action = Task { await flow.start(repository: repository) }
                }.disabled(!flow.canStart).accessibilityIdentifier("beginAccountAccess")
            }
            if flow.busy { ProgressView() }
            if let error = flow.error { Text(error).foregroundStyle(.red).accessibilityIdentifier("accountAccessError") }
        }.navigationTitle(OriginalCopy.text(flow.challenge != nil ? "auth_verify_email" : (flow.mode == .registration ? "create_profile" : "title_password_restore")))
            .onDisappear { action?.cancel(); flow.clearSecrets() }
    }
}
