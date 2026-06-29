import SwiftUI
import MapKit

#if canImport(UIKit)
/// SwiftUI wrapper around `MKMapView`. Renders zoom-aware ZCTA boundary overlays
/// and discovered/visit pins, and reports region changes and selections back up
/// to `MapViewModel`.
struct TrackerMapViewRepresentable: UIViewRepresentable {

    var mapStyle: MapDisplayStyle
    var overlays: [ZCTAOverlayFactory.BuiltOverlay]
    var discoveredPins: [ZCTAMapPin]
    var visitPins: [ZCTAVisitPin]
    var showsUserLocation: Bool
    var recenterToken: Int
    var userCoordinate: CLLocationCoordinate2D?
    var initialRegion: MKCoordinateRegion

    var onRegionChange: (MKCoordinateRegion) -> Void
    var onSelectZCTA: (String) -> Void
    var onLongPress: (CLLocationCoordinate2D) -> Void

    func makeCoordinator() -> TrackerMapCoordinator {
        let coordinator = TrackerMapCoordinator()
        coordinator.onRegionChange = onRegionChange
        coordinator.onSelectZCTA = onSelectZCTA
        coordinator.onLongPress = onLongPress
        return coordinator
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = showsUserLocation
        mapView.pointOfInterestFilter = .excludingAll
        mapView.setRegion(initialRegion, animated: false)
        applyStyle(mapStyle, to: mapView)

        let longPress = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(TrackerMapCoordinator.handleLongPress(_:))
        )
        longPress.minimumPressDuration = 0.6
        mapView.addGestureRecognizer(longPress)

        context.coordinator.apply(overlays: overlays, to: mapView)
        context.coordinator.apply(discovered: discoveredPins, visits: visitPins, to: mapView)
        context.coordinator.lastRecenterToken = recenterToken
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.onRegionChange = onRegionChange
        context.coordinator.onSelectZCTA = onSelectZCTA
        context.coordinator.onLongPress = onLongPress

        mapView.showsUserLocation = showsUserLocation
        applyStyle(mapStyle, to: mapView)

        context.coordinator.apply(overlays: overlays, to: mapView)
        context.coordinator.apply(discovered: discoveredPins, visits: visitPins, to: mapView)

        // Recenter only when the token changes (user tapped "center on me").
        if recenterToken != context.coordinator.lastRecenterToken {
            context.coordinator.lastRecenterToken = recenterToken
            if let userCoordinate {
                let region = MKCoordinateRegion(
                    center: userCoordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                )
                context.coordinator.setRegion(region, on: mapView, animated: true)
            }
        }
    }

    private func applyStyle(_ style: MapDisplayStyle, to mapView: MKMapView) {
        switch style {
        case .standard: mapView.preferredConfiguration = MKStandardMapConfiguration()
        case .hybrid: mapView.preferredConfiguration = MKHybridMapConfiguration()
        case .satellite: mapView.preferredConfiguration = MKImageryMapConfiguration()
        }
    }
}
#endif
