import SwiftUI
#if os(iOS)
import AVKit
#endif

/// A native AirPlay button utilizing AVRoutePickerView on iOS
public struct AirPlayButton: View {
    let color: Color
    let size: CGFloat

    public init(color: Color = .primary, size: CGFloat = 40) {
        self.color = color
        self.size = size
    }

    public var body: some View {
        #if os(iOS) && !SKIP
        AVRoutePickerViewWrapper(tintColor: UIColor(color))
            .frame(width: size, height: size)
            .accessibilityLabel("AirPlay")
        #else
        // Fallback for Android/Skip compilation
        Image(systemName: "airplayaudio")
            .font(.title2)
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .opacity(0.5)
            .accessibilityLabel("AirPlay")
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
