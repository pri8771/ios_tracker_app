import Foundation

/// Builds RFC-4180-style CSV text from export DTOs.
///
/// Fields containing commas, quotes, or newlines are wrapped in double quotes,
/// and embedded quotes are doubled. Dates are emitted as ISO-8601.
struct CSVService {

    private let isoFormatter: ISO8601DateFormatter

    init() {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        self.isoFormatter = f
    }

    static let visitHeaders = [
        "visit_id", "zcta_code", "entered_at", "exited_at", "duration_seconds",
        "entry_lat", "entry_lon", "last_lat", "last_lon",
        "detection_source", "confidence", "is_simulated"
    ]

    static let summaryHeaders = [
        "zcta_code", "first_entered_at", "last_entered_at", "visit_count",
        "total_duration_seconds", "first_entry_lat", "first_entry_lon",
        "centroid_lat", "centroid_lon", "is_favorite", "note"
    ]

    /// Escapes a single CSV field.
    func escape(_ field: String) -> String {
        let needsQuoting = field.contains(",") || field.contains("\"") ||
            field.contains("\n") || field.contains("\r")
        guard needsQuoting else { return field }
        let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    /// Joins one row of fields, escaping each.
    func makeRow(_ fields: [String]) -> String {
        fields.map { escape($0) }.joined(separator: ",")
    }

    // MARK: - Visits CSV

    func visitsCSV(_ visits: [ZCTAVisitExportDTO]) -> String {
        var lines = [makeRow(Self.visitHeaders)]
        for v in visits {
            lines.append(makeRow([
                v.visitId.uuidString,
                v.zctaCode,
                isoFormatter.string(from: v.enteredAt),
                v.exitedAt.map { isoFormatter.string(from: $0) } ?? "",
                String(format: "%.0f", v.durationSeconds),
                String(v.entryLatitude),
                String(v.entryLongitude),
                String(v.lastLatitude),
                String(v.lastLongitude),
                v.detectionSource,
                v.confidence,
                v.isSimulated ? "true" : "false"
            ]))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    // MARK: - Summary CSV

    func summaryCSV(_ summaries: [TrackedZCTAExportDTO]) -> String {
        var lines = [makeRow(Self.summaryHeaders)]
        for s in summaries {
            lines.append(makeRow([
                s.zctaCode,
                isoFormatter.string(from: s.firstEnteredAt),
                isoFormatter.string(from: s.lastEnteredAt),
                String(s.visitCount),
                String(format: "%.0f", s.totalDurationSeconds),
                String(s.firstEntryLatitude),
                String(s.firstEntryLongitude),
                String(s.centroidLatitude),
                String(s.centroidLongitude),
                s.isFavorite ? "true" : "false",
                s.note
            ]))
        }
        return lines.joined(separator: "\n") + "\n"
    }
}
