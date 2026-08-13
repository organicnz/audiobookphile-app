//
//  DesignTokens.swift
//  Audiobookphile
//
//  GENERATED FILE — do not edit by hand.
//  Source: design-system/tokens.json
//  Regenerate: bun design-system/sync-design-tokens.mjs
//

import SwiftUI

/// Cross-platform design tokens shared with the web app (Tailwind theme).
public enum DesignTokens {
    /// Core semantic colors (web: `tokens.generated.css` `--design-*`).
    public enum Color {
    public static let background = SwiftUI.Color(red: 0.215686, green: 0.219608, blue: 0.219608)
    public static let surface = SwiftUI.Color(red: 0.137255, green: 0.137255, blue: 0.137255)
    public static let surfaceHover = SwiftUI.Color(red: 0.176471, green: 0.176471, blue: 0.176471)
    public static let foreground = SwiftUI.Color(red: 0.929412, green: 0.929412, blue: 0.929412)
    public static let foregroundMuted = SwiftUI.Color(red: 0.819608, green: 0.835294, blue: 0.862745)
    public static let foregroundSubdued = SwiftUI.Color(red: 0.733333, green: 0.733333, blue: 0.733333)
    public static let border = SwiftUI.Color(red: 0.266667, green: 0.266667, blue: 0.266667)
    public static let glassBg = SwiftUI.Color(red: 0.137255, green: 0.137255, blue: 0.137255, opacity: 0.75)
    public static let accent = SwiftUI.Color(red: 0.976471, green: 0.450980, blue: 0.086275)
    public static let accentSecondary = SwiftUI.Color(red: 0.909804, green: 0.364706, blue: 0.047059)
    public static let accentHighlight = SwiftUI.Color(red: 0.980392, green: 0.549020, blue: 0.149020)
    public static let success = SwiftUI.Color(red: 0.298039, green: 0.686275, blue: 0.313725)
    public static let warning = SwiftUI.Color(red: 0.984314, green: 0.549020, blue: 0.000000)
    public static let error = SwiftUI.Color(red: 1.000000, green: 0.321569, blue: 0.321569)
    public static let info = SwiftUI.Color(red: 0.129412, green: 0.588235, blue: 0.952941)
    }

    /// Spacing scale in points/pixels, mirroring the web spacing scale.
    public enum Spacing {
    public static let step0: CGFloat = 4
    public static let step1: CGFloat = 8
    public static let step2: CGFloat = 12
    public static let step3: CGFloat = 16
    public static let step4: CGFloat = 24
    public static let step5: CGFloat = 32
    public static let step6: CGFloat = 48
    }

    /// Corner radius scale in points/pixels.
    public enum Radius {
    public static let step0: CGFloat = 8
    public static let step1: CGFloat = 12
    public static let step2: CGFloat = 16
    public static let step3: CGFloat = 24
    }

    /// Animation duration scale in seconds.
    public enum Duration {
    public static let fast: Double = 0.15
    public static let normal: Double = 0.3
    public static let slow: Double = 0.5
    }

    /// Text size scale in points (iOS dynamic type overrides when applied).
    public enum Typography {
    public static let xs: CGFloat = 12
    public static let sm: CGFloat = 14
    public static let base: CGFloat = 16
    public static let lg: CGFloat = 18
    public static let xl: CGFloat = 20
    public static let size2xl: CGFloat = 24
    public static let size3xl: CGFloat = 32
    public static let size4xl: CGFloat = 40
    }
}
