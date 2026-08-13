import SwiftUI
#if os(iOS) && !SKIP
import UIKit
#endif

public struct TwoFactorSettingsView: View {
    @State private var mode: Mode = .idle
    @State private var secret: String = ""
    @State private var uri: String = ""
    @State private var verificationCode: String = ""
    @State private var disableCode: String = ""
    @State private var disablePin: String = ""
    @State private var pinInput: String = ""
    @State private var is2faEnabled: Bool = false
    @State private var isLoading: Bool = true
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var copied: Bool = false

    enum Mode {
        case idle
        case enrolling
        case enrollingPin
        case disabling
    }

    public init() {}

    public var body: some View {
        ZStack {
            FluidAuraBackground()

            ScrollView {
                VStack(spacing: 24) {
                    headerCard

                    if let successMessage = successMessage {
                        Text(successMessage)
                            .font(.subheadline.bold())
                            .foregroundStyle(Color.green)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.green.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(Color.red.opacity(0.9))
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    if isLoading {
                        ProgressView()
                            .tint(.white)
                            .padding()
                    } else if mode == .enrolling {
                        enrollmentCard
                    } else if mode == .enrollingPin {
                        enrollingPinCard
                    } else if mode == .disabling {
                        disablingCard
                    } else {
                        statusCard
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
        }
        .navigationTitle("Two-Factor Auth")
        #if os(iOS) || SKIP
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            await loadStatus()
        }
    }

    private var headerCard: some View {
        VStack(spacing: 12) {
            Image(systemName: is2faEnabled ? "shield.fill" : "shield.slash")
                .font(.system(size: 40))
                .foregroundStyle(is2faEnabled ? Color.green : Color.orange)
                .padding()
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.1))
                )

            Text(is2faEnabled ? "Multi-Factor Authentication is ON" : "Multi-Factor Authentication is OFF")
                .font(.headline.bold())
                .foregroundStyle(.white)

            Text("Protect your account by requiring an authenticator app, PIN code, or facial biometric verification when signing in.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }

    private var statusCard: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                Button {
                    errorMessage = nil
                    successMessage = nil
                    Task { await startEnrollment() }
                } label: {
                    HStack {
                        Image(systemName: "candybarphone")
                        Text("Set Up Authenticator (TOTP)")
                            .font(.headline.bold())
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(isSubmitting)

                Button {
                    errorMessage = nil
                    successMessage = nil
                    pinInput = ""
                    withAnimation { mode = .enrollingPin }
                } label: {
                    HStack {
                        Image(systemName: "lock.shield")
                        Text("Set Up PIN Code Sign-In")
                            .font(.headline.bold())
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(isSubmitting)

                Button {
                    errorMessage = nil
                    successMessage = nil
                    Task { await enrollBiometric() }
                } label: {
                    HStack {
                        if isSubmitting {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "faceid")
                        }
                        Text("Enable Facial 2FA / Biometrics")
                            .font(.headline.bold())
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(isSubmitting)
            }

            if is2faEnabled {
                Button {
                    errorMessage = nil
                    successMessage = nil
                    withAnimation { mode = .disabling }
                } label: {
                    Text("Disable All 2FA Methods...")
                        .font(.headline)
                        .foregroundStyle(Color.red)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.top, 8)
            }
        }
    }

    private var enrollmentCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("1. Add Secret Key to Authenticator")
                .font(.headline)
                .foregroundStyle(.white)

            Text("Copy the secret key below and add it to your authenticator app (such as 1Password, Authy, or Google Authenticator):")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))

            HStack {
                Text(secret)
                    .font(.system(.body, design: .monospaced).bold())
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                Button {
                    #if os(iOS) && !SKIP
                    UIPasteboard.general.string = secret
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    #endif
                    withAnimation { copied = true }
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        withAnimation { copied = false }
                    }
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.subheadline)
                        .foregroundStyle(copied ? .green : .white)
                        .padding(8)
                        .background(Color.white.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding()
            .background(Color.black.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Divider().background(Color.white.opacity(0.2))

            Text("2. Verify 6-Digit Code")
                .font(.headline)
                .foregroundStyle(.white)

            TextField("000000", text: $verificationCode)
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .multilineTextAlignment(.center)
                #if os(iOS) || SKIP
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                #endif
                .padding()
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .onChange(of: verificationCode) { _, newValue in
                    let filtered = newValue.filter { $0.isNumber }
                    if filtered.count > 6 {
                        verificationCode = String(filtered.prefix(6))
                    } else {
                        verificationCode = filtered
                    }
                    errorMessage = nil
                }

            HStack(spacing: 12) {
                Button("Cancel") {
                    withAnimation {
                        mode = .idle
                        verificationCode = ""
                        errorMessage = nil
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.white.opacity(0.15))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Button {
                    Task { await confirmEnrollment() }
                } label: {
                    HStack {
                        if isSubmitting {
                            ProgressView().tint(.white)
                        }
                        Text("Activate 2FA")
                            .bold()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(verificationCode.count == 6 ? Color.green : Color.gray.opacity(0.4))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(verificationCode.count != 6 || isSubmitting)
            }
        }
        .padding()
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }

    private var enrollingPinCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Set Up 4-8 Digit PIN Code")
                .font(.headline)
                .foregroundStyle(.white)

            Text("Enter a numerical PIN code below to use as a sign-in alternative during two-factor authentication:")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))

            TextField("••••••••", text: $pinInput)
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .multilineTextAlignment(.center)
                #if os(iOS) || SKIP
                .keyboardType(.numberPad)
                #endif
                .padding()
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .onChange(of: pinInput) { _, newValue in
                    let filtered = newValue.filter { $0.isNumber }
                    if filtered.count > 8 {
                        pinInput = String(filtered.prefix(8))
                    } else {
                        pinInput = filtered
                    }
                    errorMessage = nil
                }

            HStack(spacing: 12) {
                Button("Cancel") {
                    withAnimation {
                        mode = .idle
                        pinInput = ""
                        errorMessage = nil
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.white.opacity(0.15))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Button {
                    Task { await confirmEnrollPin() }
                } label: {
                    HStack {
                        if isSubmitting {
                            ProgressView().tint(.white)
                        }
                        Text("Save PIN")
                            .bold()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(pinInput.count >= 4 ? Color.green : Color.gray.opacity(0.4))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(pinInput.count < 4 || isSubmitting)
            }
        }
        .padding()
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }

    private var disablingCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Enter a 6-digit authenticator code and/or your PIN to disable all 2FA methods:")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))

            TextField("000000 (Optional)", text: $disableCode)
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .multilineTextAlignment(.center)
                #if os(iOS) || SKIP
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                #endif
                .padding()
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .onChange(of: disableCode) { _, newValue in
                    let filtered = newValue.filter { $0.isNumber }
                    if filtered.count > 6 {
                        disableCode = String(filtered.prefix(6))
                    } else {
                        disableCode = filtered
                    }
                    errorMessage = nil
                }

            TextField("•••• (Optional)", text: $disablePin)
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .multilineTextAlignment(.center)
                #if os(iOS) || SKIP
                .keyboardType(.numberPad)
                .textContentType(.password)
                #endif
                .padding()
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .onChange(of: disablePin) { _, newValue in
                    let filtered = newValue.filter { $0.isNumber }
                    if filtered.count > 8 {
                        disablePin = String(filtered.prefix(8))
                    } else {
                        disablePin = filtered
                    }
                    errorMessage = nil
                }

            HStack(spacing: 12) {
                Button("Cancel") {
                    withAnimation {
                        mode = .idle
                        disableCode = ""
                        disablePin = ""
                        errorMessage = nil
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.white.opacity(0.15))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Button {
                    Task { await confirmDisable() }
                } label: {
                    HStack {
                        if isSubmitting {
                            ProgressView().tint(.white)
                        }
                        Text("Disable All 2FA")
                            .bold()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isSubmitting)
            }
        }
        .padding()
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }

    private func loadStatus() async {
        isLoading = true
        do {
            let status = try await AudiobookphileAPI.shared.get2FAStatus()
            is2faEnabled = status.enabled
        } catch {
            print("[TwoFactorSettings] Failed to check status: \(error)")
        }
        isLoading = false
    }

    private func startEnrollment() async {
        isSubmitting = true
        errorMessage = nil
        do {
            let res = try await AudiobookphileAPI.shared.enroll2FA()
            if let secret = res.secret {
                self.secret = secret
                self.uri = res.uri ?? ""
                self.mode = .enrolling
            } else if let err = res.error {
                self.errorMessage = err
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }

    private func confirmEnrollment() async {
        guard verificationCode.count == 6 else { return }
        isSubmitting = true
        errorMessage = nil
        do {
            let res = try await AudiobookphileAPI.shared.verify2FA(code: verificationCode)
            if res.success == true {
                is2faEnabled = true
                mode = .idle
                verificationCode = ""
                successMessage = "Authenticator App (TOTP) enabled successfully."
            } else {
                errorMessage = res.error ?? "Invalid code"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }

    private func confirmEnrollPin() async {
        guard pinInput.count >= 4 else { return }
        isSubmitting = true
        errorMessage = nil
        do {
            let res = try await AudiobookphileAPI.shared.enroll2FAPin(pinCode: pinInput)
            if res.success == true {
                is2faEnabled = true
                mode = .idle
                pinInput = ""
                successMessage = "PIN Code sign-in enabled successfully."
            } else {
                errorMessage = res.error ?? "Failed to enroll PIN code."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }

    private func enrollBiometric() async {
        isSubmitting = true
        errorMessage = nil
        do {
            #if os(iOS) && !SKIP
            let options = try await AudiobookphileAPI.shared.webauthnRegisterOptions()

            guard let rp = options.rp, let user = options.user,
                  let challengeData = WebAuthnCodec.base64urlDecode(options.challenge),
                  let userIDData = WebAuthnCodec.base64urlDecode(user.id) else {
                throw WebAuthnError.invalidChallenge
            }

            let registration = try await WebAuthnManager.requestRegistration(
                request: PasskeyRegistrationRequest(
                    challenge: challengeData,
                    rpId: rp.id,
                    rpName: rp.name,
                    userID: userIDData,
                    userName: user.name,
                    displayName: user.displayName,
                    excludeCredentialIds: (options.excludeCredentials ?? []).compactMap { WebAuthnCodec.base64urlDecode($0.id) },
                    userVerification: options.authenticatorSelection?.userVerification ?? "preferred"
                )
            )

            let res = try await AudiobookphileAPI.shared.webauthnRegisterVerify(
                registration: registration,
                deviceName: UIDevice.current.name
            )
            if res.success == true {
                is2faEnabled = true
                successMessage = "Facial 2FA / Biometric passkey enabled successfully on this device."
            } else {
                errorMessage = res.error ?? "Failed to enable passkey sign-in."
            }
            #else
            errorMessage = "Passkeys are not supported on this device. Use TOTP or PIN Code instead."
            #endif
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }

    private func confirmDisable() async {
        isSubmitting = true
        errorMessage = nil
        do {
            let res = try await AudiobookphileAPI.shared.disable2FA(code: disableCode, pinCode: disablePin)
            if res.success == true {
                is2faEnabled = false
                mode = .idle
                disableCode = ""
                disablePin = ""
                successMessage = "All 2FA methods disabled successfully."
            } else {
                errorMessage = res.error ?? "Failed to disable 2FA."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }
}
