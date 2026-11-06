import Foundation
import UIKit
import LocalAuthentication
import SwiftSignalKit
import Display
import TelegramCore
import TelegramPresentationData
import AccountContext
import AppBundle
import SGProUI

// kalgram: "Пароль на чаты" at run time, adapted from Ghostgram (GPLv2).
//
// Nothing here polls: it reacts to a chat being opened and to the app leaving and coming back.
// Unlock state is per account and in memory only, so a cold start locks everything; time is measured
// with a monotonic clock the user cannot wind back.

public enum KalgramLocalAuth {
    private static var isRunning = false

    // Main thread. Face ID or Touch ID with the device passcode as the fallback. Without a device
    // passcode nothing can be checked: the request goes through, but the user is told so.
    public static func authenticate(reason: String, completion: @escaping (Bool) -> Void) {
        assert(Thread.isMainThread)
        if isRunning {
            completion(false)
            return
        }
        isRunning = true
        let finish: (Bool) -> Void = { granted in
            isRunning = false
            completion(granted)
        }
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason, reply: { success, _ in
                DispatchQueue.main.async {
                    finish(success)
                }
            })
        } else {
            let alert = UIAlertController(title: "Защита не действует", message: "На iPhone не задан код-пароль, поэтому проверять нечем. Задайте его в настройках iPhone.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "ОК", style: .default, handler: { _ in
                finish(true)
            }))
            if let top = KalgramImagePicker.topViewController() {
                top.present(alert, animated: true)
            } else {
                finish(true)
            }
        }
    }
}

// An opaque sheet over a locked chat. It covers the chat's own navigation, so without "Закрыть" a
// refused check would leave no way out.
private final class KalgramLockCoverView: UIView {
    var unlock: (() -> Void)?
    var close: (() -> Void)?

    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let unlockButton: UIButton?
    private let closeButton: UIButton?

    init(theme: PresentationTheme, title: String, hasButtons: Bool) {
        self.unlockButton = hasButtons ? UIButton(type: .system) : nil
        self.closeButton = hasButtons ? UIButton(type: .system) : nil
        super.init(frame: .zero)

        self.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.backgroundColor = theme.list.plainBackgroundColor
        // The chat screen keeps adding nodes after the cover
        self.layer.zPosition = 1000.0

        self.iconView.image = UIImage(bundleImageName: "Chat/Context Menu/Lock")?.withRenderingMode(.alwaysTemplate)
        self.iconView.tintColor = theme.list.itemSecondaryTextColor
        self.iconView.contentMode = .scaleAspectFit
        self.addSubview(self.iconView)

        self.titleLabel.text = title
        self.titleLabel.font = Font.semibold(17.0)
        self.titleLabel.textColor = theme.list.itemPrimaryTextColor
        self.titleLabel.textAlignment = .center
        self.titleLabel.numberOfLines = 0
        self.addSubview(self.titleLabel)

        if let unlockButton = self.unlockButton {
            unlockButton.setTitle("Открыть", for: .normal)
            unlockButton.titleLabel?.font = Font.semibold(17.0)
            unlockButton.setTitleColor(theme.list.itemAccentColor, for: .normal)
            unlockButton.addTarget(self, action: #selector(self.unlockPressed), for: .touchUpInside)
            self.addSubview(unlockButton)
        }
        if let closeButton = self.closeButton {
            closeButton.setTitle("Закрыть", for: .normal)
            closeButton.titleLabel?.font = Font.regular(17.0)
            closeButton.setTitleColor(theme.list.itemSecondaryTextColor, for: .normal)
            closeButton.addTarget(self, action: #selector(self.closePressed), for: .touchUpInside)
            self.addSubview(closeButton)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let size = self.bounds.size
        let iconSize = CGSize(width: 44.0, height: 44.0)
        let width = max(1.0, size.width - 64.0)
        let titleSize = self.titleLabel.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        let buttonHeight: CGFloat = 44.0
        let buttons: [UIButton] = [self.unlockButton, self.closeButton].compactMap { $0 }
        let buttonsHeight = buttons.isEmpty ? 0.0 : 24.0 + buttonHeight * CGFloat(buttons.count)
        var y = floor((size.height - (iconSize.height + 16.0 + titleSize.height + buttonsHeight)) / 2.0)
        self.iconView.frame = CGRect(origin: CGPoint(x: floor((size.width - iconSize.width) / 2.0), y: y), size: iconSize)
        y += iconSize.height + 16.0
        self.titleLabel.frame = CGRect(origin: CGPoint(x: floor((size.width - titleSize.width) / 2.0), y: y), size: titleSize)
        y += titleSize.height + 24.0
        for button in buttons {
            button.frame = CGRect(x: 32.0, y: y, width: width, height: buttonHeight)
            y += buttonHeight
        }
    }

    @objc private func unlockPressed() {
        self.unlock?()
    }

    @objc private func closePressed() {
        self.close?()
    }
}

public enum KalgramChatScreenEvent {
    case willAppear
    case didAppear
}

public final class KalgramChatLock {
    public static let shared = KalgramChatLock()

    private struct GrantKey: Hashable {
        let account: Int64
        let peer: Int64
    }

    private final class WeakOwner {
        weak var value: AnyObject?

        init(_ value: AnyObject) {
            self.value = value
        }
    }

    private final class Grant {
        var controllers: [WeakOwner] = []
        // A check passed and the chat screen is about to be created
        var pendingUntil: UInt64 = 0

        func isAlive(now: UInt64) -> Bool {
            self.controllers.removeAll(where: { $0.value == nil })
            return !self.controllers.isEmpty || now < self.pendingUntil
        }
    }

    private final class Screen {
        weak var controller: ChatController?
        let context: AccountContext
        let peerId: EnginePeer.Id
        var isPreview: Bool
        var cover: KalgramLockCoverView?

        init(controller: ChatController, context: AccountContext, peerId: EnginePeer.Id, isPreview: Bool) {
            self.controller = controller
            self.context = context
            self.peerId = peerId
            self.isPreview = isPreview
        }
    }

    private var grants: [GrantKey: Grant] = [:]
    private var unlockedAccounts = Set<Int64>()
    private var screens: [ObjectIdentifier: Screen] = [:]
    private var backgroundedAt: UInt64?
    private var observers: [NSObjectProtocol] = []

    private init() {
        let center = NotificationCenter.default
        self.observers.append(center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main, using: { [weak self] _ in
            self?.applicationDidEnterBackground()
        }))
        self.observers.append(center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main, using: { [weak self] _ in
            self?.applicationDidBecomeActive()
        }))
    }

    private static func now() -> UInt64 {
        return clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)
    }

