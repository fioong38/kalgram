import Foundation
import UIKit
import AVFAudio
import UserNotifications
import BackgroundTasks
import SwiftSignalKit
import TelegramCore
import AccountContext
import TelegramPresentationData
import LocalizedPeerData

// kalgram: new messages while the app is in the background.
//
// A sideloaded build gets no pushes from Telegram, so the app fetches messages
// itself and shows them as local notifications. How it stays awake depends on
// KalgramTweaks.backgroundMode: iOS background refresh now and then, or a silent
// sound that keeps it running (see KalgramKeepAlive).

// Keeps the app running in the background by playing silence, mixed with other
// audio so music and videos of other apps are not interrupted.
final class KalgramKeepAlive {
    static let shared = KalgramKeepAlive()

    // Below this charge, unplugged, the keep-alive stops by itself
    static let minimumBatteryLevel: Float = 0.2

    // Set by SharedWakeupManager: re-evaluates whether the app should stay awake
    var conditionsChanged: (() -> Void)?

    private var player: AVAudioPlayer?
    private var observers: [NSObjectProtocol] = []

    var isRunning: Bool {
        return self.player != nil
    }

    private init() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let center = NotificationCenter.default
        let names: [Notification.Name] = [
            UIDevice.batteryLevelDidChangeNotification,
            UIDevice.batteryStateDidChangeNotification,
            Notification.Name.NSProcessInfoPowerStateDidChange,
            KalgramTweaks.backgroundModeDidChangeNotification
        ]
        for name in names {
            self.observers.append(center.addObserver(forName: name, object: nil, queue: .main, using: { [weak self] _ in
                self?.conditionsChanged?()
            }))
        }
        // A call or Siri interrupts the sound; it has to be started again afterwards
        self.observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main, using: { [weak self] notification in
            guard let self, let player = self.player else {
                return
            }
            if let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt, AVAudioSession.InterruptionType(rawValue: rawType) == .ended {
                let _ = try? AVAudioSession.sharedInstance().setActive(true)
                player.play()
            }
        }))
    }

    // Whether battery and power settings allow staying awake
    var isAllowed: Bool {
        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            return false
        }
        let device = UIDevice.current
        if device.batteryState == .unplugged && device.batteryLevel >= 0.0 && device.batteryLevel < KalgramKeepAlive.minimumBatteryLevel {
            return false
        }
        return true
    }

    func start() {
        if self.player != nil {
            return
        }
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            return
        }
        guard let player = try? AVAudioPlayer(data: KalgramKeepAlive.silence()) else {
            return
        }
        player.numberOfLoops = -1
        player.volume = 0.0
        player.prepareToPlay()
        player.play()
        self.player = player
    }

    // `releaseSession` is false while the app's own audio (a call, a voice message) uses the session
    func stop(releaseSession: Bool) {
        guard let player = self.player else {
            return
        }
        self.player = nil
        player.stop()
        if releaseSession {
            let _ = try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        }
    }

    // One second of 8 kHz mono 16-bit silence as a WAV file
    private static func silence() -> Data {
        let sampleRate: UInt32 = 8000
        let dataSize: UInt32 = sampleRate * 2
        var data = Data()
        func append(_ value: UInt32) {
            var value = value.littleEndian
            withUnsafeBytes(of: &value) { data.append(contentsOf: $0) }
        }
        func append16(_ value: UInt16) {
            var value = value.littleEndian
            withUnsafeBytes(of: &value) { data.append(contentsOf: $0) }
        }
        data.append(contentsOf: Array("RIFF".utf8))
        append(36 + dataSize)
        data.append(contentsOf: Array("WAVEfmt ".utf8))
        append(16)
        append16(1)
        append16(1)
        append(sampleRate)
        append(sampleRate * 2)
        append16(2)
        append16(16)
        data.append(contentsOf: Array("data".utf8))
        append(dataSize)
        data.append(Data(count: Int(dataSize)))
        return data
    }
}

// Shows new incoming messages as notifications while the app is not on screen
final class KalgramBackgroundNotifier {
    private let sharedContext: SharedAccountContextImpl
    private var accountsDisposable: Disposable?
    private var messageDisposables: [AccountRecordId: Disposable] = [:]

    private var modeObserver: NSObjectProtocol?

