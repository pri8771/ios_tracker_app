import SwiftUI

/// Advanced tracking tuning. Edits the persisted `AppSettings` and applies them
/// to the running engine via `SettingsViewModel.applyTrackingSettings()`.
struct TrackingSettingsView: View {
    @StateObject private var vm: SettingsViewModel
    @Bindable private var settings: AppSettings

    init(container: DependencyContainer, settings: AppSettings) {
        _settings = Bindable(wrappedValue: settings)
        _vm = StateObject(wrappedValue: SettingsViewModel(container: container, settings: settings))
    }

    var body: some View {
        Form {
            Section {
                stepperRow(
                    title: "Distance Filter",
                    value: $settings.distanceFilterMeters,
                    range: 25...1000, step: 25, unit: "m"
                )
            } footer: {
                Text("Minimum movement before a new location is considered. Higher values save battery but detect transitions later.")
            }

            Section {
                stepperRow(
                    title: "Desired Accuracy",
                    value: $settings.desiredAccuracyMeters,
                    range: 10...1000, step: 10, unit: "m"
                )
            } footer: {
                Text("Target horizontal accuracy. Tighter accuracy improves ZIP/ZCTA precision but uses more battery.")
            }

            Section {
                stepperRow(
                    title: "Transition Cooldown",
                    value: $settings.transitionCooldownSeconds,
                    range: 0...600, step: 15, unit: "s"
                )
            } footer: {
                Text("Anti-jitter delay before confirming a move to a different ZIP Code Area.")
            }

            Section {
                stepperRow(
                    title: "Reject Worse Than",
                    value: $settings.rejectLocationsWorseThanMeters,
                    range: 50...2000, step: 50, unit: "m"
                )
            } footer: {
                Text("Location samples with horizontal accuracy worse than this are discarded.")
            }

            Section {
                Toggle("Pause Automatically", isOn: $settings.pauseAutomatically)
                Toggle("Confirm Near Boundaries", isOn: $settings.requireTwoConsecutiveMatchesNearBoundary)
                Toggle("Background Location Indicator", isOn: $settings.showBackgroundLocationIndicator)
            } footer: {
                Text("Pausing automatically and requiring two matches near boundaries reduce battery use and false transitions. The background indicator shows the blue status bar while tracking.")
            }
        }
        .navigationTitle("Tracking Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: settings.distanceFilterMeters) { _, _ in vm.applyTrackingSettings() }
        .onChange(of: settings.desiredAccuracyMeters) { _, _ in vm.applyTrackingSettings() }
        .onChange(of: settings.transitionCooldownSeconds) { _, _ in vm.applyTrackingSettings() }
        .onChange(of: settings.rejectLocationsWorseThanMeters) { _, _ in vm.applyTrackingSettings() }
        .onChange(of: settings.pauseAutomatically) { _, _ in vm.applyTrackingSettings() }
        .onChange(of: settings.requireTwoConsecutiveMatchesNearBoundary) { _, _ in vm.applyTrackingSettings() }
        .onChange(of: settings.showBackgroundLocationIndicator) { _, _ in vm.applyTrackingSettings() }
    }

    private func stepperRow(title: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double, unit: String) -> some View {
        Stepper(value: value, in: range, step: step) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int(value.wrappedValue)) \(unit)")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .accessibilityLabel("\(title): \(Int(value.wrappedValue)) \(unit)")
    }
}
