import Foundation
import CFNetwork

// kalgram: switching to another saved proxy when the current one stops connecting
public enum KalgramProxySettings {
    public static let autoSwitchKey = "kalgram.proxy.autoSwitch"
    // Set while a proxy is on because kalgram turned it on, not the user
    public static let autoEnabledKey = "kalgram.proxy.autoEnabled"

    public static let respectVpnKey = "kalgram.proxy.respectVpn"
    public static let changedNotification = Notification.Name("KalgramProxySettingsChanged")

    // Off until the user turns it on
    public static var autoSwitch: Bool {
        get {
            return UserDefaults.standard.bool(forKey: autoSwitchKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: autoSwitchKey)
            NotificationCenter.default.post(name: changedNotification, object: nil)
        }
    }

    // With a VPN on, kalgram turns no proxy on by itself and switches none. On by default.
    public static var respectVpn: Bool {
        get {
            return UserDefaults.standard.object(forKey: respectVpnKey) as? Bool ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: respectVpnKey)
            NotificationCenter.default.post(name: changedNotification, object: nil)
        }
    }

    // A VPN that kalgram should hold back for: on, and the user wants it respected
    public static func shouldHoldBackForVpn() -> Bool {
        return respectVpn && isVpnActive()
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
