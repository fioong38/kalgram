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
}
