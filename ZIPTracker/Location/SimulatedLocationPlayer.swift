import Foundation
import CoreLocation

#if DEBUG
/// DEBUG-only helper that feeds a scripted sequence of coordinates through the
/// real `LocationEventProcessor`, so the full detection/visit pipeline can be
/// exercised in the Simulator without GPS.
@MainActor
final class SimulatedLocationPlayer {

    private let processor: LocationEventProcessor
    private var route: [Coordinate]
    private var index = 0

    init(processor: LocationEventProcessor, route: [Coordinate] = SimulatedLocationPlayer.sampleRoute) {
        self.processor = processor
        self.route = route
    }

    /// A short route crossing the bundled sample ZCTAs near San Francisco.
    /// Includes repeats so anti-jitter confirmation logic is exercised.
    static let sampleRoute: [Coordinate] = [
        Coordinate(latitude: 37.7793, longitude: -122.4193), // ~94102
        Coordinate(latitude: 37.7794, longitude: -122.4192), // ~94102 (confirm)
        Coordinate(latitude: 37.7725, longitude: -122.4109), // ~94103
        Coordinate(latitude: 37.7726, longitude: -122.4108), // ~94103 (confirm)
        Coordinate(latitude: 37.7620, longitude: -122.3940), // ~94107
        Coordinate(latitude: 37.7621, longitude: -122.3939), // ~94107 (confirm)
        Coordinate(latitude: 37.7795, longitude: -122.4190), // back to 94102
        Coordinate(latitude: 37.7796, longitude: -122.4189)  // 94102 (confirm)
    ]

    func setRoute(_ route: [Coordinate]) {
        self.route = route
        self.index = 0
    }

    func reset() {
        index = 0
    }

    /// Plays the entire route, spacing samples ~2 minutes apart in virtual time
    /// so cooldown gating accepts the transitions.
    func playFullRoute(baseDate: Date = .now) async {
        for (offset, coordinate) in route.enumerated() {
            let virtualTime = baseDate.addingTimeInterval(Double(offset) * 120)
            await processor.process(
                coordinate: coordinate,
                horizontalAccuracy: 25,
                timestamp: virtualTime,
                source: .simulated,
                isSimulated: true,
                now: virtualTime
            )
        }
        index = route.count
    }

    /// Plays a single next coordinate (Step button).
    func stepNext(now: Date = .now) async {
        guard index < route.count else { return }
        let coordinate = route[index]
        await processor.process(
            coordinate: coordinate,
            horizontalAccuracy: 25,
            timestamp: now,
            source: .simulated,
            isSimulated: true,
            now: now
        )
        index += 1
    }
}
#endif
