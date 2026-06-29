import Foundation
#if canImport(MetricKit)
import MetricKit
#endif

/// Privacy-preserving, on-device collection of MetricKit metric and diagnostic
/// payloads (crashes, hangs, CPU/disk exceptions, launch times).
///
/// Payloads are written to the app's local Application Support directory and are
/// **never transmitted anywhere** — consistent with Roam's no-backend,
/// no-analytics, local-first design. They give a developer crash/hang signal
/// (e.g. when retrieved from a device during testing or via a Files export)
/// without any third-party SDK.
@MainActor
final class MetricsService: NSObject {

    private let fileStore: FileStore
    private let directoryName = "Diagnostics"
    private var isStarted = false

    init(fileStore: FileStore = FileStore()) {
        self.fileStore = fileStore
        super.init()
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true
        #if canImport(MetricKit)
        MXMetricManager.shared.add(self)
        #endif
    }

    func stop() {
        guard isStarted else { return }
        isStarted = false
        #if canImport(MetricKit)
        MXMetricManager.shared.remove(self)
        #endif
    }

    /// Persists a payload JSON blob locally. Best-effort; failures are ignored.
    private func persist(_ data: Data, prefix: String, stamp: TimeInterval) {
        do {
            let dir = try fileStore.rootDirectory().appendingPathComponent(directoryName, isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let name = "\(prefix)-\(Int(stamp)).json"
            try data.write(to: dir.appendingPathComponent(name), options: .atomic)
        } catch {
            // Diagnostics are best-effort and must never affect app behavior.
        }
    }
}

#if canImport(MetricKit)
extension MetricsService: MXMetricManagerSubscriber {

    func didReceive(_ payloads: [MXMetricPayload]) {
        let now = Date().timeIntervalSince1970
        for (index, payload) in payloads.enumerated() {
            persist(payload.jsonRepresentation(), prefix: "metric", stamp: now + Double(index))
        }
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        let now = Date().timeIntervalSince1970
        for (index, payload) in payloads.enumerated() {
            persist(payload.jsonRepresentation(), prefix: "diagnostic", stamp: now + Double(index))
        }
    }
}
#endif
