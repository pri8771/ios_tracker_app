import Foundation
import StoreKit

/// Lightweight StoreKit 2 manager for **Roam Plus** — a single one-time unlock.
///
/// Monetization is deliberately thin and honest, matching Roam's privacy posture:
/// no subscriptions, no ads, no data sale. The core loop (tracking, map coloring,
/// the current area, the shareable card, and export/delete) is **always free**.
/// Plus only unlocks power-user extras (e.g. the full state-by-state breakdown).
@MainActor
final class StoreManager: ObservableObject {

    static let plusProductID = "com.localfirst.roam.plus"

    @Published private(set) var plusProduct: Product?
    @Published private(set) var isPlus = false
    @Published private(set) var purchaseInFlight = false
    @Published var lastError: String?

    private var updatesTask: Task<Void, Never>?

    init() {
        // Listen for transactions that arrive outside an explicit purchase
        // (e.g. restores, family sharing, Ask to Buy approvals).
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(verification: update)
            }
        }
    }

    deinit { updatesTask?.cancel() }

    /// Loads products and refreshes entitlement. Safe to call repeatedly.
    func refresh() async {
        await loadProducts()
        await updateEntitlement()
    }

    func loadProducts() async {
        do {
            let products = try await Product.products(for: [Self.plusProductID])
            plusProduct = products.first
        } catch {
            // No StoreKit configuration / offline: leave Plus locked silently.
            plusProduct = nil
        }
    }

    /// Current entitlement from the transaction ledger.
    func updateEntitlement() async {
        var owned = false
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let transaction) = entitlement,
               transaction.productID == Self.plusProductID,
               transaction.revocationDate == nil {
                owned = true
            }
        }
        isPlus = owned
    }

    func purchasePlus() async {
        guard let product = plusProduct else {
            lastError = "Roam Plus isn't available right now. Please try again later."
            return
        }
        purchaseInFlight = true
        defer { purchaseInFlight = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                await handle(verification: verification)
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
            await updateEntitlement()
            if !isPlus { lastError = "No previous Roam Plus purchase was found." }
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func handle(verification: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = verification else { return }
        if transaction.productID == Self.plusProductID, transaction.revocationDate == nil {
            isPlus = true
        }
        await transaction.finish()
    }

    /// Display price, falling back to a sensible default before products load.
    var plusDisplayPrice: String {
        plusProduct?.displayPrice ?? "$14.99"
    }
}
