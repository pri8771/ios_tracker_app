import Foundation

/// Metadata describing the loaded ZCTA SQLite bundle (from its `metadata` table).
struct ZCTABundleMetadata: Sendable, Equatable {
    var version: String
    var sourceName: String
    var buildDate: String
    var featureCount: Int
    var isProduction: Bool

    static let unknown = ZCTABundleMetadata(
        version: "unknown",
        sourceName: "unknown",
        buildDate: "unknown",
        featureCount: 0,
        isProduction: false
    )

    init(version: String, sourceName: String, buildDate: String, featureCount: Int, isProduction: Bool) {
        self.version = version
        self.sourceName = sourceName
        self.buildDate = buildDate
        self.featureCount = featureCount
        self.isProduction = isProduction
    }

    init(rawPairs: [String: String]) {
        self.version = rawPairs["version"] ?? "unknown"
        self.sourceName = rawPairs["source_name"] ?? "unknown"
        self.buildDate = rawPairs["build_date"] ?? "unknown"
        self.featureCount = Int(rawPairs["feature_count"] ?? "0") ?? 0
        let prod = (rawPairs["is_production"] ?? "false").lowercased()
        self.isProduction = (prod == "true" || prod == "1")
    }

    var dto: ZCTABundleMetadataDTO {
        ZCTABundleMetadataDTO(
            version: version,
            sourceName: sourceName,
            buildDate: buildDate,
            featureCount: featureCount,
            isProduction: isProduction
        )
    }
}

/// Which ZCTA dataset is actually backing the app right now.
enum ZCTABundleStatus: Equatable, Sendable {
    /// Production bundle present and validated.
    case production(ZCTABundleMetadata)
    /// Only the tiny DEBUG/test sample bundle is available.
    case sample(ZCTABundleMetadata)
    /// No usable bundle at all.
    case missing

    var metadata: ZCTABundleMetadata? {
        switch self {
        case .production(let m), .sample(let m): return m
        case .missing: return nil
        }
    }

    var isProduction: Bool {
        if case .production = self { return true }
        return false
    }

    var isSample: Bool {
        if case .sample = self { return true }
        return false
    }

    var isMissing: Bool {
        self == .missing
    }

    /// Whether tracking should be permitted to start with this data.
    ///
    /// Tracking runs on both the production bundle and the limited beta (sample)
    /// bundle — the beta ships labeled, limited geography on purpose so the
    /// permission + delight loops can be validated while the nationwide bundle is
    /// finalized. The in-app banner makes the limited coverage explicit. Only a
    /// truly missing bundle blocks tracking.
    var allowsTracking: Bool {
        switch self {
        case .production, .sample: return true
        case .missing: return false
        }
    }

    var shortStatusLabel: String {
        switch self {
        case .production: return "Production Census ZCTA data"
        case .sample: return "Limited beta ZCTA coverage"
        case .missing: return "ZCTA data missing"
        }
    }
}
