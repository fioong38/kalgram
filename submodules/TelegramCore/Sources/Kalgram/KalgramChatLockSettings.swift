import Foundation
import Postbox
import SwiftSignalKit

// kalgram: which chats are protected. Configuration only, adapted from Ghostgram (GPLv2). The unlock
// state of a chat lives with the screens, in SGSettingsUI's KalgramChatLock. Row layout asks this for
// every row, so the chat lists are kept in memory and nothing here touches the disk or a Postbox
// transaction once loaded.
public enum KalgramChatLockSettings {
    private static let enabledKey = "kalgram.chatLock.enabled"
    private static let allChatsKey = "kalgram.chatLock.allChats"
    private static let autolockKey = "kalgram.chatLock.autolock"
    private static let autolockSecondsKey = "kalgram.chatLock.autolockSeconds"
    private static let screenshotPrivacyKey = "kalgram.screenshotPrivacy"
    private static let screenshotPrivacyChatListKey = "kalgram.screenshotPrivacy.chatList"
    private static let accountSwitchAuthKey = "kalgram.accountSwitchAuth"

    // Telegram's service notifications carry login codes and stay readable
    private static let serviceNotificationsId: Int64 = 777000

    // Face ID, Touch ID or the device passcode before a chat opens
    public static var isEnabled: Bool {
        get {
            return UserDefaults.standard.bool(forKey: enabledKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: enabledKey)
        }
    }

    public static var allChats: Bool {
        get {
            return UserDefaults.standard.bool(forKey: allChatsKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: allChatsKey)
        }
    }

    // One check opens every protected chat until the app has been away for autolockSeconds
    public static var autolock: Bool {
        get {
            return UserDefaults.standard.bool(forKey: autolockKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: autolockKey)
        }
    }

    public static let autolockChoices: [Int32] = [0, 15, 60, 5 * 60, 15 * 60, 60 * 60]

    public static var autolockSeconds: Int32 {
        get {
            return Int32(UserDefaults.standard.object(forKey: autolockSecondsKey) as? Int ?? 60)
        }
        set {
            UserDefaults.standard.set(Int(newValue), forKey: autolockSecondsKey)
        }
    }

    // The chat's header, input panel and panels come out empty on screenshots and recordings
    public static var screenshotPrivacy: Bool {
        get {
            return UserDefaults.standard.bool(forKey: screenshotPrivacyKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: screenshotPrivacyKey)
        }
    }

    public static var screenshotPrivacyChatList: Bool {
        get {
            return UserDefaults.standard.bool(forKey: screenshotPrivacyChatListKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: screenshotPrivacyChatListKey)
        }
    }

    public static var accountSwitchAuth: Bool {
        get {
            return UserDefaults.standard.bool(forKey: accountSwitchAuthKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: accountSwitchAuthKey)
        }
    }

    // MARK: Lists of chats, separately for every account

    private static let cachedLists = Atomic<[String: Set<Int64>]>(value: [:])

    private static func list(_ key: String) -> Set<Int64> {
        if let cached = cachedLists.with({ $0[key] }) {
            return cached
        }
        let stored = UserDefaults.standard.array(forKey: key) as? [NSNumber] ?? []
        let value = Set(stored.map { $0.int64Value })
        let _ = cachedLists.modify { current in
            var current = current
            current[key] = value
            return current
        }
        return value
    }

    private static func setList(_ value: Set<Int64>, key: String) {
        UserDefaults.standard.set(value.map { NSNumber(value: $0) }, forKey: key)
        let _ = cachedLists.modify { current in
            var current = current
            current[key] = value
            return current
        }
    }

    private static func accountKey(_ name: String, _ accountPeerId: PeerId) -> String {
        return "kalgram.chatLock.\(accountPeerId.toInt64()).\(name)"
    }

    public static func protectedPeerCount(accountPeerId: PeerId) -> Int {
        return list(accountKey("peers", accountPeerId)).count
    }

    public static func isInProtectedList(peerId: PeerId, accountPeerId: PeerId) -> Bool {
        return list(accountKey("peers", accountPeerId)).contains(peerId.toInt64())
    }

    public static func setInProtectedList(_ value: Bool, peerId: PeerId, accountPeerId: PeerId) {
        let key = accountKey("peers", accountPeerId)
        var peers = list(key)
        if value {
            peers.insert(peerId.toInt64())
        } else {
            peers.remove(peerId.toInt64())
        }
        setList(peers, key: key)
    }

    public static func clearProtectedList(accountPeerId: PeerId) {
        setList(Set(), key: accountKey("peers", accountPeerId))
    }

    // MARK: Secret folder

