import Foundation
import SwiftUI

/// Backs the Data Status screen describing the active ZCTA bundle (production /
/// sample / missing), its metadata, and the ZCTA accuracy disclaimer.
@MainActor
final class DataStatusViewModel: ObservableObject {

    let container: DependencyContainer

    init(container: DependencyContainer) {
        self.container = container
    }

    var status: ZCTABundleStatus { container.geometryService.status }
    var metadata: ZCTABundleMetadata? { status.metadata }

    var statusTitle: String { status.shortStatusLabel }

    var statusSystemImage: String {
        switch status {
        case .production: return "checkmark.shield.fill"
        case .sample: return "exclamationmark.triangle.fill"
        case .missing: return "xmark.octagon.fill"
        }
    }

    var statusTint: Color {
        switch status {
        case .production: return .green
        case .sample: return .orange
        case .missing: return .red
        }
    }

    /// Whether tracking is blocked due to data state (RELEASE + non-production).
    var blocksTracking: Bool { !status.allowsTracking }

    var coverageWarning: String { AppConstants.Copy.zctaLongDisclaimer }

    var detailMessage: String {
        switch status {
        case .production:
            return "Using the bundled production Census ZCTA dataset for local ZIP/ZCTA detection."
        case .sample:
            return """
            Using the small bundled SAMPLE dataset (a handful of San Francisco \
            test areas). This does NOT provide full ZIP/ZCTA coverage. Build and \
            bundle the production dataset before shipping. See README_ZCTA_DATA.md.
            """
        case .missing:
            return """
            No usable ZCTA dataset was found in the app bundle. Local ZIP/ZCTA \
            detection cannot run. Add zcta_bundle.sqlite (production) to the app's \
            ZCTA resources. See README_ZCTA_DATA.md.
            """
        }
    }
}
