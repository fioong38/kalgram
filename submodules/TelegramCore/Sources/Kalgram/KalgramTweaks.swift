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
