import Foundation
#if os(iOS)
import UIKit
#endif

/// Thin wrapper over the system feedback generators. No-ops on platforms that
/// lack haptics and when the player has turned them off, so callers never have
/// to branch.
@MainActor
final class Haptics {
    var enabled = true

    #if os(iOS)
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notify = UINotificationFeedbackGenerator()
    private let selection = UISelectionFeedbackGenerator()
    #endif

    /// Warms up the Taptic Engine so the first real tap isn't delayed.
    func prepare() {
        #if os(iOS)
        impactLight.prepare()
        notify.prepare()
        selection.prepare()
        #endif
    }

    func tap() {
        guard enabled else { return }
        #if os(iOS)
        selection.selectionChanged()
        #endif
    }

    func light() {
        guard enabled else { return }
        #if os(iOS)
        impactLight.impactOccurred()
        #endif
    }

    func medium() {
        guard enabled else { return }
        #if os(iOS)
        impactMedium.impactOccurred()
        #endif
    }

    func success() {
        guard enabled else { return }
        #if os(iOS)
        notify.notificationOccurred(.success)
        #endif
    }

    func warning() {
        guard enabled else { return }
        #if os(iOS)
        notify.notificationOccurred(.warning)
        #endif
    }

    func error() {
        guard enabled else { return }
        #if os(iOS)
        impactHeavy.impactOccurred()
        notify.notificationOccurred(.error)
        #endif
    }
}
