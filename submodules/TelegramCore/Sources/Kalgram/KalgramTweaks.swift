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

    // How kalgram gets new messages while it is in the background (a sideloaded
    // build receives no pushes from Telegram):
    // - off: only when opened (and ntfy wake-ups, if set up);
    // - refresh: iOS wakes the app now and then (it decides when, from minutes to
    //   hours), the app fetches what is new and shows notifications;
    // - alwaysOn: a silent sound keeps the app running, messages arrive at once.
    //   Costs battery; stops by itself in Low Power Mode and below 20% charge.
    public enum BackgroundMode: String, CaseIterable {
        case off
        case refresh
        case alwaysOn
    }

    public static let backgroundModeKey = "kalgram.background.mode"
    public static let backgroundModeDidChangeNotification = Notification.Name("KalgramBackgroundModeDidChange")

    public static var backgroundMode: BackgroundMode {
        get {
            return UserDefaults.standard.string(forKey: backgroundModeKey).flatMap(BackgroundMode.init(rawValue:)) ?? .off
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: backgroundModeKey)
            NotificationCenter.default.post(name: backgroundModeDidChangeNotification, object: nil)
        }
    }

    // Text and media under a spoiler are visible at once. Off by default.
    public static let revealSpoilersKey = "kalgram.revealSpoilers"

    public static var revealSpoilers: Bool {
        get {
            return UserDefaults.standard.bool(forKey: revealSpoilersKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: revealSpoilersKey)
        }
    }

    // An empty private chat without the "say hello" sticker, which also means not loading it.
    public static let hideGreetingStickerKey = "kalgram.hideGreetingSticker"

    public static var hideGreetingSticker: Bool {
        get {
            return UserDefaults.standard.bool(forKey: hideGreetingStickerKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: hideGreetingStickerKey)
        }
    }

    // Up to 200 recent chats in search instead of 20.
    public static let longRecentSearchKey = "kalgram.longRecentSearch"

    public static var longRecentSearch: Bool {
        get {
            return UserDefaults.standard.bool(forKey: longRecentSearchKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: longRecentSearchKey)
        }
    }

    public static var recentSearchLimit: Int {
        return longRecentSearch ? 200 : 20
    }

    // More choices in the passcode's auto-lock menu.
    public static let moreAutolockKey = "kalgram.moreAutolock"

    public static var moreAutolock: Bool {
        get {
            return UserDefaults.standard.bool(forKey: moreAutolockKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: moreAutolockKey)
        }
    }

    public static let extraAutolockValues: [Int32] = [5, 2 * 60, 10 * 60, 15 * 60, 30 * 60, 2 * 60 * 60, 8 * 60 * 60, 24 * 60 * 60]

    public static func autolockTitle(_ timeout: Int32) -> String {
        if timeout < 60 {
            return "Через \(timeout) с"
        } else if timeout < 60 * 60 {
            return "Через \(timeout / 60) мин"
        } else {
            return "Через \(timeout / (60 * 60)) ч"
        }
    }

    // Any dark theme goes pure black.
    public static let amoledKey = "kalgram.amoled"

    public static var amoled: Bool {
        get {
            return UserDefaults.standard.bool(forKey: amoledKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: amoledKey)
        }
    }

    // No hairlines between rows and bars.
    public static let hideSeparatorsKey = "kalgram.hideSeparators"

    public static var hideSeparators: Bool {
        get {
            return UserDefaults.standard.bool(forKey: hideSeparatorsKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: hideSeparatorsKey)
        }
    }

    // The exact time after "last seen".
    public static let exactLastSeenKey = "kalgram.exactLastSeen"

    public static var exactLastSeen: Bool {
        get {
            return UserDefaults.standard.bool(forKey: exactLastSeenKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: exactLastSeenKey)
        }
    }

    // No blur under the message menu: cheaper for the GPU, too.
    public static let noSelectionBlurKey = "kalgram.noSelectionBlur"

    public static var noSelectionBlur: Bool {
        get {
            return UserDefaults.standard.bool(forKey: noSelectionBlurKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: noSelectionBlurKey)
        }
    }

    // No story rings on chat list avatars.
    public static let hideStoryRingsKey = "kalgram.hideStoryRings"

    public static var hideStoryRings: Bool {
        get {
            return UserDefaults.standard.bool(forKey: hideStoryRingsKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: hideStoryRingsKey)
        }
    }

    // No emoji statuses in the chat list, which also stops them animating.
    public static let hideEmojiStatusKey = "kalgram.hideEmojiStatus"

    public static var hideEmojiStatus: Bool {
        get {
            return UserDefaults.standard.bool(forKey: hideEmojiStatusKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: hideEmojiStatusKey)
        }
    }

    // Message bubbles without the tail.
    public static let hideBubbleTailsKey = "kalgram.hideBubbleTails"

    public static var hideBubbleTails: Bool {
        get {
            return UserDefaults.standard.bool(forKey: hideBubbleTailsKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: hideBubbleTailsKey)
        }
    }

    // No search field above the chat list.
    public static let hideSearchFieldKey = "kalgram.hideSearchField"

    public static var hideSearchField: Bool {
        get {
            return UserDefaults.standard.bool(forKey: hideSearchFieldKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: hideSearchFieldKey)
        }
    }

    // The passcode is asked on every cold start. Without a passcode set it does nothing.
    public static let lockOnLaunchKey = "kalgram.lockOnLaunch"

    public static var lockOnLaunch: Bool {
        get {
            return UserDefaults.standard.bool(forKey: lockOnLaunchKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: lockOnLaunchKey)
        }
    }

    // Avatars with rounded corners instead of circles.
    public static let squareAvatarsKey = "kalgram.squareAvatars"

    public static var squareAvatars: Bool {
        get {
            return UserDefaults.standard.bool(forKey: squareAvatarsKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: squareAvatarsKey)
        }
    }

    // No "edited" next to the time.
    public static let hideEditedMarkKey = "kalgram.hideEditedMark"

    public static var hideEditedMark: Bool {
        get {
            return UserDefaults.standard.bool(forKey: hideEditedMarkKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: hideEditedMarkKey)
        }
    }

    // No time on messages.
    public static let hideMessageTimeKey = "kalgram.hideMessageTime"

    public static var hideMessageTime: Bool {
        get {
            return UserDefaults.standard.bool(forKey: hideMessageTimeKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: hideMessageTimeKey)
        }
    }

    // No view counts on channel posts.
    public static let hideViewCountsKey = "kalgram.hideViewCounts"

    public static var hideViewCounts: Bool {
        get {
            return UserDefaults.standard.bool(forKey: hideViewCountsKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: hideViewCountsKey)
        }
    }

    // No comment buttons under channel posts.
    public static let hideChannelCommentsKey = "kalgram.hideChannelComments"

    public static var hideChannelComments: Bool {
        get {
            return UserDefaults.standard.bool(forKey: hideChannelCommentsKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: hideChannelCommentsKey)
        }
    }

    // Incoming messages as plain text, links and emoji stay.
    public static let hideFormattingIncomingKey = "kalgram.hideFormattingIncoming"

    public static var hideFormattingIncoming: Bool {
        get {
            return UserDefaults.standard.bool(forKey: hideFormattingIncomingKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: hideFormattingIncomingKey)
        }
    }

    // Own messages as plain text, links and emoji stay.
    public static let hideFormattingOutgoingKey = "kalgram.hideFormattingOutgoing"

    public static var hideFormattingOutgoing: Bool {
        get {
            return UserDefaults.standard.bool(forKey: hideFormattingOutgoingKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: hideFormattingOutgoingKey)
        }
    }

    // The chat list shows no message text.
    public static let hideChatPreviewKey = "kalgram.hideChatPreview"

    public static var hideChatPreview: Bool {
        get {
            return UserDefaults.standard.bool(forKey: hideChatPreviewKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: hideChatPreviewKey)
        }
    }

    // The chat list title stays while connecting.
    public static let hideConnectionTextKey = "kalgram.hideConnectionText"

    public static var hideConnectionText: Bool {
        get {
            return UserDefaults.standard.bool(forKey: hideConnectionTextKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: hideConnectionTextKey)
        }
    }

    // No channel pinned by an MTProxy.
    public static let hideProxySponsorKey = "kalgram.hideProxySponsor"

    public static var hideProxySponsor: Bool {
        get {
            return UserDefaults.standard.bool(forKey: hideProxySponsorKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: hideProxySponsorKey)
        }
    }

    // A numeric query finds peers this device knows by their id.
    public static let searchByIdKey = "kalgram.searchById"

    public static var searchById: Bool {
        get {
            return UserDefaults.standard.bool(forKey: searchByIdKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: searchByIdKey)
        }
    }

    // The chosen checkmark colors in the chat list too.
    public static let checkColorsInChatListKey = "kalgram.checkColorsInChatList"

    public static var checkColorsInChatList: Bool {
        get {
            return UserDefaults.standard.bool(forKey: checkColorsInChatListKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: checkColorsInChatListKey)
        }
    }

    // The "read" checkmarks. 0 keeps the theme's color.
    public static let readCheckColorKey = "kalgram.readCheckColor"

    public static var readCheckColor: Int {
        get {
            return UserDefaults.standard.integer(forKey: readCheckColorKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: readCheckColorKey)
        }
    }

    // The "delivered" checkmark. 0 keeps the theme's color.
    public static let sentCheckColorKey = "kalgram.sentCheckColor"

    public static var sentCheckColor: Int {
        get {
            return UserDefaults.standard.integer(forKey: sentCheckColorKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: sentCheckColorKey)
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
