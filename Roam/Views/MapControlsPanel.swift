import SwiftUI

/// Vertical stack of circular glass map controls: recenter, toggle boundaries,
/// toggle pins, and cycle the base map style.
struct MapControlsPanel: View {

    let boundariesOn: Bool
    let pinsOn: Bool
    let onRecenter: () -> Void
    let onToggleBoundaries: () -> Void
    let onTogglePins: () -> Void
    let onCycleStyle: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            controlButton(systemImage: "location.fill",
                          label: "Center on my location",
                          isActive: false,
                          action: onRecenter)
            controlButton(systemImage: "map",
                          label: boundariesOn ? "Hide boundaries" : "Show boundaries",
                          isActive: boundariesOn,
                          action: onToggleBoundaries)
            controlButton(systemImage: "mappin.and.ellipse",
                          label: pinsOn ? "Hide pins" : "Show pins",
                          isActive: pinsOn,
                          action: onTogglePins)
            controlButton(systemImage: "square.3.layers.3d",
                          label: "Change map style",
                          isActive: false,
                          action: onCycleStyle)
        }
    }

    private func controlButton(systemImage: String, label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(isActive ? Color.accentColor : Color.primary)
                .frame(width: 44, height: 44)
                .background(Circle().fill(.ultraThinMaterial))
                .overlay(Circle().strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
        }
        .accessibilityLabel(label)
    }
}
