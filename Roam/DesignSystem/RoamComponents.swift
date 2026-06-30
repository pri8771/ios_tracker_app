import SwiftUI

// MARK: - Card

/// The standard Roam surface: a soft, elevated rounded container. Replaces the
/// ad-hoc `.ultraThinMaterial` panels with a consistent, theme-aware card.
struct RoamCard<Content: View>: View {
    var padding: CGFloat = Theme.Spacing.md
    var cornerRadius: CGFloat = Theme.Radius.card
    var tint: Color? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.roamSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill((tint ?? .clear).opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.roamSeparator.opacity(0.07), lineWidth: 1)
            )
            .roamCardShadow()
    }
}

// MARK: - Section header

/// A consistent section title with optional icon and trailing accessory.
struct SectionHeader<Accessory: View>: View {
    let title: String
    var systemImage: String? = nil
    var tint: Color = .roamIndigo
    @ViewBuilder var accessory: () -> Accessory

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xs) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
            }
            Text(title)
                .font(.roamHeadline)
                .foregroundStyle(Color.roamTextPrimary)
            Spacer(minLength: 0)
            accessory()
        }
        .accessibilityAddTraits(.isHeader)
    }
}

extension SectionHeader where Accessory == EmptyView {
    init(_ title: String, systemImage: String? = nil, tint: Color = .roamIndigo) {
        self.init(title: title, systemImage: systemImage, tint: tint, accessory: { EmptyView() })
    }
}

// MARK: - Icon badge

/// An SF Symbol inside a soft, tinted rounded square. Used in list rows and stats.
struct IconBadge: View {
    let systemImage: String
    var tint: Color = .roamIndigo
    var size: CGFloat = 38

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                    .fill(tint.opacity(0.14))
            )
            .accessibilityHidden(true)
    }
}

// MARK: - Stat tile

/// A compact metric tile: big rounded number + label, with an optional icon.
struct StatTile: View {
    let value: String
    let label: String
    var systemImage: String? = nil
    var tint: Color = .roamIndigo
    var caption: String? = nil

    var body: some View {
        RoamCard(padding: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack {
                    if let systemImage {
                        IconBadge(systemImage: systemImage, tint: tint, size: 32)
                    }
                    Spacer(minLength: 0)
                }
                Text(value)
                    .font(.roamMetric(28))
                    .foregroundStyle(Color.roamTextPrimary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(Color.roamTextSecondary)
                if let caption {
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(tint)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
    }
}

// MARK: - Chip / pill

struct Chip: View {
    let text: String
    var systemImage: String? = nil
    var tint: Color = .roamIndigo
    var filled: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage).font(.system(size: 11, weight: .semibold))
            }
            Text(text).font(.caption.weight(.semibold))
        }
        .foregroundStyle(filled ? Color.white : tint)
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(filled ? AnyShapeStyle(tint) : AnyShapeStyle(tint.opacity(0.14)))
        )
    }
}

// MARK: - Progress ring

/// A circular progress indicator used for coverage / completion.
struct ProgressRing: View {
    var progress: Double            // 0...1
    var lineWidth: CGFloat = 10
    var gradient: AngularGradient = AngularGradient(
        colors: [Color(hex: 0xFF7A59), Color(hex: 0xF5559E), Color(hex: 0x7C3AED), Color(hex: 0xFF7A59)],
        center: .center
    )
    var centerLabel: String? = nil
    var centerCaption: String? = nil

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.roamSurfaceMuted, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, progress)))
                .stroke(gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(Theme.Motion.gentle, value: progress)
            if centerLabel != nil || centerCaption != nil {
                VStack(spacing: 2) {
                    if let centerLabel {
                        Text(centerLabel)
                            .font(.roamMetric(26))
                            .foregroundStyle(Color.roamTextPrimary)
                    }
                    if let centerCaption {
                        Text(centerCaption)
                            .font(.caption)
                            .foregroundStyle(Color.roamTextSecondary)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Int((progress * 100).rounded())) percent")
    }
}

// MARK: - Linear progress bar

struct RoamProgressBar: View {
    var progress: Double
    var tint: LinearGradient = .roamSunset
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.roamSurfaceMuted)
                Capsule()
                    .fill(tint)
                    .frame(width: max(height, geo.size.width * max(0, min(1, progress))))
            }
        }
        .frame(height: height)
        .animation(Theme.Motion.gentle, value: progress)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Int((progress * 100).rounded())) percent")
    }
}

// MARK: - Screen background

/// A subtle, warm app background used behind scrollable screens.
struct RoamScreenBackground: View {
    var body: some View {
        Color.roamBackground.ignoresSafeArea()
    }
}
