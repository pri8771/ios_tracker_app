import Foundation
import SwiftData

/// A lightweight diagnostic event used to explain tracking behavior to the user.
///
/// The store is capped at `AppConstants.Persistence.maxEventLogCount` rows;
/// `pruneIfNeeded` trims oldest entries. These never leave the device.
@Model
final class TrackingEventLog {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var typeRaw: String
    var message: String
    var zctaCode: String?
    var latitude: Double?
    var longitude: Double?

    init(
        id: UUID = UUID(),
        timestamp: Date = .now,
        type: TrackingEventType,
        message: String,
        zctaCode: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.typeRaw = type.rawValue
        self.message = message
        self.zctaCode = zctaCode
        self.latitude = latitude
        self.longitude = longitude
    }

    var type: TrackingEventType {
        TrackingEventType(rawValue: typeRaw) ?? .error
    }
}
