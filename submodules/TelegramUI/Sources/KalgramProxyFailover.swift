import Foundation
import SwiftSignalKit
import TelegramCore
import AccountContext
import SGSimpleSettings

// kalgram: automatic proxy switching (kalgram Pro, «Автосмена прокси»).
// - A proxy that has been connecting for `switchDelay` is replaced by the next saved one. Once every saved
//   proxy has failed in a row, it waits until the connection comes back.
// - With no proxy on and no connection for `enableDelay`, the first saved proxy is turned on.
// - With a VPN on, kalgram turns nothing on and switches nothing: a proxy kalgram itself turned on is
//   turned off again, and one the user turned on by hand is left alone.
// Driven by the account's connection status alone: no polling, nothing runs while the connection is fine.
final class KalgramProxyFailover {
    static let shared = KalgramProxyFailover()

    private let switchDelay: Double = 10.0
    private let enableDelay: Double = 15.0

    private var sharedContext: SharedAccountContext?
    private let disposable = MetaDisposable()
    private var timer: SwiftSignalKit.Timer?
    private var proxySettings = ProxySettings.defaultSettings
    private var connectionStatus: ConnectionStatus?
    // Proxies that failed since the connection was last online
    private var failedServers = Set<ProxyServerSettings>()
    // The user turned the proxy off by hand: no turning it back on until the next launch
    private var userDisabledProxy = false
    // The on/off state kalgram itself just asked for, so that change is not taken for the user's
    private var expectedEnabled: Bool?
    private var settingsObserver: NSObjectProtocol?

    func start(sharedContext: SharedAccountContext) {
        guard self.sharedContext == nil else {
            return
        }
        self.sharedContext = sharedContext

        // The kalgram Pro switches take effect at once, not at the next change of the connection
        self.settingsObserver = NotificationCenter.default.addObserver(forName: KalgramProxySettings.changedNotification, object: nil, queue: .main, using: { [weak self] _ in
            self?.reschedule()
        })

        let proxySettings = sharedContext.accountManager.sharedData(keys: [SharedDataKeys.proxySettings])
        |> map { sharedData -> ProxySettings in
            return sharedData.entries[SharedDataKeys.proxySettings]?.get(ProxySettings.self) ?? ProxySettings.defaultSettings
        }
        |> distinctUntilChanged

        let connectionStatus = sharedContext.activeAccountContexts
        |> map { primary, _, _ -> AccountContext? in
            return primary
        }
        |> distinctUntilChanged(isEqual: { lhs, rhs in
            return lhs === rhs
        })
        |> mapToSignal { context -> Signal<ConnectionStatus?, NoError> in
            guard let context else {
                return .single(nil)
            }
            return context.account.network.connectionStatus
            |> map { status -> ConnectionStatus? in
                return status
            }
        }
        |> distinctUntilChanged

        self.disposable.set((combineLatest(proxySettings, connectionStatus)
        |> deliverOnMainQueue).startStrict(next: { [weak self] proxySettings, connectionStatus in
            self?.update(proxySettings: proxySettings, connectionStatus: connectionStatus)
        }))
    }

    private func update(proxySettings: ProxySettings, connectionStatus: ConnectionStatus?) {
        let previous = self.proxySettings
        self.proxySettings = proxySettings
        self.connectionStatus = connectionStatus

        if let expectedEnabled = self.expectedEnabled, expectedEnabled == proxySettings.enabled {
            self.expectedEnabled = nil
        } else if previous.enabled != proxySettings.enabled {
            if previous.enabled && !proxySettings.enabled {
                // turned off by hand
                self.userDisabledProxy = true
                KalgramProxySettings.autoEnabled = false
            } else if !previous.enabled && proxySettings.enabled {
                // turned on by hand: it is the user's now
                KalgramProxySettings.autoEnabled = false
            }
        }

        if case .online = connectionStatus {
            self.failedServers.removeAll()
        }
        self.reschedule()
    }

    private func reschedule() {
        self.timer?.invalidate()
        self.timer = nil

        guard KalgramProxySettings.autoSwitch, let connectionStatus = self.connectionStatus else {
            return
        }
        if KalgramProxySettings.shouldHoldBackForVpn() {
            if self.proxySettings.enabled && KalgramProxySettings.autoEnabled {
                KalgramProxySettings.autoEnabled = false
                self.apply { settings in
                    var settings = settings
                    settings.enabled = false
                    return settings
                }
            }
            return
        }
        guard case .connecting = connectionStatus, !self.proxySettings.servers.isEmpty else {
            return
        }
        let delay = self.proxySettings.enabled ? self.switchDelay : self.enableDelay
        let timer = SwiftSignalKit.Timer(timeout: delay, repeat: false, completion: { [weak self] in
            self?.timerFired()
        }, queue: Queue.mainQueue())
        self.timer = timer
        timer.start()
    }

    private func timerFired() {
        self.timer = nil
        guard KalgramProxySettings.autoSwitch, let connectionStatus = self.connectionStatus, case .connecting = connectionStatus, !KalgramProxySettings.shouldHoldBackForVpn() else {
            return
        }
        let servers = self.proxySettings.servers
        guard !servers.isEmpty else {
            return
        }
        if self.proxySettings.enabled {
            if let current = self.proxySettings.activeServer {
                self.failedServers.insert(current)
            }
            // the next saved proxy after the current one that has not failed yet
            let startIndex = self.proxySettings.activeServer.flatMap({ servers.firstIndex(of: $0) }) ?? -1
            var next: ProxyServerSettings?
            for offset in 1 ... servers.count {
                let candidate = servers[(startIndex + offset + servers.count) % servers.count]
                if !self.failedServers.contains(candidate) {
                    next = candidate
                    break
                }
            }
            guard let next else {
                return
            }
            self.apply { settings in
                var settings = settings
                settings.activeServer = next
                return settings
            }
        } else {
            guard !self.userDisabledProxy, let first = servers.first(where: { !self.failedServers.contains($0) }) else {
                return
            }
            KalgramProxySettings.autoEnabled = true
            self.apply { settings in
                var settings = settings
                settings.enabled = true
                if settings.activeServer == nil {
                    settings.activeServer = first
                }
                return settings
            }
        }
    }

    private func apply(_ f: @escaping (ProxySettings) -> ProxySettings) {
        guard let sharedContext = self.sharedContext else {
            return
        }
        self.expectedEnabled = f(self.proxySettings).enabled
        let _ = updateProxySettingsInteractively(accountManager: sharedContext.accountManager, f).startStandalone()
    }
}
