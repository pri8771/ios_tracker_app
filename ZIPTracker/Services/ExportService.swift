import Foundation
import SwiftData

/// Assembles full JSON and CSV exports from SwiftData and writes them to disk.
/// All data stays local; the user chooses whether to share files via the system
/// share sheet.
@MainActor
struct ExportService {

    let context: ModelContext
    let bundleMetadata: ZCTABundleMetadata
    let fileStore: FileStore
    let csvService: CSVService

    init(
        context: ModelContext,
        bundleMetadata: ZCTABundleMetadata,
        fileStore: FileStore = FileStore(),
        csvService: CSVService = CSVService()
    ) {
        self.context = context
        self.bundleMetadata = bundleMetadata
        self.fileStore = fileStore
        self.csvService = csvService
    }

    private func timestampSuffix(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmmss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: date)
    }

    // MARK: - DTO assembly

    func buildFullExport(includeEventLogs: Bool, now: Date = .now) throws -> FullExportRecord {
        let tracked = try context.fetch(FetchDescriptor<TrackedZCTA>())
        let visits = try context.fetch(
            FetchDescriptor<ZCTAVisit>(sortBy: [SortDescriptor(\.enteredAt, order: .forward)])
        )

        let trackedDTOs = tracked.map { z in
            TrackedZCTAExportDTO(
                zctaCode: z.zctaCode,
                displayName: z.displayName,
                note: z.note,
                firstEnteredAt: z.firstEnteredAt,
                lastEnteredAt: z.lastEnteredAt,
                lastSeenAt: z.lastSeenAt,
                visitCount: z.visitCount,
                totalDurationSeconds: z.totalDurationSeconds,
                firstEntryLatitude: z.firstEntryLatitude,
                firstEntryLongitude: z.firstEntryLongitude,
                centroidLatitude: z.centroidLatitude,
                centroidLongitude: z.centroidLongitude,
                isFavorite: z.isFavorite,
                isArchived: z.isArchived
            )
        }

        let visitDTOs = visits.map { v in
            ZCTAVisitExportDTO(
                visitId: v.id,
                zctaCode: v.zctaCode,
                enteredAt: v.enteredAt,
                exitedAt: v.exitedAt,
                durationSeconds: v.duration,
                entryLatitude: v.entryLatitude,
                entryLongitude: v.entryLongitude,
                lastLatitude: v.lastLatitude,
                lastLongitude: v.lastLongitude,
                detectionSource: v.detectionSource.rawValue,
                confidence: v.confidence.rawValue,
                acceptedSampleCount: v.acceptedSampleCount,
                isSimulated: v.isSimulated
            )
        }

        var eventDTOs: [TrackingEventLogExportDTO]?
        if includeEventLogs {
            let events = try context.fetch(
                FetchDescriptor<TrackingEventLog>(sortBy: [SortDescriptor(\.timestamp, order: .forward)])
            )
            eventDTOs = events.map {
                TrackingEventLogExportDTO(
                    timestamp: $0.timestamp,
                    type: $0.type.rawValue,
                    message: $0.message,
                    zctaCode: $0.zctaCode,
                    latitude: $0.latitude,
                    longitude: $0.longitude
                )
            }
        }

        return FullExportRecord(
            appName: AppConstants.appName,
            exportVersion: AppConstants.Export.exportVersion,
            generatedAt: now,
            zctaBundleMetadata: bundleMetadata.dto,
            trackedZCTAs: trackedDTOs,
            visits: visitDTOs,
            eventLogs: eventDTOs
        )
    }

    // MARK: - File writers

    @discardableResult
    func exportJSON(includeEventLogs: Bool, now: Date = .now) throws -> URL {
        let record = try buildFullExport(includeEventLogs: includeEventLogs, now: now)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(record)
        return try fileStore.write(data, fileName: "ZIPTracker-Export-\(timestampSuffix(now)).json")
    }

    @discardableResult
    func exportVisitsCSV(now: Date = .now) throws -> URL {
        let record = try buildFullExport(includeEventLogs: false, now: now)
        let csv = csvService.visitsCSV(record.visits)
        return try fileStore.write(csv, fileName: "ZIPTracker-Visits-\(timestampSuffix(now)).csv")
    }

    @discardableResult
    func exportSummaryCSV(now: Date = .now) throws -> URL {
        let record = try buildFullExport(includeEventLogs: false, now: now)
        let csv = csvService.summaryCSV(record.trackedZCTAs)
        return try fileStore.write(csv, fileName: "ZIPTracker-Summary-\(timestampSuffix(now)).csv")
    }
}
