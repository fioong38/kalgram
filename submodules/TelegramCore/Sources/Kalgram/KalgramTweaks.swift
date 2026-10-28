import Foundation

// kalgram: client-side switches that are not part of ghost mode.
//
// Modules that cannot depend on TelegramCore (ScreenCaptureDetection,
// UIKitRuntimeUtils) read the same UserDefaults keys directly.
public enum KalgramTweaks {
    // Copy, save and screenshot content that the sender protected. Also stops
    // reporting screenshots to the other side. On by default.
    public static let bypassProtectionKey = "kalgram.bypassProtection"

    public static var bypassProtection: Bool {
        get {
            return UserDefaults.standard.object(forKey: bypassProtectionKey) as? Bool ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: bypassProtectionKey)
        }
    }

    // Opening a self-destructing (view-once or timed) photo or video does not
    // start its timer or notify the sender until the user burns it. On by default.
    // Channels, bots and messages hidden only on iOS ("violated App Store guidelines")
    // open as they do on Android and desktop. Restrictions for every platform
    // (legal blocks) still apply. On by default.
    public static let bypassIosRestrictionsKey = "kalgram.bypassIosRestrictions"

    public static var bypassIosRestrictions: Bool {
        get {
            return UserDefaults.standard.object(forKey: bypassIosRestrictionsKey) as? Bool ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: bypassIosRestrictionsKey)
        }
    }

    // Whether a restriction rule for `rulePlatform` hides content on this device
    public static func restrictionApplies(rulePlatform: String, platform: String, addedPlatforms: [String]) -> Bool {
        if rulePlatform == "all" {
            return true
        }
        if bypassIosRestrictions {
            return false
        }
        return rulePlatform == platform || addedPlatforms.contains(rulePlatform)
    }

    // Private chats: messages deleted by the other side stay, marked as deleted. On by default.
    public static let keepDeletedMessagesKey = "kalgram.keepDeletedMessages"

    public static var keepDeletedMessages: Bool {
        get {
            return UserDefaults.standard.object(forKey: keepDeletedMessagesKey) as? Bool ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: keepDeletedMessagesKey)
        }
    }

    // Private chats: edited incoming messages keep their previous text below the new one. On by default.
    public static let keepEditHistoryKey = "kalgram.keepEditHistory"

    public static var keepEditHistory: Bool {
        get {
            return UserDefaults.standard.object(forKey: keepEditHistoryKey) as? Bool ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: keepEditHistoryKey)
        }
    }

    public static let keepSelfDestructingKey = "kalgram.keepSelfDestructing"

    public static var keepSelfDestructing: Bool {
        get {
            return UserDefaults.standard.object(forKey: keepSelfDestructingKey) as? Bool ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: keepSelfDestructingKey)
        }
    }
}
