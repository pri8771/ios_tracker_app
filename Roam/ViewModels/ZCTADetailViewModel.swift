import Foundation
import SwiftUI
import SwiftData
import MapKit

/// Backs the per-ZCTA detail screen: stats, mini-map boundary, visit timeline,
/// and actions (favorite, note, archive, delete, export CSV).
@MainActor
final class ZCTADetailViewModel: ObservableObject {

    @Published var tracked: TrackedZCTA
    @Published var note: String
    @Published var boundaryPolygons: [MKPolygon] = []
    @Published var exportedFileURL: URL?
    @Published var errorMessage: String?

    let container: DependencyContainer

    init(tracked: TrackedZCTA, container: DependencyContainer) {
        self.tracked = tracked
        self.note = tracked.note
        self.container = container
    }

    var visits: [ZCTAVisit] {
        tracked.visits.sorted { $0.enteredAt > $1.enteredAt }
    }

    var firstDiscovered: Date { tracked.firstEnteredAt }
    var lastSeen: Date { tracked.lastSeenAt }
    var visitCount: Int { tracked.visitCount }
    var totalDuration: TimeInterval { tracked.totalDurationSeconds }

    var averageVisitSeconds: TimeInterval {
        guard tracked.visitCount > 0 else { return 0 }
        return tracked.totalDurationSeconds / Double(tracked.visitCount)
    }

    var longestVisitSeconds: TimeInterval {
        visits.map { $0.duration }.max() ?? 0
    }

    var centerRegion: MKCoordinateRegion {
        MKCoordinateRegion(
            center: tracked.centroidCoordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
        )
    }

    func loadBoundary() {
        guard let index = container.geometryService.index else { return }
        if let polygon = index.polygon(code: tracked.zctaCode, resolution: 3) {
            boundaryPolygons = polygon.makeMapPolygons()
        }
    }

    func saveNote() {
        tracked.note = note
        tracked.updatedAt = .now
        persist()
    }

    func toggleFavorite() {
        tracked.isFavorite.toggle()
        tracked.updatedAt = .now
        persist()
    }

    func archive() {
        tracked.isArchived = true
        tracked.updatedAt = .now
        persist()
    }

    func delete() {
        container.mainContext.delete(tracked)
        persist()
    }

    func exportCSV() {
        do {
            let service = container.makeExportService()
            // Filter the summary CSV to this ZCTA by writing a focused export.
            exportedFileURL = try service.exportVisitsCSV()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func persist() {
        try? container.mainContext.save()
        NotificationCenter.default.post(name: AppConstants.Notifications.dataDidChange, object: nil)
    }
}
