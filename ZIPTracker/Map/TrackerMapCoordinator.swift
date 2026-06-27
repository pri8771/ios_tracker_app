import Foundation
import MapKit
#if canImport(UIKit)
import UIKit
#endif

#if canImport(UIKit)
/// `MKMapViewDelegate` for the tracker map: renders boundary overlays with
/// style-based colors, vends marker annotation views with emoji glyphs, reports
/// region changes (for zoom-aware overlays), handles taps for selection, and a
/// DEBUG long-press for manual sample injection.
final class TrackerMapCoordinator: NSObject, MKMapViewDelegate {

    var onRegionChange: ((MKCoordinateRegion) -> Void)?
    var onSelectZCTA: ((String) -> Void)?
    var onLongPress: ((CLLocationCoordinate2D) -> Void)?

    /// Style metadata keyed by overlay identity, so `rendererFor` is O(1).
    private var overlayStyles: [ObjectIdentifier: ZCTAOverlayStyle] = [:]
    private var programmaticRegionChange = false

    /// Last applied "center on user" token (so recenters happen only on tap).
    var lastRecenterToken = 0

    // MARK: - Overlay sync

    /// Replaces the map's boundary overlays with the supplied built overlays.
    func apply(overlays builtOverlays: [ZCTAOverlayFactory.BuiltOverlay], to mapView: MKMapView) {
        mapView.removeOverlays(mapView.overlays)
        overlayStyles.removeAll(keepingCapacity: true)
        for built in builtOverlays {
            overlayStyles[ObjectIdentifier(built.polygon)] = built.style
            mapView.addOverlay(built.polygon, level: .aboveRoads)
        }
    }

    /// Replaces discovered + visit annotations (keeps the user-location dot).
    func apply(discovered: [ZCTAMapPin], visits: [ZCTAVisitPin], to mapView: MKMapView) {
        let existing = mapView.annotations.filter { !($0 is MKUserLocation) }
        mapView.removeAnnotations(existing)
        mapView.addAnnotations(discovered.map { ZCTADiscoveredAnnotation(pin: $0) })
        mapView.addAnnotations(visits.map { ZCTAVisitAnnotation(pin: $0) })
    }

    func setRegion(_ region: MKCoordinateRegion, on mapView: MKMapView, animated: Bool) {
        programmaticRegionChange = true
        mapView.setRegion(region, animated: animated)
    }

    // MARK: - MKMapViewDelegate

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        guard let polygon = overlay as? MKPolygon else {
            return MKOverlayRenderer(overlay: overlay)
        }
        let style = overlayStyles[ObjectIdentifier(polygon)] ?? .unvisited
        return ZCTAOverlayRenderer.makeRenderer(for: polygon, style: style)
    }

    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        if programmaticRegionChange {
            programmaticRegionChange = false
            return
        }
        onRegionChange?(mapView.region)
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation { return nil }

        if let discovered = annotation as? ZCTADiscoveredAnnotation {
            let id = "discovered"
            let view = (mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView)
                ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: id)
            view.annotation = annotation
            view.glyphText = discovered.glyphEmoji
            view.markerTintColor = discovered.isCurrent ? .systemGreen
                : (discovered.isFavorite ? .systemYellow : .systemTeal)
            view.clusteringIdentifier = AppConstants.Map.discoveredPinClusterIdentifier
            view.canShowCallout = true
            view.displayPriority = discovered.isCurrent ? .required : .defaultHigh
            return view
        }

        if let visit = annotation as? ZCTAVisitAnnotation {
            let id = "visit"
            let view = (mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView)
                ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: id)
            view.annotation = annotation
            view.glyphImage = UIImage(systemName: "mappin")
            view.markerTintColor = visit.isSimulated ? .systemPurple : .systemBlue
            view.displayPriority = .defaultLow
            view.canShowCallout = true
            return view
        }
        return nil
    }

    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        if let discovered = view.annotation as? ZCTADiscoveredAnnotation {
            onSelectZCTA?(discovered.zctaCode)
        } else if let visit = view.annotation as? ZCTAVisitAnnotation {
            onSelectZCTA?(visit.zctaCode)
        }
    }

    // MARK: - Gestures

    @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began, let mapView = gesture.view as? MKMapView else { return }
        let point = gesture.location(in: mapView)
        let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
        onLongPress?(coordinate)
    }
}
#endif
