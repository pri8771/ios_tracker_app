import SwiftUI

/// Lets the user export their data locally and optionally share it via the
/// system share sheet. Exports are written to Application Support and only
/// leave the device if the user chooses to share them.
struct ExportDataView: View {
    @StateObject private var vm: SettingsViewModel
    @State private var includeEventLogs = false
    @State private var showShareSheet = false

    init(container: DependencyContainer, settings: AppSettings) {
        _vm = StateObject(wrappedValue: SettingsViewModel(container: container, settings: settings))
    }

    var body: some View {
        List {
            if let error = vm.errorMessage {
                Section {
                    ErrorBanner(message: error) { vm.errorMessage = nil }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            }

            Section("JSON") {
                Toggle("Include diagnostic logs", isOn: $includeEventLogs)
                Button {
                    vm.exportJSON(includeEventLogs: includeEventLogs)
                    if vm.exportedFileURL != nil { showShareSheet = true }
                } label: {
                    Label("Export Full JSON", systemImage: "square.and.arrow.up")
                }
            }

            Section("CSV") {
                Button {
                    vm.exportVisitsCSV()
                    if vm.exportedFileURL != nil { showShareSheet = true }
                } label: {
                    Label("Export Visits CSV", systemImage: "square.and.arrow.up")
                }
                Button {
                    vm.exportSummaryCSV()
                    if vm.exportedFileURL != nil { showShareSheet = true }
                } label: {
                    Label("Export Summary CSV", systemImage: "square.and.arrow.up")
                }
            }

            Section {
                Text("Exports are saved locally in the app's Application Support directory. They are shared with other apps only if you choose to from the share sheet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Export Data")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShareSheet) {
            if let url = vm.exportedFileURL {
                #if canImport(UIKit)
                ActivityView(items: [url])
                #endif
            }
        }
    }
}
