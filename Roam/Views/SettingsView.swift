import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// The Settings tab. The tracking enable/disable flow is threaded in from
/// `AppTabView` (which owns the `RootViewModel`) via closures, so the permission
/// walk (When-In-Use → Always education → Always) runs correctly.
struct SettingsView: View {
    @StateObject private var vm: SettingsViewModel
    // AppSettings is an @Observable SwiftData model, so reading its properties in
    // `body` is enough to drive updates; this view uses explicit Bindings, never
    // `$settings`, so a plain `let` is correct here.
    private let settings: AppSettings
    @ObservedObject private var trackingState: TrackingState
    private let container: DependencyContainer

    let requestEnableTracking: () -> Void
    let requestDisableTracking: () -> Void

    @State private var showDeleteDialog = false

    init(
        container: DependencyContainer,
        settings: AppSettings,
        requestEnableTracking: @escaping () -> Void,
        requestDisableTracking: @escaping () -> Void
    ) {
        self.container = container
        self.settings = settings
        _trackingState = ObservedObject(wrappedValue: container.trackingState)
        self.requestEnableTracking = requestEnableTracking
        self.requestDisableTracking = requestDisableTracking
        _vm = StateObject(wrappedValue: SettingsViewModel(container: container, settings: settings))
    }

    var body: some View {
        Form {
            trackingSection
            trackingModeSection
            privacySection
            mapSection
            dataSection
            diagnosticsSection
            #if DEBUG
            debugSection
            #endif
        }
        .navigationTitle("Settings")
        .confirmationDialog("Delete All Data",
                            isPresented: $showDeleteDialog, titleVisibility: .visible) {
            Button("Delete Everything", role: .destructive) {
                vm.deleteAllData()
            }
            .disabled(!vm.canConfirmDelete)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes all tracked ZIP Code Areas and visits on this device. Type DELETE above to confirm.")
        }
    }

    // MARK: - Tracking

    private var trackingSection: some View {
        Section {
            Toggle("Enable Tracking", isOn: Binding(
                get: { settings.trackingEnabled },
                set: { newValue in
                    if newValue {
                        requestEnableTracking()
                    } else {
                        requestDisableTracking()
                    }
                }
            ))
            .accessibilityHint("Collects the ZIP Code Areas you visit in the background.")

            HStack {
                Text("Permission")
                Spacer()
                Text(authDescription)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)

            if authDenied {
                openSettingsButton
            }

            NavigationLink {
                TrackingSettingsView(container: container, settings: settings)
            } label: {
                Label("Advanced Tracking", systemImage: "slider.horizontal.3")
            }
        } header: {
            Text("Tracking")
        } footer: {
            Text("Status: \(trackingState.runtimeState.displayName)")
        }
    }

    private var trackingModeSection: some View {
        Section {
            Picker("Tracking Mode", selection: Binding(
                get: { settings.trackingMode },
                set: { vm.setTrackingMode($0) }
            )) {
                ForEach(TrackingMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            Text(settings.trackingMode.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Text("Tracking Mode")
        }
    }

    private var privacySection: some View {
        Section("Privacy") {
            NavigationLink {
                PrivacyHelpView()
            } label: {
                Label("Privacy & Help", systemImage: "lock.shield")
            }
            Text("All data stays on this device. No account, no cloud, no analytics.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var mapSection: some View {
        Section("Map") {
            Toggle("Show Visited Boundaries", isOn: mapBinding(\.showVisitedBoundaries))
            Toggle("Show All Visible Boundaries", isOn: mapBinding(\.showAllVisibleBoundaries))
            Toggle("Show Visit Pins", isOn: mapBinding(\.showVisitPins))
            Toggle("Show Discovered Pins", isOn: mapBinding(\.showDiscoveredPins))
            Picker("Map Style", selection: Binding(
                get: { settings.mapStyle },
                set: { newValue in settings.mapStyle = newValue; vm.persistMapToggles() }
            )) {
                ForEach(MapDisplayStyle.allCases) { style in
                    Text(style.displayName).tag(style)
                }
            }
        }
    }

    private var dataSection: some View {
        Section("Data") {
            NavigationLink {
                DataStatusView(container: container)
            } label: {
                Label("Data Status", systemImage: "externaldrive")
            }
            NavigationLink {
                ExportDataView(container: container, settings: settings)
            } label: {
                Label("Export Data", systemImage: "square.and.arrow.up")
            }
            VStack(alignment: .leading, spacing: 8) {
                TextField("Type DELETE to confirm", text: $vm.deleteConfirmationText)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.characters)
                Button(role: .destructive) {
                    showDeleteDialog = true
                } label: {
                    Label("Delete All Data", systemImage: "trash")
                }
                .disabled(!vm.canConfirmDelete)
            }
        }
    }

    private var diagnosticsSection: some View {
        Section("Diagnostics") {
            Toggle("Store Diagnostic Event Log", isOn: diagnosticsBinding(\.storeDiagnosticEventLog))
            Toggle("Enable Haptics", isOn: diagnosticsBinding(\.enableHaptics))
        }
    }

    #if DEBUG
    private var debugSection: some View {
        Section("Developer (DEBUG)") {
            Button("Generate Sample Visits") { vm.generateSampleVisits() }
            Button("Simulate Route") { vm.simulateRoute() }
            Button("Step Next Location") { vm.stepNextLocation() }
            Button("Clear Sample Data") { vm.clearSampleData() }
            Button("Reset Simulated Visits") { vm.resetSimulatedVisits() }
        }
    }
    #endif

    // MARK: - Helpers

    private func mapBinding(_ keyPath: ReferenceWritableKeyPath<AppSettings, Bool>) -> Binding<Bool> {
        Binding(
            get: { settings[keyPath: keyPath] },
            set: { newValue in
                settings[keyPath: keyPath] = newValue
                vm.persistMapToggles()
            }
        )
    }

    private func diagnosticsBinding(_ keyPath: ReferenceWritableKeyPath<AppSettings, Bool>) -> Binding<Bool> {
        Binding(
            get: { settings[keyPath: keyPath] },
            set: { newValue in
                settings[keyPath: keyPath] = newValue
                try? container.mainContext.save()
            }
        )
    }

    private var authDescription: String {
        switch vm.authorizationState {
        case .notDetermined: return "Not Set"
        case .denied: return "Denied"
        case .restricted: return "Restricted"
        case .whenInUse: return "While Using"
        case .whenInUseReducedAccuracy: return "While Using (Reduced)"
        case .always: return "Always"
        case .alwaysReducedAccuracy: return "Always (Reduced)"
        }
    }

    private var authDenied: Bool {
        vm.authorizationState == .denied || vm.authorizationState == .restricted
    }

    @ViewBuilder
    private var openSettingsButton: some View {
        #if canImport(UIKit)
        Button {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        } label: {
            Label("Open Settings", systemImage: "gearshape")
        }
        #endif
    }
}
