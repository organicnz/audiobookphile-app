//
//  GlassNavigationBar.swift
//  AudiobookphileClient
//
//  Custom navigation bar with Liquid Glass design
//

import SwiftUI

struct GlassNavigationBar<Leading: View, Trailing: View>: View {
    let title: String
    var subtitle: String? = nil
    var showBackground: Bool = true
    @ViewBuilder var leading: () -> Leading
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                // Leading content
                leading()
                    .frame(width: 44, alignment: .leading)

                Spacer()

                // Title
                VStack(spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.white)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }

                Spacer()

                // Trailing content
                trailing()
                    .frame(width: 44, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background {
                if showBackground {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                }
            }
        }
    }
}

// Convenience initializer for simple back button
extension GlassNavigationBar where Leading == GlassBackButton, Trailing == EmptyView {
    init(title: String, subtitle: String? = nil, onBack: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.showBackground = true
        self.leading = { GlassBackButton(action: onBack) }
        self.trailing = { EmptyView() }
    }
}

// MARK: - Glass Back Button

struct GlassBackButton: View {
    let action: () -> Void
    var icon: String = "chevron.left"

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
        }
    }
}

// MARK: - Glass Action Button

struct GlassActionButton: View {
    let icon: String
    let action: () -> Void
    var badgeCount: Int? = nil

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())

                if let count = badgeCount, count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(minWidth: 16, minHeight: 16)
                        .background(.red)
                        .clipShape(Circle())
                        .offset(x: 4, y: -4)
                }
            }
        }
    }
}

// MARK: - Scrolling Navigation Bar

struct ScrollingGlassNavBar: View {
    let title: String
    let scrollOffset: CGFloat
    let threshold: CGFloat
    var onBack: (() -> Void)? = nil

    private var progress: CGFloat {
        min(1, max(0, -scrollOffset / threshold))
    }

    var body: some View {
        ZStack {
            // Blurred background (appears on scroll)
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(progress)

            HStack {
                if let onBack = onBack {
                    GlassBackButton(action: onBack)
                }

                Spacer()

                // Title (appears on scroll)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .opacity(progress)

                Spacer()

                // Placeholder for symmetry
                Color.clear
                    .frame(width: 36, height: 36)
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 56)
    }
}

// MARK: - Large Title Navigation Bar

struct LargeTitleGlassNavBar<Trailing: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(.white)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }

                Spacer()

                trailing()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }
}

extension LargeTitleGlassNavBar where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = { EmptyView() }
    }
}

// MARK: - Tab Style Navigation

struct GlassTabBar: View {
    @Binding var selectedIndex: Int
    let tabs: [GlassTab]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                GlassTabButton(
                    tab: tab,
                    isSelected: selectedIndex == index
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        selectedIndex = index
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
        }
        .padding(4)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }
}

struct GlassTab {
    let icon: String
    let title: String
}

struct GlassTabButton: View {
    let tab: GlassTab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 18))

                Text(tab.title)
                    .font(.caption2)
            }
            .foregroundStyle(isSelected ? .white : .white.opacity(0.5))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                isSelected
                    ? Color.cyan.opacity(0.3)
                    : Color.clear
            )
            .clipShape(Capsule())
        }
    }
}

// MARK: - Previews

#Preview("Glass Navigation Bar") {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack {
            GlassNavigationBar(title: "Library", onBack: {})

            Spacer()
        }
    }
}

#Preview("Large Title Nav") {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack {
            LargeTitleGlassNavBar(title: "My Library", subtitle: "24 books") {
                GlassActionButton(icon: "gearshape", action: {})
            }

            Spacer()
        }
    }
}

#Preview("Glass Tab Bar") {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack {
            Spacer()

            GlassTabBar(selectedIndex: .constant(0), tabs: [
                GlassTab(icon: "books.vertical", title: "Library"),
                GlassTab(icon: "magnifyingglass", title: "Search"),
                GlassTab(icon: "arrow.down.circle", title: "Downloads"),
                GlassTab(icon: "gearshape", title: "Settings")
            ])
            .padding()
        }
    }
}
