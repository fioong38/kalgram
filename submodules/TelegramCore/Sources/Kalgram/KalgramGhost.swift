import Foundation
import Postbox

// kalgram: ghost mode, separately for every account.
//
// Two layers decide whether a ghost feature is active for an account:
// - permanent: features that are always on (e.g. invisible story views);
// - quick: features toggled together by the ghost button in the chat list.
// A feature is active when it is permanent, or when it is in the quick set and
// the quick mode is on. The button switches only the account it is shown for,
// the other accounts keep whatever was chosen for them.
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
    // Posted with the account id (Int64) as the object
    public static let didChangeNotification = Notification.Name("KalgramGhostDidChange")

    private static func accountKey(_ accountPeerId: PeerId) -> String {
        return "kalgram.ghost.\(accountPeerId.id._internalGetInt64Value())"
    }

    // Value for the account, falling back to the setting from builds that had one
    // ghost mode for all accounts
    private static func bool(_ key: String, legacyKey: String, defaultValue: Bool) -> Bool {
        if let value = UserDefaults.standard.object(forKey: key) as? Bool {
            return value
        }
        return UserDefaults.standard.object(forKey: legacyKey) as? Bool ?? defaultValue
    }

    private static func set(_ value: Bool, key: String, accountPeerId: PeerId) {
        UserDefaults.standard.set(value, forKey: key)
        NotificationCenter.default.post(name: didChangeNotification, object: accountPeerId.id._internalGetInt64Value())
    }

    public static func isQuickEnabled(accountPeerId: PeerId) -> Bool {
        return bool("\(accountKey(accountPeerId)).quickEnabled", legacyKey: "kalgram.ghost.quickEnabled", defaultValue: false)
    }

    public static func setQuickEnabled(_ value: Bool, accountPeerId: PeerId) {
        set(value, key: "\(accountKey(accountPeerId)).quickEnabled", accountPeerId: accountPeerId)
    }

    public static func isPermanent(_ feature: KalgramGhostFeature, accountPeerId: PeerId) -> Bool {
        return bool("\(accountKey(accountPeerId)).permanent.\(feature.rawValue)", legacyKey: "kalgram.ghost.permanent.\(feature.rawValue)", defaultValue: false)
    }

    public static func setPermanent(_ feature: KalgramGhostFeature, _ value: Bool, accountPeerId: PeerId) {
        set(value, key: "\(accountKey(accountPeerId)).permanent.\(feature.rawValue)", accountPeerId: accountPeerId)
    }

    // Every feature is in the quick set until the user removes it
    public static func isInQuickSet(_ feature: KalgramGhostFeature, accountPeerId: PeerId) -> Bool {
        return bool("\(accountKey(accountPeerId)).quick.\(feature.rawValue)", legacyKey: "kalgram.ghost.quick.\(feature.rawValue)", defaultValue: true)
    }

    public static func setInQuickSet(_ feature: KalgramGhostFeature, _ value: Bool, accountPeerId: PeerId) {
        set(value, key: "\(accountKey(accountPeerId)).quick.\(feature.rawValue)", accountPeerId: accountPeerId)
    }

    public static func isActive(_ feature: KalgramGhostFeature, accountPeerId: PeerId) -> Bool {
        return isPermanent(feature, accountPeerId: accountPeerId) || (isQuickEnabled(accountPeerId: accountPeerId) && isInQuickSet(feature, accountPeerId: accountPeerId))
    }
}
