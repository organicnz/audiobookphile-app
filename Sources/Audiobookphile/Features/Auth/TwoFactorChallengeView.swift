import SwiftUI

public struct TwoFactorChallengeView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var code: String = ""
    @State private var errorMessage: String?
    @State private var isVerifying: Bool = false
    @FocusState private var isInputFocused: Bool

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                FluidAuraBackground()
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        Image(systemName: "shield.checkered")
                            .font(.system(size: 56, weight: .light))
                            .foregroundStyle(.white)
                            .padding()
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.12))
                                    .frame(width: 96, height: 96)
                            )

                        Text("Two-Factor Authentication")
                            .font(.title2.bold())
                            .foregroundStyle(.white)

                        Text("Enter the 6-digit verification code from your authenticator app.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    VStack(spacing: 16) {
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

                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(Color.red.opacity(0.9))
                        }

                        Button {
                            Task {
                                await verify()
                            }
                        } label: {
                            HStack {
                                if isVerifying {
                                    ProgressView()
                                        .tint(.white)
                                }
                                Text("Verify")
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
            isInputFocused = true
        }
    }

    private func verify() async {
        guard code.count == 6 else { return }
        isVerifying = true
        errorMessage = nil
        do {
            try await appState.verify2FAChallenge(code: code)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            isVerifying = false
        }
    }
}
