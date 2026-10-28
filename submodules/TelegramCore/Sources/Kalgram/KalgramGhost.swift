import Foundation

// kalgram: ghost mode.
//
// Two layers decide whether a ghost feature is active:
// - permanent: features that are always on (e.g. invisible story views);
// - quick: features toggled together by the ghost button in the chat list.
// A feature is active when it is permanent, or when it is in the quick set and
// the quick mode is on.
//
// Stored in UserDefaults so the network code can read it from any queue
// without a Postbox transaction.

public enum KalgramGhostFeature: String, CaseIterable {
    // Read receipts, also "listened" marks on voice and video messages
    case readReceipts
    // "typing…", "recording voice…" and other activities
    case typing
    // Never report being online
    case online
    // Viewing stories leaves no trace
    case stories
}

public enum KalgramGhost {
    public static let didChangeNotification = Notification.Name("KalgramGhostDidChange")

    private static let quickEnabledKey = "kalgram.ghost.quickEnabled"

    private static func permanentKey(_ feature: KalgramGhostFeature) -> String {
        return "kalgram.ghost.permanent.\(feature.rawValue)"
    }

    private static func quickKey(_ feature: KalgramGhostFeature) -> String {
        return "kalgram.ghost.quick.\(feature.rawValue)"
    }

    public static var isQuickEnabled: Bool {
        get {
            return UserDefaults.standard.bool(forKey: quickEnabledKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: quickEnabledKey)
            NotificationCenter.default.post(name: didChangeNotification, object: nil)
        }
    }

    public static func isPermanent(_ feature: KalgramGhostFeature) -> Bool {
        return UserDefaults.standard.bool(forKey: permanentKey(feature))
    }

    public static func setPermanent(_ feature: KalgramGhostFeature, _ value: Bool) {
        UserDefaults.standard.set(value, forKey: permanentKey(feature))
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }

    // Every feature is in the quick set until the user removes it
    public static func isInQuickSet(_ feature: KalgramGhostFeature) -> Bool {
        return UserDefaults.standard.object(forKey: quickKey(feature)) as? Bool ?? true
    }

    public static func setInQuickSet(_ feature: KalgramGhostFeature, _ value: Bool) {
        UserDefaults.standard.set(value, forKey: quickKey(feature))
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }

    public static func isActive(_ feature: KalgramGhostFeature) -> Bool {
        return isPermanent(feature) || (isQuickEnabled && isInQuickSet(feature))
    }
}
