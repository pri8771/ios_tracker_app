import Foundation

/// Loads the bundled ZCTA dataset, determines bundle status (production /
/// sample / missing), and vends a `ZCTAIndex` for detection & overlays.
///
/// Bundle selection:
/// - If `zcta_bundle.sqlite` exists and validates → `.production`.
/// - Else if `zcta_sample.sqlite` exists and validates → `.sample`.
/// - Else → `.missing`.
final class ZCTAGeometryService {

    let status: ZCTABundleStatus
    let index: ZCTAIndex?

    /// Designated initializer. `bundle` is injectable for tests.
    init(bundle: Bundle = .main) {
        if let (db, isProduction) = Self.openBestDatabase(in: bundle) {
            let idx = ZCTAIndex(database: db)
            self.index = idx
            if isProduction {
                self.status = .production(idx.metadata)
            } else {
                self.status = .sample(idx.metadata)
            }
        } else {
            self.index = nil
            self.status = .missing
        }
    }

    /// Test/preview initializer with an explicit database path.
    init(databasePath: String, treatAsProduction: Bool) {
        if let db = try? ZCTADatabase(path: databasePath), Self.validate(db) {
            let idx = ZCTAIndex(database: db)
            self.index = idx
            self.status = treatAsProduction ? .production(idx.metadata) : .sample(idx.metadata)
        } else {
            self.index = nil
            self.status = .missing
        }
    }

    // MARK: - Bundle discovery

    private static func openBestDatabase(in bundle: Bundle) -> (ZCTADatabase, Bool)? {
        // 1. Try production bundle.
        if let prodPath = path(for: AppConstants.Bundle.productionDatabaseName, in: bundle),
           let db = try? ZCTADatabase(path: prodPath),
           validate(db) {
            let meta = db.loadMetadata()
            // Honor the embedded production flag; a file named production but
            // flagged sample is treated as sample to avoid faking coverage.
            return (db, meta.isProduction)
        }

        // 2. Fall back to sample bundle.
        if let samplePath = path(for: AppConstants.Bundle.sampleDatabaseName, in: bundle),
           let db = try? ZCTADatabase(path: samplePath),
           validate(db) {
            return (db, false)
        }

        return nil
    }

    private static func path(for name: String, in bundle: Bundle) -> String? {
        // Prefer the ZCTA subdirectory; fall back to bundle root.
        if let url = bundle.url(
            forResource: name,
            withExtension: AppConstants.Bundle.sqliteExtension,
            subdirectory: AppConstants.Bundle.resourceSubdirectory
        ) {
            return url.path
        }
        if let url = bundle.url(
            forResource: name,
            withExtension: AppConstants.Bundle.sqliteExtension
        ) {
            return url.path
        }
        return nil
    }

    /// Lightweight runtime validation: required tables exist and there is at
    /// least one feature. Never fakes production coverage on a malformed bundle.
    static func validate(_ db: ZCTADatabase) -> Bool {
        guard db.hasRequiredTables() else { return false }
        return db.featureCount() > 0
    }
}