    private func isProtected(account: EnginePeer.Id, peerId: EnginePeer.Id) -> Bool {
        return KalgramChatLockSettings.hidesContent(accountPeerId: account, peerId: peerId)
    }

    private func needsUnlock(account: EnginePeer.Id, peerId: EnginePeer.Id, controller: AnyObject?) -> Bool {
        let folder = KalgramChatLockSettings.isFolderProtected(accountPeerId: account, peerId: peerId)
        if !folder && !KalgramChatLockSettings.isChatLockProtected(accountPeerId: account, peerId: peerId) {
            return false
        }
        if let grant = self.grants[GrantKey(account: account.toInt64(), peer: peerId.toInt64())], grant.isAlive(now: KalgramChatLock.now()) {
            if let controller, !grant.controllers.contains(where: { $0.value === controller }) {
                // The screen the check was for exists now: from here the grant lives with it
                grant.controllers.append(WeakOwner(controller))
                grant.pendingUntil = 0
            }
            return false
        }
        if folder {
            return true
        }
        return !(KalgramChatLockSettings.autolock && self.unlockedAccounts.contains(account.toInt64()))
    }

    private func grant(account: EnginePeer.Id, peerId: EnginePeer.Id, controller: AnyObject?) {
        let key = GrantKey(account: account.toInt64(), peer: peerId.toInt64())
        let grant = self.grants[key] ?? Grant()
        if let controller {
            grant.controllers.append(WeakOwner(controller))
        } else {
            grant.pendingUntil = KalgramChatLock.now() + 15 * 1_000_000_000
        }
        self.grants[key] = grant
        if KalgramChatLockSettings.autolock && KalgramChatLockSettings.isChatLockProtected(accountPeerId: account, peerId: peerId) {
            self.unlockedAccounts.insert(account.toInt64())
        }
        let now = KalgramChatLock.now()
        for (key, grant) in self.grants where !grant.isAlive(now: now) {
            self.grants.removeValue(forKey: key)
        }
    }

    // MARK: Chat screens

    public func screenEvent(_ event: KalgramChatScreenEvent, controller: ChatController, context: AccountContext, peerId: EnginePeer.Id?, isPreview: Bool) {
        guard let peerId else {
            return
        }
        let account = context.account.peerId
        let id = ObjectIdentifier(controller)
        switch event {
        case .willAppear:
            self.pruneScreens()
            let tracked = KalgramChatLockSettings.isChatLockProtected(accountPeerId: account, peerId: peerId) || KalgramChatLockSettings.isInSecretFolder(accountPeerId: account, peerId: peerId)
            if !tracked {
                if let entry = self.screens.removeValue(forKey: id) {
                    self.uncover(entry)
                }
                return
            }
            let entry = self.screens[id] ?? Screen(controller: controller, context: context, peerId: peerId, isPreview: isPreview)
            entry.isPreview = isPreview
            self.screens[id] = entry
            // A peek never opens a chat, even an unlocked one
            if isPreview {
                if self.isProtected(account: account, peerId: peerId) {
                    self.cover(entry)
                }
            } else if self.needsUnlock(account: account, peerId: peerId, controller: controller) {
                self.cover(entry)
            } else {
                self.uncover(entry)
            }
        case .didAppear:
            guard let entry = self.screens[id] else {
                return
            }
            entry.isPreview = isPreview
            if entry.cover != nil && !isPreview {
                if !self.needsUnlock(account: account, peerId: peerId, controller: controller) {
                    self.uncover(entry)
                } else if UIApplication.shared.applicationState == .active {
                    self.ask(entry)
                }
            }
        }
    }

