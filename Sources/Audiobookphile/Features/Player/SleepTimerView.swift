import SwiftUI

public struct SleepTimerView: View {
    @Environment(\.dismiss) var dismiss

    // Using simple options for now, this can integrate with AudioPlayerViewModel
    public let onSetTimer: (TimeInterval?) -> Void
    public let onSetEndOfChapter: () -> Void

    public init(onSetTimer: @escaping (TimeInterval?) -> Void, onSetEndOfChapter: @escaping () -> Void) {
        self.onSetTimer = onSetTimer
        self.onSetEndOfChapter = onSetEndOfChapter
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                FluidAuraBackground()

                List {
                Section {
                    Button {
                        onSetTimer(nil)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                                .font(.body)
                            Text("Off")
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                    }
                }

                Section {
                    Button {
                        onSetTimer(15 * 60)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "clock.fill")
                                .foregroundStyle(Color.appPrimary)
                                .font(.body)
                            Text("15 Minutes")
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                    }

                    Button {
                        onSetTimer(30 * 60)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "clock.fill")
                                .foregroundStyle(Color.appPrimary)
                                .font(.body)
                            Text("30 Minutes")
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                    }

                    Button {
                        onSetTimer(60 * 60)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "clock.fill")
                                .foregroundStyle(Color.appPrimary)
                                .font(.body)
                            Text("60 Minutes")
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                    }
                } header: {
                    Text("Time")
                }

                Section {
                    Button {
                        onSetEndOfChapter()
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "moon.zzz.fill")
                                .foregroundStyle(.indigo)
                                .font(.body)
                            Text("End of Chapter")
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Sleep Timer")
            #if os(iOS) || SKIP
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            // iOS 27 Toolbar Styling
            .applyToolbarAdapters(isLight: false, isHidden: false)
            }
        }
    }
}
