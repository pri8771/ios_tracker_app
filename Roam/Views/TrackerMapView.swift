import SwiftUI
import MapKit

/// Full-screen map tab. Drives `TrackerMapViewRepresentable` from `MapViewModel`
/// and overlays status pills, map controls, a selected-ZCTA card, and a
/// sample-data banner.
struct TrackerMapView: View {
    @StateObject private var vm: MapViewModel
    @ObservedObject private var trackingState: TrackingState
    private let container: DependencyContainer
    private let settings: AppSettings

    init(container: DependencyContainer, settings: AppSettings) {
        self.container = container
        self.settings = settings
        self.trackingState = container.trackingState
        _vm = StateObject(wrappedValue: MapViewModel(container: container, settings: settings))
    }

    var body: some View {
        ZStack {
            mapLayer
                .ignoresSafeArea(edges: .bottom)

            VStack {
                topPills
                Spacer()
            }
            .padding()

            HStack {
                Spacer()
                VStack {
                    Spacer()
                    MapControlsPanel(
                        boundariesOn: settings.showVisitedBoundaries || settings.showAllVisibleBoundaries,
                        pinsOn: settings.showDiscoveredPins,
                        onRecenter: vm.recenterOnUser,
                        onToggleBoundaries: toggleBoundaries,
                        onTogglePins: togglePins,
                        onCycleStyle: cycleStyle
                    )
                    Spacer()
                }
            }
            .padding()

            VStack {
                Spacer()
                if vm.selectedCode != nil || vm.selectedZCTA != nil {
                    SelectedZCTACard(
                        tracked: vm.selectedZCTA,
                        code: vm.selectedCode ?? vm.selectedZCTA?.zctaCode ?? "",
                        container: container,
                        onDismiss: vm.clearSelection
                    )
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .navigationTitle("Map")
        .navigationBarTitleDisplayMode(.inline)
        .animation(.easeInOut, value: vm.selectedCode)
        .onAppear { vm.onAppear() }
        .alert(
            "Location Unavailable",
            isPresented: Binding(
                get: { trackingState.lastErrorMessage != nil },
                set: { if !$0 { trackingState.lastErrorMessage = nil } }
            ),
            actions: {
                Button("OK") { trackingState.lastErrorMessage = nil }
            },
            message: {
                Text(trackingState.lastErrorMessage ?? "")
            }
        )
    }

    @ViewBuilder
    private var mapLayer: some View {
        #if canImport(UIKit)
        TrackerMapViewRepresentable(
            mapStyle: vm.mapStyle,
            overlays: vm.overlays,
            discoveredPins: vm.showDiscoveredPins ? vm.discoveredPins : [],
            visitPins: vm.visitPins,
            showsUserLocation: true,
            recenterToken: vm.recenterToken,
            userCoordinate: vm.userCoordinate,
            initialRegion: vm.initialRegion,
            onRegionChange: vm.regionChanged,
            onSelectZCTA: vm.selectZCTA,
            onLongPress: vm.handleLongPress
        )
        #else
        Color(.systemBackground)
        #endif
    }

    private var topPills: some View {
        VStack(spacing: 8) {
            HStack {
                statusPill
                Spacer()
                if let code = vm.currentCode {
                    currentPill(code)
                }
            }
            HStack {
                Text(AppConstants.Copy.boundaryModeLabel)
                    .font(.caption2)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(.ultraThinMaterial))
                Spacer()
            }
            if vm.isUsingSampleData {
                ErrorBanner(message: "Limited beta coverage — some areas aren't detected yet.")
            }
        }
    }

    private var statusPill: some View {
        HStack(spacing: 6) {
            Circle().fill(statusColor).frame(width: 9, height: 9)
            Text(trackingState.runtimeState.displayName)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Capsule().fill(.ultraThinMaterial))
        .accessibilityLabel("Tracking: \(trackingState.runtimeState.displayName)")
    }

    private func currentPill(_ code: String) -> some View {
        Label(code, systemImage: "location.fill")
            .font(.caption.weight(.semibold))
            .monospacedDigit()
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(.ultraThinMaterial))
            .accessibilityLabel("Current ZIP/ZCTA \(code)")
    }

    private var statusColor: Color {
        switch trackingState.runtimeState {
        case .off: return .gray
        case .needsAlwaysAuthorization: return .orange
        case .active: return .green
        case .activeReducedAccuracy: return .yellow
        case .error: return .red
        }
    }

    // MARK: - Control actions

    private func toggleBoundaries() {
        let on = settings.showVisitedBoundaries || settings.showAllVisibleBoundaries
        // Turn both off when on; restore visited boundaries when off.
        settings.showVisitedBoundaries = !on
        settings.showAllVisibleBoundaries = !on
        try? container.mainContext.save()
        vm.scheduleOverlayRebuild()
    }

    private func togglePins() {
        settings.showDiscoveredPins.toggle()
        try? container.mainContext.save()
        vm.reloadPins()
    }

    private func cycleStyle() {
        let all = MapDisplayStyle.allCases
        if let idx = all.firstIndex(of: settings.mapStyle) {
            settings.mapStyle = all[(idx + 1) % all.count]
        } else {
            settings.mapStyle = .standard
        }
        try? container.mainContext.save()
    }
}