    private func pruneScreens() {
        for (key, screen) in self.screens where screen.controller == nil {
            self.screens.removeValue(forKey: key)
        }
    }

    private func cover(_ screen: Screen) {
        guard let controller = screen.controller else {
            return
        }
        controller.canReadHistory.set(false)
        if let cover = screen.cover {
            controller.view.bringSubviewToFront(cover)
            return
        }
        let presentationData = screen.context.sharedContext.currentPresentationData.with { $0 }
        let cover = KalgramLockCoverView(theme: presentationData.theme, title: "Чат защищён", hasButtons: !screen.isPreview)
        cover.unlock = { [weak self, weak screen] in
            guard let self, let screen else {
                return
            }
            self.ask(screen)
        }
        cover.close = { [weak screen] in
            guard let controller = screen?.controller else {
                return
            }
            KalgramChatLock.close(controller)
        }
        cover.frame = controller.view.bounds
        controller.view.addSubview(cover)
        screen.cover = cover
    }

    private func uncover(_ screen: Screen) {
        if let cover = screen.cover {
            screen.cover = nil
            cover.removeFromSuperview()
            screen.controller?.canReadHistory.set(true)
        }
    }

    private func ask(_ screen: Screen) {
        guard let controller = screen.controller else {
            return
        }
        let account = screen.context.account.peerId
        let peerId = screen.peerId
        KalgramLocalAuth.authenticate(reason: "Открыть защищённый чат", completion: { [weak self, weak controller] granted in
            guard let self, let controller, granted else {
                return
            }
            self.grant(account: account, peerId: peerId, controller: controller)
            if let entry = self.screens[ObjectIdentifier(controller)] {
                self.uncover(entry)
            }
        })
    }

    private static func close(_ controller: ChatController) {
        if let navigationController = controller.navigationController as? NavigationController, navigationController.viewControllers.contains(where: { $0 === controller }) {
            navigationController.filterController(controller, animated: true)
        } else {
            controller.dismiss()
        }
    }

    // MARK: Opening a chat

    // true: the check took the navigation over
    public func interceptOpen(context: AccountContext, peerId: EnginePeer.Id, proceed: @escaping () -> Void) -> Bool {
        let account = context.account.peerId
        if !self.needsUnlock(account: account, peerId: peerId, controller: nil) {
            return false
        }
        KalgramLocalAuth.authenticate(reason: "Открыть защищённый чат", completion: { [weak self] granted in
            guard let self, granted else {
                return
            }
            self.grant(account: account, peerId: peerId, controller: nil)
            proceed()
        })
        return true
    }

    // MARK: App lifecycle

    private func applicationDidEnterBackground() {
        KalgramChatLockSettings.lockSecretFolders()
        self.backgroundedAt = KalgramChatLock.now()
        let autolock = KalgramChatLockSettings.autolock
        let immediately = autolock && KalgramChatLockSettings.autolockSeconds <= 0
        if immediately {
            self.unlockedAccounts.removeAll()
            self.grants.removeAll()
        } else {
            // The folder's chats follow the folder: it locks on every trip to the background
            for key in Array(self.grants.keys) {
                let account = EnginePeer.Id(key.account)
                let peer = EnginePeer.Id(key.peer)
                if KalgramChatLockSettings.isFolderProtected(accountPeerId: account, peerId: peer) {
                    self.grants.removeValue(forKey: key)
                }
            }
        }
        self.pruneScreens()
        for screen in self.screens.values {
            guard let controller = screen.controller, controller.view.window != nil else {
                continue
            }
            let account = screen.context.account.peerId
            let chatLock = KalgramChatLockSettings.isChatLockProtected(accountPeerId: account, peerId: screen.peerId)
            let folder = KalgramChatLockSettings.isFolderProtected(accountPeerId: account, peerId: screen.peerId)
            if !chatLock && !folder {
                continue
            }
            // The app switcher's snapshot is taken after this: show the cover, not the chat
            if autolock || folder || screen.isPreview {
                self.cover(screen)
            }
            if immediately && chatLock && !screen.isPreview {
                KalgramChatLock.close(controller)
            }
        }
    }

    // Only a return from the background counts: a system prompt (Face ID) also makes the app
    // inactive and active again, and must not ask once more
    private func applicationDidBecomeActive() {
        guard let backgroundedAt = self.backgroundedAt else {
            return
        }
        self.backgroundedAt = nil
        let elapsed = Double(KalgramChatLock.now() &- backgroundedAt) / 1_000_000_000.0
        if KalgramChatLockSettings.autolock && elapsed >= Double(KalgramChatLockSettings.autolockSeconds) {
            self.unlockedAccounts.removeAll()
            self.grants.removeAll()
        }
        self.pruneScreens()
        for screen in self.screens.values where screen.cover != nil && !screen.isPreview {
            guard let controller = screen.controller else {
                continue
            }
            if !self.needsUnlock(account: screen.context.account.peerId, peerId: screen.peerId, controller: controller) {
                self.uncover(screen)
            } else if controller.view.window != nil {
                self.ask(screen)
            }
        }
    }
}
