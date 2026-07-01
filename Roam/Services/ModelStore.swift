import Foundation
import SwiftData

/// Centralized fetch-or-create ("upsert") for `TrackedZCTA`.
///
/// `TrackedZCTA.zctaCode` is `@Attribute(.unique)`. More than one writer can try
/// to create the same code — the detection actor's background `ModelContext` and
/// the main context used by sample-data tools. Routing every creation through a
/// single fetch-immediately-before-insert helper keeps the collision window
/// minimal and guarantees we never insert a duplicate within a given context.
enum TrackedZCTAStore {

    struct UpsertResult {
        let model: TrackedZCTA
        let didCreate: Bool
    }

    /// Returns the existing `TrackedZCTA` for `code` in `context`, or inserts a
    /// new one built by `makeNew`. `didCreate` is true only when a new row was
    /// inserted (callers use it to fire the "discovered" notification once).
    static func upsert(
        code: String,
        in context: ModelContext,
        makeNew: () -> TrackedZCTA
    ) -> UpsertResult {
        // Predicate-free lookup: SwiftData can trap (EXC_BREAKPOINT) evaluating
        // `#Predicate` fetches for these models in the current toolchain, so we
        // fetch and match in memory (the tracked-ZCTA table is small).
        let all = (try? context.fetch(FetchDescriptor<TrackedZCTA>())) ?? []
        if let existing = all.first(where: { $0.zctaCode == code }) {
            return UpsertResult(model: existing, didCreate: false)
        }
        let created = makeNew()
        context.insert(created)
        return UpsertResult(model: created, didCreate: true)
    }
}