    public static func secretFolderId(accountPeerId: PeerId) -> Int32 {
        return Int32(UserDefaults.standard.integer(forKey: accountKey("folder", accountPeerId)))
    }

    public static func setSecretFolderId(_ value: Int32, accountPeerId: PeerId) {
        UserDefaults.standard.set(Int(value), forKey: accountKey("folder", accountPeerId))
        secretFolderDidChange.set(secretFolderRevision.modify { $0 + 1 })
    }

    public static func secretFolderProtectsChats(accountPeerId: PeerId) -> Bool {
        return UserDefaults.standard.bool(forKey: accountKey("folderProtects", accountPeerId))
    }

    public static func setSecretFolderProtectsChats(_ value: Bool, accountPeerId: PeerId) {
        UserDefaults.standard.set(value, forKey: accountKey("folderProtects", accountPeerId))
        if !value {
            setSecretFolderPeers([], accountPeerId: accountPeerId)
        }
    }

    public static func setSecretFolderPeers(_ peers: Set<Int64>, accountPeerId: PeerId) {
        setList(peers, key: accountKey("folderPeers", accountPeerId))
    }

    private static let secretFolderRevision = Atomic<Int>(value: 0)
    private static let secretFolderDidChange = ValuePromise<Int>(0, ignoreRepeated: true)
    private static let unlockedFolders = Atomic<Set<Int64>>(value: Set())
    private static let unlockedFoldersPromise = ValuePromise<Set<Int64>>(Set(), ignoreRepeated: true)

    public static func isSecretFolderUnlocked(accountPeerId: PeerId) -> Bool {
        return unlockedFolders.with { $0.contains(accountPeerId.toInt64()) }
    }

    public static func unlockSecretFolder(accountPeerId: PeerId) {
        unlockedFoldersPromise.set(unlockedFolders.modify { current in
            var current = current
            current.insert(accountPeerId.toInt64())
            return current
        })
    }

    public static func lockSecretFolders() {
        unlockedFoldersPromise.set(unlockedFolders.modify { _ in Set() })
    }

    // The folder that must stay out of the tabs right now; 0 when there is none
    public static func hiddenFolderId(accountPeerId: PeerId) -> Signal<Int32, NoError> {
        let key = accountPeerId.toInt64()
        return combineLatest(secretFolderDidChange.get(), unlockedFoldersPromise.get())
        |> map { _, unlocked -> Int32 in
            return unlocked.contains(key) ? 0 : secretFolderId(accountPeerId: accountPeerId)
        }
        |> distinctUntilChanged
    }

    // MARK: Questions

    private static let secretChatUsers = Atomic<[Int64: Int64]>(value: [:])

    // A protected person's secret chat is protected too
    public static func noteSecretChat(peerId: PeerId, userId: PeerId) {
        let key = peerId.toInt64()
        let value = userId.toInt64()
        if secretChatUsers.with({ $0[key] == value }) {
            return
        }
        let _ = secretChatUsers.modify { current in
            var current = current
            current[key] = value
            return current
        }
    }

    public static func isLockable(_ peerId: PeerId) -> Bool {
        return !(peerId.namespace == Namespaces.Peer.CloudUser && peerId.id._internalGetInt64Value() == serviceNotificationsId)
    }

    public static func isChatLockProtected(accountPeerId: PeerId, peerId: PeerId) -> Bool {
        if !isEnabled {
            return false
        }
        if allChats {
            return isLockable(peerId)
        }
        let peers = list(accountKey("peers", accountPeerId))
        if peers.isEmpty {
            return false
        }
        if peers.contains(peerId.toInt64()) {
            return true
        }
        if peerId.namespace == Namespaces.Peer.SecretChat, let user = secretChatUsers.with({ $0[peerId.toInt64()] }) {
            return peers.contains(user)
        }
        return false
    }

    public static func isInSecretFolder(accountPeerId: PeerId, peerId: PeerId) -> Bool {
        return list(accountKey("folderPeers", accountPeerId)).contains(peerId.toInt64())
    }

    public static func isFolderProtected(accountPeerId: PeerId, peerId: PeerId) -> Bool {
        return isInSecretFolder(accountPeerId: accountPeerId, peerId: peerId) && !isSecretFolderUnlocked(accountPeerId: accountPeerId)
    }

    // Lists, search and notifications hide the chat's content, whatever is unlocked at the moment
    public static func hidesContent(accountPeerId: PeerId, peerId: PeerId) -> Bool {
        return isChatLockProtected(accountPeerId: accountPeerId, peerId: peerId) || isFolderProtected(accountPeerId: accountPeerId, peerId: peerId)
    }
}
