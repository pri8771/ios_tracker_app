import SwiftUI

#if canImport(UIKit)
import UIKit

/// A SwiftUI wrapper around `UIActivityViewController` for presenting share
/// sheets (e.g. exported file URLs).
struct ActivityView: UIViewControllerRepresentable {

    let items: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
#endif
