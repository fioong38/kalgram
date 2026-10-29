import Foundation
import CFNetwork

// kalgram: switching to another saved proxy when the current one stops connecting
public enum KalgramProxySettings {
    public static let autoSwitchKey = "kalgram.proxy.autoSwitch"
    // Set while a proxy is on because kalgram turned it on, not the user
    public static let autoEnabledKey = "kalgram.proxy.autoEnabled"

    public static var autoSwitch: Bool {
        get {
            return UserDefaults.standard.object(forKey: autoSwitchKey) as? Bool ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: autoSwitchKey)
        }
    }

    public static var autoEnabled: Bool {
        get {
            return UserDefaults.standard.bool(forKey: autoEnabledKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: autoEnabledKey)
        }
    }

    // A VPN shows up as a scoped network interface (utun, ipsec, ppp, tap, tun) in the system proxy settings
    public static func isVpnActive() -> Bool {
        guard let settings = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any], let scoped = settings["__SCOPED__"] as? [String: Any] else {
            return false
        }
        let prefixes = ["utun", "ipsec", "ppp", "tap", "tun"]
        return scoped.keys.contains(where: { key in
            return prefixes.contains(where: { key.hasPrefix($0) })
        })
    }
}
