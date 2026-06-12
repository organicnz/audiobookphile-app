import SwiftUI
#if os(iOS)
import AVKit
#endif

/// A native AirPlay button utilizing AVRoutePickerView on iOS
public struct AirPlayButton: View {
    let color: Color

    public init(color: Color = .primary) {
        self.color = color
    }

    public var body: some View {
        #if os(iOS) && !SKIP
        AVRoutePickerViewWrapper(tintColor: UIColor(color))
            .frame(width: 44, height: 44)
        #else
        // Fallback for Android/Skip compilation
        Image(systemName: "airplayaudio")
            .font(.title2)
            .foregroundStyle(color)
            .frame(width: 44, height: 44)
            .opacity(0.5)
        #endif
    }
}

#if os(iOS) && !SKIP
private struct AVRoutePickerViewWrapper: UIViewRepresentable {
    let tintColor: UIColor

    func makeUIView(context: Context) -> AVRoutePickerView {
        let routePickerView = AVRoutePickerView()
        routePickerView.backgroundColor = .clear
        routePickerView.activeTintColor = tintColor
        routePickerView.tintColor = tintColor
        return routePickerView
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        uiView.activeTintColor = tintColor
        uiView.tintColor = tintColor
    }
}
#endif
