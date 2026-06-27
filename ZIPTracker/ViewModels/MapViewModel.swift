import Foundation
import SwiftUI
import SwiftData
import MapKit
import Combine

/// Backs the map screen: owns the visible region, builds zoom-aware boundary
/// overlays (debounced, off-main), and supplies discovered/visit pins.
@MainActor
final class MapViewModel: ObservableObject {

    @Published var overlays: [ZCTAOverlayFactory.BuiltOverlay] = []
    @Published var discoveredPins: [ZCTAMapPin] = []
    @Published var visitPins: [ZCTAVisitPin] = []
    @Published var selectedCode: String?
    @Published var selectedZCTA: TrackedZCTA?
    @Published var recenterToken = 0
    @Published var region: MKCoordinateRegion

    let container: DependencyContainer
    private let settings: AppSettings
    private let factory: ZCTAOverlayFactory?

    private var rebuildTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    init(container: DependencyContainer, settings: AppSettings) {
        self.container = container
        self.settings = settings
        self.factory = container.geometryService.index.map { ZCTAOverlayFactory(index: $0) }
        self.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: settings.lastMapCenterLatitude,
                longitude: settings.lastMapCenterLongitude
            ),
            span: MKCoordinateSpan(
                latitudeDelta: settings.lastMapLatitudeDelta,
                longitudeDelta: settings.lastMapLongitudeDelta
            )
        )

        NotificationCenter.default.publisher(for: AppConstants.Notifications.dataDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.reloadPins()
                self?.scheduleOverlayRebuild()
            }
            .store(in: &cancellables)
    }

    var initialRegion: MKCoordinateRegion { region }

    var currentCode: String? { container.trackingState.currentZCTACode }
    var isUsingSampleData: Bool { container.trackingState.isUsingSampleData }
    var mapStyle: MapDisplayStyle { settings.mapStyle }
    var showVisitPins: Bool { settings.showVisitPins }
    var showDiscoveredPins: Bool { settings.showDiscoveredPins }

    func onAppear() {
        reloadPins()
        scheduleOverlayRebuild()
    }

    func regionChanged(_ region: MKCoordinateRegion) {
        self.region = region
        settings.lastMapCenterLatitude = region.center.latitude
        settings.lastMapCenterLongitude = region.center.longitude
        settings.lastMapLatitudeDelta = region.span.latitudeDelta
        settings.lastMapLongitudeDelta = region.span.longitudeDelta
        scheduleOverlayRebuild()
    }

    func recenterOnUser() {
        recenterToken &+= 1
    }

    func selectZCTA(code: String) {
        selectedCode = code
        var descriptor = FetchDescriptor<TrackedZCTA>(predicate: #Predicate { $0.zctaCode == code })
        descriptor.fetchLimit = 1
        selectedZCTA = (try? container.mainContext.fetch(descriptor))?.first
        scheduleOverlayRebuild()
    }

    func clearSelection() {
        selectedCode = nil
        selectedZCTA = nil
        scheduleOverlayRebuild()
    }

    /// DEBUG-only manual sample injection via long-press.
    func handleLongPress(at coordinate: CLLocationCoordinate2D) {
        #if DEBUG
        let coord = Coordinate(coordinate)
        Task {
            await container.processor.process(
                coordinate: coord,
                horizontalAccuracy: 20,
                timestamp: .now,
                source: .manual,
                isSimulated: true
            )
        }
        #endif
    }

    // MARK: - Pins

    func reloadPins() {
        let tracked = (try? container.mainContext.fetch(
            FetchDescriptor<TrackedZCTA>(predicate: #Predicate { !$0.isArchived })
        )) ?? []

        let current = currentCode
        discoveredPins = tracked.map { z in
            ZCTAMapPin(
                id: z.zctaCode,
                zctaCode: z.zctaCode,
                coordinate: Coordinate(latitude: z.centroidLatitude, longitude: z.centroidLongitude),
                firstEnteredAt: z.firstEnteredAt,
                lastEnteredAt: z.lastEnteredAt,
                visitCount: z.visitCount,
                isFavorite: z.isFavorite,
                isCurrent: z.zctaCode == current
            )
        }

        if settings.showVisitPins {
            let visits = (try? container.mainContext.fetch(
                FetchDescriptor<ZCTAVisit>(sortBy: [SortDescriptor(\.enteredAt, order: .reverse)])
            )) ?? []
            visitPins = visits.prefix(200).map { v in
                ZCTAVisitPin(
                    id: v.id.uuidString,
                    zctaCode: v.zctaCode,
                    coordinate: Coordinate(latitude: v.entryLatitude, longitude: v.entryLongitude),
                    enteredAt: v.enteredAt,
                    isSimulated: v.isSimulated
                )
            }
        } else {
            visitPins = []
        }
    }

    private func visitedCodes() -> Set<String> {
        let tracked = (try? container.mainContext.fetch(FetchDescriptor<TrackedZCTA>())) ?? []
        return Set(tracked.map { $0.zctaCode })
    }

    // MARK: - Overlay building (debounced, off-main)

    func scheduleOverlayRebuild() {
        guard settings.showVisitedBoundaries || settings.showAllVisibleBoundaries else {
            overlays = []
            return
        }
        guard let factory else { return }

        rebuildTask?.cancel()
        let region = self.region
        let visited = visitedCodes()
        let current = currentCode
        let selected = selectedCode
        let showUnvisited = settings.showAllVisibleBoundaries

        rebuildTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(AppConstants.Map.overlayDebounceSeconds * 1_000_000_000))
            if Task.isCancelled { return }
            let built = await Task.detached(priority: .userInitiated) {
                factory.buildOverlays(
                    region: region,
                    visitedCodes: visited,
                    currentCode: current,
                    selectedCode: selected,
                    showUnvisited: showUnvisited
                )
            }.value
            if Task.isCancelled { return }
            await MainActor.run { self?.overlays = built }
        }
    }
}
