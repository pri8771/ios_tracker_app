import SwiftUI

/// Describes the active ZCTA bundle (production / sample / missing), its
/// metadata, the coverage disclaimer, and whether tracking is blocked.
struct DataStatusView: View {
    @StateObject private var vm: DataStatusViewModel

    init(container: DependencyContainer) {
        _vm = StateObject(wrappedValue: DataStatusViewModel(container: container))
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    Image(systemName: vm.statusSystemImage)
                        .font(.system(size: 36))
                        .foregroundStyle(vm.statusTint)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(vm.statusTitle).font(.headline)
                    }
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Data status: \(vm.statusTitle)")

                Text(vm.detailMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if vm.blocksTracking {
                Section {
                    ErrorBanner(message: "Tracking is blocked until a valid production Census ZCTA bundle is installed.")
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            }

            if let meta = vm.metadata {
                Section("Bundle Metadata") {
                    metaRow("Version", meta.version)
                    metaRow("Source", meta.sourceName)
                    metaRow("Build Date", meta.buildDate)
                    metaRow("Feature Count", "\(meta.featureCount)")
                    metaRow("Production", meta.isProduction ? "Yes" : "No")
                }
            }

            Section("About ZCTA Coverage") {
                Text(vm.coverageWarning)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Data Status")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func metaRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}
