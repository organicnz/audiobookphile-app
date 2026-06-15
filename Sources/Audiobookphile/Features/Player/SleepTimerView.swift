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
            List {
                Section {
                    Button {
                        onSetTimer(nil)
                        dismiss()
                    } label: {
                        Text("Off")
                            .foregroundStyle(.primary)
                    }
                }
                
                Section {
                    Button {
                        onSetTimer(15 * 60)
                        dismiss()
                    } label: {
                        Text("15 Minutes")
                            .foregroundStyle(.primary)
                    }
                    
                    Button {
                        onSetTimer(30 * 60)
                        dismiss()
                    } label: {
                        Text("30 Minutes")
                            .foregroundStyle(.primary)
                    }
                    
                    Button {
                        onSetTimer(60 * 60)
                        dismiss()
                    } label: {
                        Text("60 Minutes")
                            .foregroundStyle(.primary)
                    }
                } header: {
                    Text("Time")
                }
                
                Section {
                    Button {
                        onSetEndOfChapter()
                        dismiss()
                    } label: {
                        Text("End of Chapter")
                            .foregroundStyle(.primary)
                    }
                }
            }
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
