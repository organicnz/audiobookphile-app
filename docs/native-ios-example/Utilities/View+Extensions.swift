//
//  View+Extensions.swift
//  AudiobookshelfClient
//
//  SwiftUI View extensions and modifiers
//

import SwiftUI

// MARK: - Conditional Modifier

extension View {
    /// Apply a modifier conditionally
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    /// Apply a modifier conditionally with else clause
    @ViewBuilder
    func `if`<TrueContent: View, FalseContent: View>(
        _ condition: Bool,
        if ifTransform: (Self) -> TrueContent,
        else elseTransform: (Self) -> FalseContent
    ) -> some View {
        if condition {
            ifTransform(self)
        } else {
            elseTransform(self)
        }
    }

    /// Apply a modifier if value is not nil
    @ViewBuilder
    func ifLet<Value, Content: View>(_ value: Value?, transform: (Self, Value) -> Content) -> some View {
        if let value = value {
            transform(self, value)
        } else {
            self
        }
    }
}

// MARK: - Haptic Feedback

extension View {
    /// Trigger haptic feedback on tap
    func hapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) -> some View {
        self.simultaneousGesture(
            TapGesture().onEnded { _ in
                UIImpactFeedbackGenerator(style: style).impactOccurred()
            }
        )
    }

    /// Trigger selection haptic
    func selectionHaptic() -> some View {
        self.simultaneousGesture(
            TapGesture().onEnded { _ in
                UISelectionFeedbackGenerator().selectionChanged()
            }
        )
    }
}

// MARK: - Glass Effects

extension View {

    /// Apply glass shadow
    func glassShadow() -> some View {
        self.shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
    }

    /// Apply inner glow effect
    func innerGlow(color: Color = .white, radius: CGFloat = 10) -> some View {
        self.overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.2), lineWidth: 1)
                .blur(radius: radius)
                .mask(self)
        }
    }
}

// MARK: - Animation Extensions

extension View {
    /// Apply spring animation to changes
    func springAnimation<Value: Equatable>(value: Value) -> some View {
        self.animation(.spring(response: 0.3, dampingFraction: 0.7), value: value)
    }

    /// Apply smooth easing animation
    func smoothAnimation<Value: Equatable>(value: Value, duration: Double = 0.3) -> some View {
        self.animation(.easeInOut(duration: duration), value: value)
    }
}

// MARK: - Layout Extensions

extension View {
    /// Fill available space
    func fillWidth(alignment: Alignment = .leading) -> some View {
        self.frame(maxWidth: .infinity, alignment: alignment)
    }

    /// Fill available height
    func fillHeight(alignment: Alignment = .top) -> some View {
        self.frame(maxHeight: .infinity, alignment: alignment)
    }

    /// Fill all available space
    func fillSpace(alignment: Alignment = .topLeading) -> some View {
        self.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
    }

    /// Center content
    func centered() -> some View {
        self.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

// MARK: - Safe Area

extension View {
    /// Read safe area insets
    func readSafeArea(_ safeArea: Binding<EdgeInsets>) -> some View {
        self.background(
            GeometryReader { geometry in
                Color.clear
                    .preference(key: SafeAreaPreferenceKey.self, value: geometry.safeAreaInsets)
            }
        )
        .onPreferenceChange(SafeAreaPreferenceKey.self) { value in
            safeArea.wrappedValue = value
        }
    }
}

struct SafeAreaPreferenceKey: PreferenceKey {
    static var defaultValue: EdgeInsets = .init()
    static func reduce(value: inout EdgeInsets, nextValue: () -> EdgeInsets) {
        value = nextValue()
    }
}

// MARK: - Scroll Detection

extension View {
    /// Detect scroll offset
    func onScroll(_ action: @escaping (CGFloat) -> Void) -> some View {
        self.background(
            GeometryReader { geometry in
                Color.clear
                    .preference(key: ScrollOffsetPreferenceKey.self, value: geometry.frame(in: .named("scroll")).minY)
            }
        )
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
            action(value)
        }
    }
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Debugging

extension View {
    /// Debug modifier to print view updates
    func debugPrint(_ value: String) -> some View {
        #if DEBUG
        print("[Debug] \(value)")
        #endif
        return self
    }

    /// Debug modifier to add colored border
    func debugBorder(_ color: Color = .red) -> some View {
        #if DEBUG
        return self.border(color, width: 1)
        #else
        return self
        #endif
    }
}

// MARK: - Redacted/Loading State

extension View {
    /// Apply loading placeholder style
    func loadingPlaceholder(_ isLoading: Bool) -> some View {
        self
            .redacted(reason: isLoading ? .placeholder : [])
            .shimmer()
            .disabled(isLoading)
    }
}

// MARK: - Keyboard

extension View {
    /// Hide keyboard on tap
    func hideKeyboardOnTap() -> some View {
        self.onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
}

// MARK: - Preview Helper

extension View {
    /// Wrap in dark mode for previews
    func previewDarkMode() -> some View {
        self
            .preferredColorScheme(.dark)
            .background(Color.black)
    }
}
