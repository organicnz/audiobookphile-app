import SwiftUI

public struct TwoFactorChallengeView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var selectedMethod: String = "totp"
    @State private var code: String = ""
    @State private var pinCode: String = ""
    @State private var errorMessage: String?
    @State private var isVerifying: Bool = false
    @FocusState private var isInputFocused: Bool

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                FluidAuraBackground()

                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        Image(systemName: methodIconName)
                            .font(.system(size: 52, weight: .light))
                            .foregroundStyle(DesignTokens.Color.foreground)
                            .padding()
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.12))
                                    .frame(width: 88, height: 88)
                            )

                        Text("Two-Factor Authentication")
                            .font(.title2.bold())
                            .foregroundStyle(DesignTokens.Color.foreground)

                        Text(methodDescription)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.75))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    if !enrolledMethods.isEmpty {
                        HStack(spacing: 10) {
                            ForEach(enrolledMethods, id: \.self) { method in
                                methodButton(
                                    title: methodTitle(method),
                                    method: method,
                                    icon: methodIcon(method),
                                    enrolled: true
                                )
                            }
                        }
                        .padding(4)
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 32)
                    }

                    VStack(spacing: 16) {
                        if !hasAnyEnrolledMethod {
                            VStack(spacing: 12) {
                                Text("No two-factor methods are configured for this account.")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.75))
                                    .multilineTextAlignment(.center)

                                Text("Sign in with your password instead, then reconfigure 2FA in Settings.")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.55))
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.vertical, 24)
                        } else if !isEnrolled(selectedMethod) {
                            VStack(spacing: 12) {
                                Text(notSetupHint)
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.75))
                                    .multilineTextAlignment(.center)

                                Text("Enable it in Settings → Security")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.55))
                            }
                            .padding(.vertical, 24)
                        } else if selectedMethod == "biometric" {
                            Button {
                                Task {
                                    await triggerBiometric()
                                }
                            } label: {
                                HStack(spacing: 10) {
                                    if isVerifying {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Image(systemName: "faceid")
                                            .font(.title3)
                                    }
                                    Text("Authenticate with Facial 2FA")
                                        .font(.headline.bold())
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.accentColor)
                                .foregroundStyle(DesignTokens.Color.foreground)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .disabled(isVerifying)
                        } else if selectedMethod == "pin" {
                            TextField("••••••••", text: $pinCode)
                                .font(.system(size: 28, weight: .bold, design: .monospaced))
                                .multilineTextAlignment(.center)
                                #if os(iOS) || SKIP
                                .keyboardType(.numberPad)
                                #endif
                                .focused($isInputFocused)
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                                .onChange(of: pinCode) { _, newValue in
                                    let filtered = newValue.filter { $0.isNumber }
                                    if filtered.count > 8 {
                                        pinCode = String(filtered.prefix(8))
                                    } else {
                                        pinCode = filtered
                                    }
                                    errorMessage = nil
                                }

                            Button {
                                Task {
                                    await verifyPin()
                                }
                            } label: {
                                HStack {
                                    if isVerifying {
                                        ProgressView()
                                            .tint(.white)
                                    }
                                    Text("Verify PIN Code")
                                        .font(.headline.bold())
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(pinCode.count >= 4 ? Color.accentColor : Color.gray.opacity(0.4))
                                .foregroundStyle(DesignTokens.Color.foreground)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .disabled(pinCode.count < 4 || isVerifying)
                        } else {
                            TextField("000000", text: $code)
                                .font(.system(size: 28, weight: .bold, design: .monospaced))
                                .multilineTextAlignment(.center)
                                #if os(iOS) || SKIP
                                .keyboardType(.numberPad)
                                .textContentType(.oneTimeCode)
                                #endif
                                .focused($isInputFocused)
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                                .onChange(of: code) { _, newValue in
                                    let filtered = newValue.filter { $0.isNumber }
                                    if filtered.count > 6 {
                                        code = String(filtered.prefix(6))
                                    } else {
                                        code = filtered
                                    }
                                    errorMessage = nil
                                }

                            Button {
                                Task {
                                    await verifyTotp()
                                }
                            } label: {
                                HStack {
                                    if isVerifying {
                                        ProgressView()
                                            .tint(.white)
                                    }
                                    Text("Verify Code")
                                        .font(.headline.bold())
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(code.count == 6 ? Color.accentColor : Color.gray.opacity(0.4))
                                .foregroundStyle(DesignTokens.Color.foreground)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .disabled(code.count != 6 || isVerifying)
                        }

                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(Color.red.opacity(0.9))
                        }
                    }
                    .padding(.horizontal, 32)

                    Spacer()
                }
                .padding(.top, 40)
            }
            #if os(iOS) || SKIP
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        appState.cancel2FAChallenge()
                        dismiss()
                    }
                    .foregroundStyle(DesignTokens.Color.foreground)
                }
            }
        }
        .onAppear {
            // Prefer TOTP whenever it is set up. A method that is merely
            // suggested (not enrolled) must never be auto-selected.
            if isEnrolled("totp") {
                selectedMethod = "totp"
            } else if isEnrolled("pin") {
                selectedMethod = "pin"
            } else if isEnrolled("biometric") {
                selectedMethod = "biometric"
            } else {
                selectedMethod = ""
            }
            if selectedMethod != "biometric" && hasAnyEnrolledMethod {
                isInputFocused = true
            }
        }
    }

    private var methodIconName: String {
        guard hasAnyEnrolledMethod else { return "shield.slash" }
        switch selectedMethod {
        case "biometric":
            return "faceid"
        case "pin":
            return "lock.shield"
        default:
            return "shield.checkered"
        }
    }

    private var methodDescription: String {
        guard hasAnyEnrolledMethod else {
            return "No two-factor methods are configured for this account."
        }
        switch selectedMethod {
        case "biometric":
            return "Verify your identity using Face ID or Touch ID."
        case "pin":
            return "Enter your 4-8 digit numerical PIN code."
        default:
            return "Enter the 6-digit verification code from your authenticator app."
        }
    }

    private var notSetupHint: String {
        switch selectedMethod {
        case "biometric":
            return "Biometric 2FA is not set up yet."
        case "pin":
            return "A PIN code is not set up yet."
        default:
            return "TOTP 2FA is not set up yet."
        }
    }

    private func isEnrolled(_ method: String) -> Bool {
        switch method {
        case "biometric":
            return appState.pending2FAMethods?.biometric == true
        case "pin":
            return appState.pending2FAMethods?.pin == true
        default:
            // Fail closed: a method the server does not explicitly report as
            // enrolled must never be auto-selected or presented.
            return appState.pending2FAMethods?.totp == true
        }
    }

    private var hasAnyEnrolledMethod: Bool {
        isEnrolled("totp") || isEnrolled("pin") || isEnrolled("biometric")
    }

    private var enrolledMethods: [String] {
        var methods: [String] = []
        if isEnrolled("totp") { methods.append("totp") }
        if isEnrolled("pin") { methods.append("pin") }
        if isEnrolled("biometric") { methods.append("biometric") }
        return methods
    }

    private func methodTitle(_ method: String) -> String {
        switch method {
        case "biometric": return "Biometric"
        case "pin": return "PIN Code"
        default: return "TOTP"
        }
    }

    private func methodIcon(_ method: String) -> String {
        switch method {
        case "biometric": return "faceid"
        case "pin": return "lock"
        default: return "candybarphone"
        }
    }

    @ViewBuilder
    private func methodButton(title: String, method: String, icon: String, enrolled: Bool) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedMethod = method
                errorMessage = nil
            }
            if method != "biometric" {
                isInputFocused = true
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption.bold())
                if !enrolled {
                    Text("Set up")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .background(selectedMethod == method ? Color.accentColor : Color.clear)
            .foregroundStyle(selectedMethod == method ? .white : (enrolled ? .white : .white.opacity(0.55)))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func verifyTotp() async {
        guard code.count == 6 else { return }
        isVerifying = true
        errorMessage = nil
        do {
            try await appState.verify2FAChallenge(code: code, method: "totp")
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            isVerifying = false
        }
    }

    private func verifyPin() async {
        guard pinCode.count >= 4 else { return }
        isVerifying = true
        errorMessage = nil
        do {
            try await appState.verify2FAChallenge(code: pinCode, method: "pin")
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            isVerifying = false
        }
    }

    private func triggerBiometric() async {
        isVerifying = true
        errorMessage = nil
        do {
            try await appState.verify2FAPasskey()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            isVerifying = false
        }
    }
}
