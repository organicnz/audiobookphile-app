import SwiftUI
#if os(iOS) && !SKIP
import LocalAuthentication
#endif

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
                            .foregroundStyle(.white)
                            .padding()
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.12))
                                    .frame(width: 88, height: 88)
                            )

                        Text("Two-Factor Authentication")
                            .font(.title2.bold())
                            .foregroundStyle(.white)

                        Text(methodDescription)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.75))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    if methodCount > 1 {
                        HStack(spacing: 10) {
                            if appState.pending2FAMethods?.biometric == true {
                                methodButton(title: "Biometric", method: "biometric", icon: "faceid")
                            }
                            if appState.pending2FAMethods?.pin == true {
                                methodButton(title: "PIN Code", method: "pin", icon: "lock")
                            }
                            if appState.pending2FAMethods?.totp == true || appState.pending2FAMethods == nil {
                                methodButton(title: "TOTP", method: "totp", icon: "candybarphone")
                            }
                        }
                        .padding(4)
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 32)
                    }

                    VStack(spacing: 16) {
                        if selectedMethod == "biometric" {
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
                                .foregroundStyle(.white)
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
                                .foregroundStyle(.white)
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
                                .foregroundStyle(.white)
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
                    .foregroundStyle(.white)
                }
            }
        }
        .onAppear {
            if let methods = appState.pending2FAMethods {
                if methods.biometric == true {
                    selectedMethod = "biometric"
                    Task {
                        await triggerBiometric()
                    }
                } else if methods.pin == true {
                    selectedMethod = "pin"
                    isInputFocused = true
                } else {
                    selectedMethod = "totp"
                    isInputFocused = true
                }
            } else {
                selectedMethod = "totp"
                isInputFocused = true
            }
        }
    }

    private var methodIconName: String {
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
        switch selectedMethod {
        case "biometric":
            return "Verify your identity using Face ID or Touch ID."
        case "pin":
            return "Enter your 4-8 digit numerical PIN code."
        default:
            return "Enter the 6-digit verification code from your authenticator app."
        }
    }

    private var methodCount: Int {
        var count = 0
        if appState.pending2FAMethods?.totp == true || appState.pending2FAMethods == nil { count += 1 }
        if appState.pending2FAMethods?.pin == true { count += 1 }
        if appState.pending2FAMethods?.biometric == true { count += 1 }
        return count
    }

    @ViewBuilder
    private func methodButton(title: String, method: String, icon: String) -> some View {
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
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .background(selectedMethod == method ? Color.accentColor : Color.clear)
            .foregroundStyle(.white)
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
        #if os(iOS) && !SKIP
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            do {
                let success = try await context.evaluatePolicy(
                    .deviceOwnerAuthenticationWithBiometrics,
                    localizedReason: "Authenticate to sign in to your Audiobookphile account."
                )
                if success {
                    isVerifying = true
                    errorMessage = nil
                    try await appState.verify2FAChallenge(code: "biometric", method: "biometric")
                    dismiss()
                }
            } catch {
                errorMessage = "Biometric authentication cancelled or failed. You may use PIN Code or TOTP."
                isVerifying = false
            }
        } else {
            errorMessage = "Biometric authentication is not available on this device."
        }
        #else
        errorMessage = "Biometric authentication is not supported in this environment."
        #endif
    }
}
