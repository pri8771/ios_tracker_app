import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Centralized, opt-out haptic feedback. Used for the "new ZIP/ZCTA discovered"
/// success cue while the app is active.
@MainActor
final class HapticsService {

    var isEnabled: Bool

    init(isEnabled: Bool = true) {
        self.isEnabled = isEnabled
    }

    func success() {
        guard isEnabled else { return }
        #if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
    }

    func selection() {
        guard isEnabled else { return }
        #if canImport(UIKit)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }

    func lightImpact() {
        guard isEnabled else { return }
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}