    init(sharedContext: SharedAccountContextImpl) {
        self.sharedContext = sharedContext
        // A mode picked in kalgram Pro asks iOS for background refresh right away
        self.modeObserver = NotificationCenter.default.addObserver(forName: KalgramTweaks.backgroundModeDidChangeNotification, object: nil, queue: .main, using: { _ in
            kalgramScheduleBackgroundRefresh()
        })
        self.accountsDisposable = (sharedContext.activeAccountContexts
        |> deliverOnMainQueue).start(next: { [weak self] _, contexts, _ in
            guard let self else {
                return
            }
            var current = Set<AccountRecordId>()
            let accountCount = contexts.count
            for (id, context, _) in contexts {
                current.insert(id)
                if self.messageDisposables[id] != nil {
                    continue
                }
                self.messageDisposables[id] = (context.account.stateManager.notificationMessages
                |> deliverOnMainQueue).start(next: { [weak self, weak context] messageList in
                    guard let self, let context else {
                        return
                    }
                    // Unpacked here: the list's element types are Postbox's, which this module does not import
                    for (messages, _, notify, _) in messageList {
                        guard notify, let message = messages.last else {
                            continue
                        }
                        self.show(message: EngineMessage(message), count: messages.count, context: context, accountCount: accountCount)
                    }
                })
            }
            for (id, disposable) in self.messageDisposables where !current.contains(id) {
                disposable.dispose()
                self.messageDisposables.removeValue(forKey: id)
            }
        })
    }

    deinit {
        if let modeObserver = self.modeObserver {
            NotificationCenter.default.removeObserver(modeObserver)
        }
        self.accountsDisposable?.dispose()
        for (_, disposable) in self.messageDisposables {
            disposable.dispose()
        }
    }

    private func show(message: EngineMessage, count: Int, context: AccountContext, accountCount: Int) {
        guard KalgramTweaks.backgroundMode != .off, UIApplication.shared.applicationState != .active else {
            return
        }
        guard message.flags.contains(.Incoming) else {
            return
        }
        let isMuted = message.attributes.contains(where: { attribute in
            if let attribute = attribute as? NotificationInfoMessageAttribute {
                return attribute.flags.contains(.muted)
            }
            return false
        })
        if isMuted {
            return
        }
        let peers = message.enginePeers
        guard let chatPeer = peers[message.id.peerId] else {
            return
        }
        let presentationData = self.sharedContext.currentPresentationData.with { $0 }
        let strings = presentationData.strings
        let nameOrder = presentationData.nameDisplayOrder

        var body = message.text
        if body.isEmpty {
            body = message.engineMedia.isEmpty ? "Новое сообщение" : "📎 Вложение"
        }
        if count > 1 {
            body += " (+\(count - 1))"
        }
        if message.id.peerId.namespace != Namespaces.Peer.CloudUser, let author = message.author, author.id != chatPeer.id {
            body = "\(author.displayTitle(strings: strings, displayOrder: nameOrder)): \(body)"
        }

        let content = UNMutableNotificationContent()
        content.title = chatPeer.displayTitle(strings: strings, displayOrder: nameOrder)
        content.body = body
        content.sound = .default
        content.threadIdentifier = "\(message.id.peerId.toInt64())"
        var userInfo: [AnyHashable: Any] = [
            "accountId": context.account.id.int64,
            "peerId": message.id.peerId.toInt64()
        ]
        if let threadId = message.threadId {
            userInfo["threadId"] = threadId
        }
        content.userInfo = userInfo
        // Which account it came to, when there are several
        if accountCount > 1, let accountPeer = peers[context.account.peerId] {
            content.subtitle = accountPeer.displayTitle(strings: strings, displayOrder: nameOrder)
        }
        let request = UNNotificationRequest(identifier: "kalgram_\(context.account.id.int64)_\(message.id.peerId.toInt64())_\(message.id.id)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}

// iOS background refresh: asks to be woken again in about 15 minutes; iOS decides
// when it actually happens
func kalgramScheduleBackgroundRefresh() {
    guard KalgramTweaks.backgroundMode != .off, let bundleId = Bundle.main.bundleIdentifier else {
        return
    }
    let request = BGAppRefreshTaskRequest(identifier: "\(bundleId).refresh")
    request.earliestBeginDate = Date(timeIntervalSinceNow: 15.0 * 60.0)
    let _ = try? BGTaskScheduler.shared.submit(request)
}
