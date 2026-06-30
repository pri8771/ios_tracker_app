import SwiftUI

/// Roam's design system.
///
/// Roam's brand story is "your travels, colored in automatically and privately"
/// — a warm, golden-hour travel diary, not a cold GIS tool. The palette pairs a
/// trustworthy **indigo** (maps, privacy, calm) with a warm **sunset** coral→amber
/// (the satisfying "colored-in" patches) and a live **teal** for the current area.
///
/// Everything here is theme-aware (light/dark) and centralizes the tokens that
/// were previously hard-coded ad-hoc across views.
enum Theme {

    // MARK: - Spacing (4-pt scale)

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 40
    }

    // MARK: - Corner radius

    enum Radius {
        static let chip: CGFloat = 10
        static let control: CGFloat = 14
        static let card: CGFloat = 18
        static let panel: CGFloat = 22
        static let hero: CGFloat = 28
    }

    // MARK: - Animation

    enum Motion {
        static let quick = Animation.spring(response: 0.32, dampingFraction: 0.82)
        static let gentle = Animation.spring(response: 0.5, dampingFraction: 0.85)
    }
}

// MARK: - Dynamic color helper

extension Color {
    /// Builds a color that resolves differently in light vs. dark mode.
    init(light: UInt, dark: UInt) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(hex: dark)
                : UIColor(hex: light)
        })
    }

    init(hex: UInt, alpha: Double = 1) {
        self.init(uiColor: UIColor(hex: hex, alpha: alpha))
    }
}

extension UIColor {
    convenience init(hex: UInt, alpha: Double = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: CGFloat(alpha)
        )
    }
}

// MARK: - Palette

extension Color {

    // Brand
    /// Primary brand color: trustworthy indigo. Used for primary actions and chrome.
    static let roamIndigo = Color(light: 0x4F46E5, dark: 0x8B80FF)
    static let roamViolet = Color(light: 0x7C3AED, dark: 0xA78BFA)
    /// Warm sunset coral — the signature "colored-in" patch color and celebration accent.
    static let roamCoral = Color(light: 0xFB6F47, dark: 0xFF8A66)
    static let roamAmber = Color(light: 0xF5A623, dark: 0xFFBE4D)
    /// Live/current-area color.
    static let roamTeal = Color(light: 0x0FB39B, dark: 0x2DD4BF)

    // Semantic
    static let roamSuccess = Color(light: 0x1FA463, dark: 0x4ADE80)
    static let roamWarning = Color(light: 0xC9821A, dark: 0xFBBF4D)
    static let roamDanger = Color(light: 0xE0483D, dark: 0xFF6B5E)

    // Surfaces (warm-tinted neutrals)
    static let roamBackground = Color(light: 0xFBFAF8, dark: 0x0E0E12)
    static let roamSurface = Color(light: 0xFFFFFF, dark: 0x1A1A20)
    static let roamSurfaceElevated = Color(light: 0xFFFFFF, dark: 0x23232B)
    static let roamSurfaceMuted = Color(light: 0xF3F1ED, dark: 0x26262E)

    // Text
    static let roamTextPrimary = Color(light: 0x1A1A1F, dark: 0xF5F4F2)
    static let roamTextSecondary = Color(light: 0x6B6B73, dark: 0xA2A2AC)
    static let roamTextTertiary = Color(light: 0x9A9AA2, dark: 0x6E6E78)

    // Hairline
    static let roamSeparator = Color(light: 0x000000, dark: 0xFFFFFF)
}

// MARK: - Gradients

extension LinearGradient {
    /// Signature golden-hour horizon: coral → indigo. The hero/celebration brand gradient.
    static let roamBrand = LinearGradient(
        colors: [Color(hex: 0xFF7A59), Color(hex: 0xF5559E), Color(hex: 0x7C3AED)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Warm sunset used for "colored-in" celebration and the share card.
    static let roamSunset = LinearGradient(
        colors: [Color(hex: 0xFF9A5B), Color(hex: 0xFB6F47), Color(hex: 0xF5559E)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Calm indigo→violet for primary chrome and buttons.
    static let roamIndigoGradient = LinearGradient(
        colors: [Color(hex: 0x5B4BE6), Color(hex: 0x7C3AED)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let roamTealGradient = LinearGradient(
        colors: [Color(hex: 0x14C8AE), Color(hex: 0x0FB39B)],
        startPoint: .top,
        endPoint: .bottom
    )
}

// MARK: - Typography

extension Font {
    /// Friendly rounded display type for titles / numbers — warm travel-diary tone.
    static func roamDisplay(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static let roamLargeTitle = roamDisplay(32, weight: .bold)
    static let roamTitle = roamDisplay(24, weight: .bold)
    static let roamTitle2 = roamDisplay(20, weight: .semibold)
    static let roamHeadline = roamDisplay(17, weight: .semibold)
    /// Big tabular number for stat tiles / coverage counts.
    static func roamMetric(_ size: CGFloat = 30) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }
}

// MARK: - Shadow

extension View {
    /// Soft, layered card shadow tuned for both modes.
    func roamCardShadow() -> some View {
        shadow(color: Color.black.opacity(0.06), radius: 14, x: 0, y: 6)
    }

    func roamFloatShadow() -> some View {
        shadow(color: Color.black.opacity(0.12), radius: 18, x: 0, y: 10)
    }
}
