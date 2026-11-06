import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import LocalizedPeerData
import UndoUI
import SGItemListUI
import SGSimpleSettings
import SGProUI

// kalgram: every setting of the mod, behind the "kalgram Pro" row in Settings.
// Ghost mode is shown for the account the screen was opened from.

private enum KalgramProSection: Int32, SGItemListSection {
    case ghostQuick
    case ghostPermanent
    case history
    case protection
    case security
    case sending
    case tweaks
    case background
    case notifications
    case badges
    case effects
    case roundVideo
    case study
    case proxy
    case interface
    case ads
    case energy
}

private enum KalgramProToggle: String {
    case ghostQuickEnabled
    case ghostQuickReadReceipts
    case ghostQuickTyping
    case ghostQuickOnline
    case ghostQuickStories
    case ghostPermanentReadReceipts
    case ghostPermanentTyping
    case ghostPermanentOnline
    case ghostPermanentStories
    case keepDeletedMessages
    case keepEditHistory
    case bypassProtection
    case keepSelfDestructing
    case bypassIosRestrictions
    case oldInterface
    case adsHideSponsored
    case adsHideSimilarChannels
    case adsHideSearchAds
    case adsHidePremiumPromo
    case effectRemoveBackground
    case studyEnabled
    case proxyAutoSwitch
    case proxyRespectVpn
    case sendingAntiCaps
    case sendingWordReplacement
    case sendingDelay
    case ghostReadOnAction
    case revealSpoilers
    case hideGreetingSticker
    case longRecentSearch
    case moreAutolock
    case hideBlockedMessages
    case amoled
    case hideSeparators
    case exactLastSeen
    case noSelectionBlur
    case hideStoryRings
    case hideEmojiStatus
    case hideBubbleTails
    case hideSearchField
    case lockOnLaunch
    case chatLockEnabled
    case chatLockAllChats
    case chatLockAutolock
    case screenshotPrivacy
    case screenshotPrivacyChatList
    case accountSwitchAuth
    case secretFolderProtects
}

private enum KalgramProSlider: String {
    case effectDensity
    case effectSpeed
    case effectSize
    case effectSizeSpread
    case effectSpin
    case effectSpinSpread
    case effectOpacity
}

private enum KalgramProSelector: String {
    case effectStyle
    case effectDirection
    case backgroundMode
    case roundVideoQuality
    case studyInterval
    case sendingDelaySeconds
    case chatLockTimeout
    case secretFolder
}

private enum KalgramProLink: String {
    case ntfyCopyTopic
    case badges
    case effectAddImage
    case effectRemoveImages
    case sendingAddRule
    case sendingRemoveRules
    case chatLockClear
    case secretFolderOpen
}

private enum KalgramProAction: Hashable {
    case ntfySendTest
    case ntfyCheckTelegram
}

private struct KalgramProState: Equatable {
    var ntfyCheckResult: String?
}

private typealias KalgramProEntry = SGItemListUIEntry<KalgramProSection, KalgramProToggle, KalgramProSlider, KalgramProSelector, KalgramProLink, KalgramProAction>

private let oldInterfaceKey = "kalgram.oldInterface"

private func backgroundModeTitle(_ mode: KalgramTweaks.BackgroundMode) -> String {
    switch mode {
    case .off:
        return "Выключено"
    case .refresh:
        return "Фоновое обновление iOS"
    case .alwaysOn:
        return "Постоянно (как Ghostgram)"
    }
}

private func effectStyleTitle(_ style: String) -> String {
    switch style {
    case SGSimpleSettings.NYStyle.snow.rawValue:
        return "❄️ Снег"
    case SGSimpleSettings.NYStyle.lightning.rawValue:
        return "⚡️ Молнии"
    case SGSimpleSettings.NYStyle.custom.rawValue:
        return "🖼 Своя картинка"
    default:
        return "Выключено"
    }
}

private func effectDirectionTitle(_ direction: KalgramEffectSettings.Direction) -> String {
    switch direction {
    case .down:
        return "Вниз, как снег"
    case .up:
        return "Вверх, пузырьки"
    case .sway:
        return "Качаясь, с ветром"
    }
}

private func roundVideoQualityTitle(_ quality: String) -> String {
    switch quality {
    case SGSimpleSettings.RoundVideoQualityValues.high.rawValue:
        return "Высокое (640 px)"
    case SGSimpleSettings.RoundVideoQualityValues.maximum.rawValue:
        return "Максимальное (800 px)"
    default:
        return "Стандарт (480 px)"
    }
}

// A change that weakens protection asks first, a change that strengthens it does not. Without this an
// unlocked phone in someone else's hands could switch protection off from here.
private func kalgramChangeSecurity(weakens: Bool, reload: @escaping () -> Void, apply: @escaping () -> Void) {
    if !weakens {
        apply()
        reload()
        return
    }
    KalgramLocalAuth.authenticate(reason: "Изменить настройки безопасности", completion: { granted in
        if granted {
            apply()
        }
        reload()
    })
}

private func chatLockTimeoutTitle(_ seconds: Int32) -> String {
    if seconds <= 0 {
        return "Сразу (и закрыть чат)"
    } else if seconds < 60 {
        return "\(seconds) с"
    } else if seconds < 60 * 60 {
        return "\(seconds / 60) мин"
    } else {
        return "\(seconds / (60 * 60)) ч"
    }
}

private func kalgramProEntries(accountPeerId: EnginePeer.Id, accountName: String, state: KalgramProState) -> [KalgramProEntry] {
    var entries: [KalgramProEntry] = []
    let id = SGItemListCounter()

    let quickEnabled = KalgramGhost.isQuickEnabled(accountPeerId: accountPeerId)
    entries.append(.header(id: id.count, section: .ghostQuick, text: "👻 ПРИЗРАК — \(accountName.uppercased())", badge: nil))
    entries.append(.toggle(id: id.count, section: .ghostQuick, settingName: .ghostQuickEnabled, value: quickEnabled, text: "Включён (кнопка 👻)", enabled: true))
    entries.append(.toggle(id: id.count, section: .ghostQuick, settingName: .ghostQuickReadReceipts, value: KalgramGhost.isInQuickSet(.readReceipts, accountPeerId: accountPeerId), text: "Не отправлять «прочитано»", enabled: true))
    entries.append(.toggle(id: id.count, section: .ghostQuick, settingName: .ghostQuickTyping, value: KalgramGhost.isInQuickSet(.typing, accountPeerId: accountPeerId), text: "Скрывать «печатает»", enabled: true))
    entries.append(.toggle(id: id.count, section: .ghostQuick, settingName: .ghostQuickOnline, value: KalgramGhost.isInQuickSet(.online, accountPeerId: accountPeerId), text: "Не показывать онлайн", enabled: true))
    entries.append(.toggle(id: id.count, section: .ghostQuick, settingName: .ghostQuickStories, value: KalgramGhost.isInQuickSet(.stories, accountPeerId: accountPeerId), text: "Невидимый просмотр историй", enabled: true))
    entries.append(.notice(id: id.count, section: .ghostQuick, text: "Только для этого аккаунта. Кнопка 👻 рядом с «Изм.» включает и выключает отмеченное; долгий тап по ней открывает этот экран. У других аккаунтов свои настройки, выбранное запоминается."))

    entries.append(.header(id: id.count, section: .ghostPermanent, text: "🔒 ПРИЗРАК ВСЕГДА", badge: nil))
    entries.append(.toggle(id: id.count, section: .ghostPermanent, settingName: .ghostPermanentReadReceipts, value: KalgramGhost.isPermanent(.readReceipts, accountPeerId: accountPeerId), text: "Не отправлять «прочитано»", enabled: true))
    entries.append(.toggle(id: id.count, section: .ghostPermanent, settingName: .ghostPermanentTyping, value: KalgramGhost.isPermanent(.typing, accountPeerId: accountPeerId), text: "Скрывать «печатает»", enabled: true))
    entries.append(.toggle(id: id.count, section: .ghostPermanent, settingName: .ghostPermanentOnline, value: KalgramGhost.isPermanent(.online, accountPeerId: accountPeerId), text: "Не показывать онлайн", enabled: true))
    entries.append(.toggle(id: id.count, section: .ghostPermanent, settingName: .ghostPermanentStories, value: KalgramGhost.isPermanent(.stories, accountPeerId: accountPeerId), text: "Невидимый просмотр историй", enabled: true))
    entries.append(.toggle(id: id.count, section: .ghostPermanent, settingName: .ghostReadOnAction, value: KalgramOutgoing.isReadOnAction(accountPeerId: accountPeerId), text: "Читать при ответе и реакции", enabled: true))
    entries.append(.notice(id: id.count, section: .ghostPermanent, text: "Работает на этом аккаунте всегда, с первой секунды после входа, кнопка 👻 на это не влияет. «Читать при ответе и реакции»: пока «прочитано» скрыто, ответ или реакция отмечают прочитанным этот чат. Отправка с задержкой ничего не отмечает."))

    entries.append(.header(id: id.count, section: .history, text: "ЛИЧНЫЕ ЧАТЫ", badge: nil))
    entries.append(.toggle(id: id.count, section: .history, settingName: .keepDeletedMessages, value: KalgramTweaks.keepDeletedMessages, text: "Сохранять удалённые", enabled: true))
    entries.append(.toggle(id: id.count, section: .history, settingName: .keepEditHistory, value: KalgramTweaks.keepEditHistory, text: "Сохранять историю правок", enabled: true))
    entries.append(.notice(id: id.count, section: .history, text: "Удалённое собеседником остаётся, у времени появляется «удалено» — эту пометку ставит kalgram, текстом её не подделать. У изменённого ниже видно «✏️ было: …». Сохраняются сообщения, которые kalgram успел загрузить: если сообщение пришло и удалилось, пока приложение было закрыто, телефон его не получал."))

    entries.append(.header(id: id.count, section: .protection, text: "ОБХОДЫ", badge: nil))
    entries.append(.toggle(id: id.count, section: .protection, settingName: .bypassProtection, value: KalgramTweaks.bypassProtection, text: "Сохранять и скринить защищённое", enabled: true))
    entries.append(.toggle(id: id.count, section: .protection, settingName: .keepSelfDestructing, value: KalgramTweaks.keepSelfDestructing, text: "Сохранять одноразки", enabled: true))
    entries.append(.toggle(id: id.count, section: .protection, settingName: .bypassIosRestrictions, value: KalgramTweaks.bypassIosRestrictions, text: "Открывать каналы, скрытые на iOS", enabled: true))
    entries.append(.notice(id: id.count, section: .protection, text: "Одноразки не исчезают, и отправитель не видит, что ты открыл. Отметить просмотренной: долгий тап по сообщению → «🔥 Сжечь». Каналы с пометкой «нарушал правила App Store» открываются; блокировки по закону остаются."))

    let chatLockEnabled = KalgramChatLockSettings.isEnabled
    let protectedCount = KalgramChatLockSettings.protectedPeerCount(accountPeerId: accountPeerId)
    let secretFolderId = KalgramChatLockSettings.secretFolderId(accountPeerId: accountPeerId)
    entries.append(.header(id: id.count, section: .security, text: "🔐 ЗАЩИТА ЧАТОВ", badge: nil))
    entries.append(.toggle(id: id.count, section: .security, settingName: .chatLockEnabled, value: chatLockEnabled, text: "Пароль на чаты", enabled: true))
    entries.append(.toggle(id: id.count, section: .security, settingName: .chatLockAllChats, value: KalgramChatLockSettings.allChats, text: "Все чаты", enabled: chatLockEnabled))
    entries.append(.toggle(id: id.count, section: .security, settingName: .chatLockAutolock, value: KalgramChatLockSettings.autolock, text: "Автоблокировка", enabled: chatLockEnabled))
    entries.append(.oneFromManySelector(id: id.count, section: .security, settingName: .chatLockTimeout, text: "Таймер автоблокировки", value: chatLockTimeoutTitle(KalgramChatLockSettings.autolockSeconds), enabled: chatLockEnabled && KalgramChatLockSettings.autolock))
    if protectedCount > 0 {
        entries.append(.disclosure(id: id.count, section: .security, link: .chatLockClear, text: "Снять защиту со всех (\(protectedCount))"))
    }
    entries.append(.notice(id: id.count, section: .security, text: "Face ID, Touch ID или код iPhone перед открытием чата. Чат защищается в его профиле: «…» → «Защитить чат паролем». Без автоблокировки чат запирается, как только ты из него вышел; с ней одна проверка открывает все защищённые чаты, пока приложение не пробудет в фоне дольше таймера. Текст защищённых чатов не видно в списке, поиске, баннерах и уведомлениях kalgram. Сервер уведомлений на VPS про защиту не знает: его текст настраивается там отдельно."))
    entries.append(.toggle(id: id.count, section: .security, settingName: .accountSwitchAuth, value: KalgramChatLockSettings.accountSwitchAuth, text: "Face ID при смене аккаунта", enabled: true))
    entries.append(.toggle(id: id.count, section: .security, settingName: .screenshotPrivacy, value: KalgramChatLockSettings.screenshotPrivacy, text: "Скрывать чат на скриншотах", enabled: true))
    entries.append(.toggle(id: id.count, section: .security, settingName: .screenshotPrivacyChatList, value: KalgramChatLockSettings.screenshotPrivacyChatList, text: "И список чатов", enabled: KalgramChatLockSettings.screenshotPrivacy))
    entries.append(.notice(id: id.count, section: .security, text: "На скриншотах и записи экрана пустыми выходят шапка чата, поле ввода и панели, сами сообщения остаются."))
    entries.append(.header(id: id.count, section: .security, text: "СЕКРЕТНАЯ ПАПКА", badge: nil))
    entries.append(.oneFromManySelector(id: id.count, section: .security, settingName: .secretFolder, text: "Какая папка", value: secretFolderId == 0 ? "Нет" : "Выбрана", enabled: true))
    entries.append(.toggle(id: id.count, section: .security, settingName: .secretFolderProtects, value: KalgramChatLockSettings.secretFolderProtectsChats(accountPeerId: accountPeerId), text: "Защищать чаты папки", enabled: secretFolderId != 0))
    if secretFolderId != 0 {
        entries.append(.disclosure(id: id.count, section: .security, link: .secretFolderOpen, text: "Открыть секретную папку"))
    }
    entries.append(.notice(id: id.count, section: .security, text: "Запертая папка пропадает из вкладок и выбора папок. Открывается только отсюда и запирается при сворачивании приложения. У каждого аккаунта своя."))

    let sendingRules = KalgramOutgoing.rules
    entries.append(.header(id: id.count, section: .sending, text: "ОТПРАВКА", badge: nil))
    entries.append(.toggle(id: id.count, section: .sending, settingName: .sendingAntiCaps, value: KalgramOutgoing.antiCaps, text: "Анти-капс", enabled: true))
    entries.append(.toggle(id: id.count, section: .sending, settingName: .sendingWordReplacement, value: KalgramOutgoing.wordReplacement, text: "Автозамена слов", enabled: true))
    entries.append(.disclosure(id: id.count, section: .sending, link: .sendingAddRule, text: "Добавить правило замены"))
    if !sendingRules.isEmpty {
        entries.append(.disclosure(id: id.count, section: .sending, link: .sendingRemoveRules, text: "Убрать все правила"))
    }
    var sendingNotice = "Анти-капс: ПРИВЕТ ВСЕМ → Привет всем. Автозамена меняет только целые слова, без учёта регистра. Ссылки, упоминания, команды и код не трогаются, ботам текст уходит как есть."
    if !sendingRules.isEmpty {
        sendingNotice += "\n\nПравила:\n" + sendingRules.map { "\($0.source) → \($0.replacement)" }.joined(separator: "\n")
    }
    entries.append(.notice(id: id.count, section: .sending, text: sendingNotice))
    let sendDelayEnabled = KalgramOutgoing.isSendDelayEnabled(accountPeerId: accountPeerId)
    entries.append(.toggle(id: id.count, section: .sending, settingName: .sendingDelay, value: sendDelayEnabled, text: "Отправлять с задержкой", enabled: true))
    entries.append(.oneFromManySelector(id: id.count, section: .sending, settingName: .sendingDelaySeconds, text: "Задержка", value: "\(KalgramOutgoing.sendDelaySeconds(accountPeerId: accountPeerId)) с", enabled: sendDelayEnabled))
    entries.append(.notice(id: id.count, section: .sending, text: "Только для этого аккаунта. Сообщение уходит как отложенное: его доставляет сервер, а ты не появляешься «в сети», даже если приложение закрыть. До отправки оно лежит в «Отложенных», а не в чате. Не действует в «Избранном», секретных чатах, с ботами, для платных и одноразовых сообщений."))

    entries.append(.header(id: id.count, section: .tweaks, text: "МЕЛОЧИ", badge: nil))
    entries.append(.toggle(id: id.count, section: .tweaks, settingName: .hideBlockedMessages, value: KalgramBlockedPeers.isEnabled, text: "Скрыть сообщения заблокированных", enabled: true))
    entries.append(.toggle(id: id.count, section: .tweaks, settingName: .revealSpoilers, value: KalgramTweaks.revealSpoilers, text: "Анти-спойлер", enabled: true))
    entries.append(.toggle(id: id.count, section: .tweaks, settingName: .hideGreetingSticker, value: KalgramTweaks.hideGreetingSticker, text: "Без приветственного стикера", enabled: true))
    entries.append(.toggle(id: id.count, section: .tweaks, settingName: .longRecentSearch, value: KalgramTweaks.longRecentSearch, text: "Длинная история поиска", enabled: true))
    entries.append(.toggle(id: id.count, section: .tweaks, settingName: .lockOnLaunch, value: KalgramTweaks.lockOnLaunch, text: "Код-пароль при каждом запуске", enabled: true))
    entries.append(.toggle(id: id.count, section: .tweaks, settingName: .moreAutolock, value: KalgramTweaks.moreAutolock, text: "Больше вариантов автоблокировки", enabled: true))
    entries.append(.notice(id: id.count, section: .tweaks, text: "Заблокированных не видно в группах и каналах, сам чат в списке не меняется; список заблокированных обновляется раз в 30 минут и только при включённой настройке. Анти-спойлер: текст и медиа под спойлером видны сразу. История поиска: до 200 чатов вместо 20. Автоблокировка: 5 секунд, 2, 10, 15 и 30 минут, 2, 8 и 24 часа в меню кода-пароля. Без стикера приветствия он и не загружается."))

    entries.append(.header(id: id.count, section: .ads, text: "РЕКЛАМА", badge: nil))
    entries.append(.toggle(id: id.count, section: .ads, settingName: .adsHideSponsored, value: SGSimpleSettings.shared.kalgramHideSponsored, text: "Спонсорские сообщения", enabled: true))
    entries.append(.toggle(id: id.count, section: .ads, settingName: .adsHideSimilarChannels, value: SGSimpleSettings.shared.kalgramHideSimilarChannels, text: "Похожие каналы", enabled: true))
    entries.append(.toggle(id: id.count, section: .ads, settingName: .adsHideSearchAds, value: SGSimpleSettings.shared.kalgramHideSearchAds, text: "Реклама в поиске и ботах", enabled: true))
    entries.append(.toggle(id: id.count, section: .ads, settingName: .adsHidePremiumPromo, value: SGSimpleSettings.shared.kalgramHidePremiumPromo, text: "Предложения Premium", enabled: true))
    entries.append(.notice(id: id.count, section: .ads, text: "Всё работает на этом устройстве, ничего не отправляется. Спонсорские сообщения в каналах не загружаются и не отмечаются как просмотренные."))

    let backgroundMode = KalgramTweaks.backgroundMode
    entries.append(.header(id: id.count, section: .background, text: "УВЕДОМЛЕНИЯ С ТЕКСТОМ", badge: nil))
    entries.append(.oneFromManySelector(id: id.count, section: .background, settingName: .backgroundMode, text: "Режим", value: backgroundModeTitle(backgroundMode), enabled: true))
    let backgroundNotice: String
    switch backgroundMode {
    case .off:
        backgroundNotice = "kalgram получает сообщения, только когда открыт. Включи один из режимов, чтобы приходили уведомления с текстом."
    case .refresh:
        backgroundNotice = "iOS сама иногда будит kalgram, он скачивает новое и показывает уведомления с текстом. Батарею почти не тратит, но когда будить, решает iOS: бывает раз в 15–30 минут, бывает раз в несколько часов, ночью и в энергосбережении почти никогда."
    case .alwaysOn:
        backgroundNotice = "kalgram не засыпает в фоне (играет беззвучный звук, музыке не мешает), сообщения приходят сразу. Тратит батарею — проверь в Настройки → Аккумулятор. Сам выключается в режиме энергосбережения и при заряде ниже 20% без зарядки. Если смахнуть kalgram из многозадачности, уведомления прекратятся до следующего открытия."
    }
    entries.append(.notice(id: id.count, section: .background, text: backgroundNotice))

    entries.append(.header(id: id.count, section: .notifications, text: "УВЕДОМЛЕНИЯ (NTFY)", badge: nil))
    entries.append(.disclosure(id: id.count, section: .notifications, link: .ntfyCopyTopic, text: "Скопировать топик"))
    entries.append(.action(id: id.count, section: .notifications, actionType: .ntfySendTest, text: "Прислать тестовое уведомление", kind: .generic))
    entries.append(.action(id: id.count, section: .notifications, actionType: .ntfyCheckTelegram, text: "Проверить, шлёт ли Telegram", kind: .generic))
    var notificationsNotice = "1. Поставь ntfy из App Store.\n2. Нажми «Скопировать топик», в ntfy нажми + и вставь (сервер ntfy.sh).\n3. Нажми «Прислать тестовое» — должно прийти уведомление от ntfy.\n\nТопик: \(KalgramNtfy.topic)\nРегистрация: \(KalgramNtfy.lastStatus ?? "ещё не было, перезапусти приложение")"
    if let ntfyCheckResult = state.ntfyCheckResult {
        notificationsNotice += "\nПроверка: \(ntfyCheckResult)"
    }
    entries.append(.notice(id: id.count, section: .notifications, text: notificationsNotice))

    entries.append(.header(id: id.count, section: .badges, text: "БЕЙДЖИК ВМЕСТО DYNAMIC ISLAND", badge: nil))
    entries.append(.disclosure(id: id.count, section: .badges, link: .badges, text: "Бейджики"))
    entries.append(.notice(id: id.count, section: .badges, text: "Картинка или надпись на месте островка: видна на скриншотах, а вживую её закрывает островок. Свои бейджи, файлы .ggbadge из Ghostgram и картинки по ссылке."))

    let style = SGSimpleSettings.shared.nyStyle
    let pictureCount = KalgramEffectSettings.pictureURLs().count
    let maxPictures = KalgramEffectSettings.maxPictures
    entries.append(.header(id: id.count, section: .effects, text: "ПАДАЮЩИЙ ЭФФЕКТ В ЧАТАХ", badge: nil))
    entries.append(.oneFromManySelector(id: id.count, section: .effects, settingName: .effectStyle, text: "Что падает", value: effectStyleTitle(style), enabled: true))
    entries.append(.oneFromManySelector(id: id.count, section: .effects, settingName: .effectDirection, text: "Куда", value: effectDirectionTitle(KalgramEffectSettings.direction), enabled: true))
    entries.append(.header(id: id.count, section: .effects, text: "СВОЯ КАРТИНКА, ДО \(maxPictures)", badge: nil))
    entries.append(.toggle(id: id.count, section: .effects, settingName: .effectRemoveBackground, value: KalgramEffectSettings.removeBackground, text: "Убрать фон", enabled: true))
    entries.append(.disclosure(id: id.count, section: .effects, link: .effectAddImage, text: "Добавить картинку (\(pictureCount) из \(maxPictures))"))
    if pictureCount > 0 {
        entries.append(.disclosure(id: id.count, section: .effects, link: .effectRemoveImages, text: "Убрать все картинки"))
    }
    entries.append(.notice(id: id.count, section: .effects, text: "Фон убирается по контуру предмета, нужен iOS 17. Картинка обрезается по предмету и уменьшается до 128 px. Без фона остаётся как есть. Размер, разброс и вращение — для своей картинки."))
    entries.append(.header(id: id.count, section: .effects, text: "СКОЛЬКО", badge: nil))
    entries.append(.percentageSlider(id: id.count, section: .effects, settingName: .effectDensity, value: Int32(KalgramEffectSettings.percent(KalgramEffectSettings.densityKey, default: 30.0))))
    entries.append(.header(id: id.count, section: .effects, text: "СКОРОСТЬ", badge: nil))
    entries.append(.percentageSlider(id: id.count, section: .effects, settingName: .effectSpeed, value: Int32(KalgramEffectSettings.percent(KalgramEffectSettings.speedKey, default: 50.0))))
    entries.append(.header(id: id.count, section: .effects, text: "РАЗМЕР", badge: nil))
    entries.append(.percentageSlider(id: id.count, section: .effects, settingName: .effectSize, value: Int32(KalgramEffectSettings.percent(KalgramEffectSettings.sizeKey, default: 45.0))))
    entries.append(.header(id: id.count, section: .effects, text: "РАЗБРОС РАЗМЕРА", badge: nil))
    entries.append(.percentageSlider(id: id.count, section: .effects, settingName: .effectSizeSpread, value: Int32(KalgramEffectSettings.percent(KalgramEffectSettings.sizeSpreadKey, default: 35.0))))
    entries.append(.header(id: id.count, section: .effects, text: "ВРАЩЕНИЕ, 50 — НЕ КРУТИТСЯ", badge: nil))
    entries.append(.percentageSlider(id: id.count, section: .effects, settingName: .effectSpin, value: Int32(KalgramEffectSettings.percent(KalgramEffectSettings.spinKey, default: 50.0))))
    entries.append(.header(id: id.count, section: .effects, text: "РАЗБРОС ВРАЩЕНИЯ", badge: nil))
    entries.append(.percentageSlider(id: id.count, section: .effects, settingName: .effectSpinSpread, value: Int32(KalgramEffectSettings.percent(KalgramEffectSettings.spinSpreadKey, default: 22.0))))
    entries.append(.header(id: id.count, section: .effects, text: "ПРОЗРАЧНОСТЬ", badge: nil))
    entries.append(.percentageSlider(id: id.count, section: .effects, settingName: .effectOpacity, value: Int32(KalgramEffectSettings.percent(KalgramEffectSettings.opacityKey, default: 100.0))))
    entries.append(.notice(id: id.count, section: .effects, text: "Меняется в чатах, открытых после настройки. Для одного чата можно выбрать свой: профиль собеседника → «…» → «Снег в этом чате». В режиме энергосбережения эффект выключается сам."))

    entries.append(.header(id: id.count, section: .roundVideo, text: "КРУЖКИ", badge: nil))
    entries.append(.oneFromManySelector(id: id.count, section: .roundVideo, settingName: .roundVideoQuality, text: "Качество", value: roundVideoQualityTitle(SGSimpleSettings.shared.roundVideoQuality), enabled: true))
    entries.append(.notice(id: id.count, section: .roundVideo, text: "Действует на кружки, записанные после изменения. Чем выше качество, тем чётче картинка, но файл больше и отправляется дольше. Уже отправленные не меняются."))

    entries.append(.header(id: id.count, section: .study, text: "📚 ПОДГОТОВКА", badge: nil))
    entries.append(.toggle(id: id.count, section: .study, settingName: .studyEnabled, value: KalgramStudySettings.isEnabled, text: "Напоминать учиться", enabled: true))
    entries.append(.oneFromManySelector(id: id.count, section: .study, settingName: .studyInterval, text: "Каждые", value: "\(KalgramStudySettings.minutes) мин", enabled: KalgramStudySettings.isEnabled))
    entries.append(.notice(id: id.count, section: .study, text: "Считается только время, пока kalgram открыт. Когда наберётся выбранное время, сверху появится плашка: «Хватит сидеть — иди занимайся». Свёрнутое приложение не считается и батарею не тратит."))

    entries.append(.header(id: id.count, section: .proxy, text: "ПРОКСИ", badge: nil))
    entries.append(.toggle(id: id.count, section: .proxy, settingName: .proxyAutoSwitch, value: KalgramProxySettings.autoSwitch, text: "Автосмена прокси", enabled: true))
    entries.append(.toggle(id: id.count, section: .proxy, settingName: .proxyRespectVpn, value: KalgramProxySettings.respectVpn, text: "Не включать при VPN", enabled: KalgramProxySettings.autoSwitch))
    entries.append(.notice(id: id.count, section: .proxy, text: "Автосмена: если прокси не подключается 10 секунд, kalgram переключит на следующий из сохранённых, а если прокси выключен и связи нет 15 секунд — включит первый. Работает только когда со связью беда, в остальное время ничего не делает.\n«Не включать при VPN»: пока включён VPN, kalgram сам прокси не включает и не переключает, а включённый им самим выключает. Вручную включать можно всегда."))

    entries.append(.header(id: id.count, section: .interface, text: "ИНТЕРФЕЙС", badge: nil))
    entries.append(.toggle(id: id.count, section: .interface, settingName: .oldInterface, value: UserDefaults.standard.bool(forKey: oldInterfaceKey), text: "Старый интерфейс", enabled: true))
    entries.append(.toggle(id: id.count, section: .interface, settingName: .amoled, value: KalgramTweaks.amoled, text: "AMOLED — чистый чёрный", enabled: true))
    entries.append(.toggle(id: id.count, section: .interface, settingName: .hideSeparators, value: KalgramTweaks.hideSeparators, text: "Скрыть разделители", enabled: true))
    entries.append(.toggle(id: id.count, section: .interface, settingName: .noSelectionBlur, value: KalgramTweaks.noSelectionBlur, text: "Без размытия при выборе сообщения", enabled: true))
    entries.append(.toggle(id: id.count, section: .interface, settingName: .exactLastSeen, value: KalgramTweaks.exactLastSeen, text: "Точное время «был(а)»", enabled: true))
    entries.append(.toggle(id: id.count, section: .interface, settingName: .hideStoryRings, value: KalgramTweaks.hideStoryRings, text: "Без колец историй у аватаров", enabled: true))
    entries.append(.toggle(id: id.count, section: .interface, settingName: .hideEmojiStatus, value: KalgramTweaks.hideEmojiStatus, text: "Скрыть эмодзи-статусы в списке", enabled: true))
    entries.append(.toggle(id: id.count, section: .interface, settingName: .hideBubbleTails, value: KalgramTweaks.hideBubbleTails, text: "Пузыри без хвостиков", enabled: true))
    entries.append(.toggle(id: id.count, section: .interface, settingName: .hideSearchField, value: KalgramTweaks.hideSearchField, text: "Скрыть поле поиска", enabled: true))
    entries.append(.notice(id: id.count, section: .interface, text: "AMOLED делает чёрной любую тёмную тему и на этом экране экономит заряд. Без размытия и без анимированных статусов тоже меньше работы видеочипу. AMOLED и разделители применяются после перезапуска."))
    entries.append(.notice(id: id.count, section: .interface, text: "Как до «жидкого стекла»: плоские панели без бликов и теней, панель вкладок во всю ширину внизу экрана с подписями. Нужен перезапуск."))

    // kalgram: iOS's own daily report of what kalgram spent (MetricKit)
    let energyDays = KalgramEnergyReport.shared.days
    entries.append(.header(id: id.count, section: .energy, text: "🔋 РАСХОД ЗА СУТКИ", badge: nil))
    if let latest = energyDays.first {
        entries.append(.notice(id: id.count, section: .energy, text: kalgramEnergyReportText(latest, previous: energyDays.count > 1 ? energyDays[1] : nil)))
    }
    entries.append(.notice(id: id.count, section: .energy, text: energyDays.isEmpty ? "Отчёта ещё нет. iOS присылает его примерно раз в сутки, первый — обычно через день после установки. Отчёт остаётся на телефоне, никуда не отправляется." : "Отчёт присылает iOS примерно раз в сутки. Сравнивать дни удобно по «на час экрана»: это не зависит от того, сколько ты сидел. Остаётся на телефоне, никуда не отправляется."))

    return entries
}

public func kalgramProController(context: AccountContext) -> ViewController {
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments?) -> Void)?
    var pushControllerImpl: ((ViewController) -> Void)?
    var openFolderImpl: ((Int32) -> Void)?
    var askForRestart: (() -> Void)?
    var showToast: ((String) -> Void)?

    let accountPeerId = context.account.peerId

    let initialState = KalgramProState()
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((KalgramProState) -> KalgramProState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    // Settings live in UserDefaults; this re-reads them after a change
    let reloadPromise = ValuePromise(true, ignoreRepeated: false)

    let arguments = SGItemListArguments<KalgramProToggle, KalgramProSlider, KalgramProSelector, KalgramProLink, KalgramProAction>(
        context: context,
        setBoolValue: { setting, value in
            switch setting {
            case .ghostQuickEnabled:
                KalgramGhost.setQuickEnabled(value, accountPeerId: accountPeerId)
            case .ghostQuickReadReceipts:
                KalgramGhost.setInQuickSet(.readReceipts, value, accountPeerId: accountPeerId)
            case .ghostQuickTyping:
                KalgramGhost.setInQuickSet(.typing, value, accountPeerId: accountPeerId)
            case .ghostQuickOnline:
                KalgramGhost.setInQuickSet(.online, value, accountPeerId: accountPeerId)
            case .ghostQuickStories:
                KalgramGhost.setInQuickSet(.stories, value, accountPeerId: accountPeerId)
            case .ghostPermanentReadReceipts:
                KalgramGhost.setPermanent(.readReceipts, value, accountPeerId: accountPeerId)
            case .ghostPermanentTyping:
                KalgramGhost.setPermanent(.typing, value, accountPeerId: accountPeerId)
            case .ghostPermanentOnline:
                KalgramGhost.setPermanent(.online, value, accountPeerId: accountPeerId)
            case .ghostPermanentStories:
                KalgramGhost.setPermanent(.stories, value, accountPeerId: accountPeerId)
            case .keepDeletedMessages:
                KalgramTweaks.keepDeletedMessages = value
            case .keepEditHistory:
                KalgramTweaks.keepEditHistory = value
            case .bypassProtection:
                KalgramTweaks.bypassProtection = value
                askForRestart?()
            case .keepSelfDestructing:
                KalgramTweaks.keepSelfDestructing = value
            case .bypassIosRestrictions:
                KalgramTweaks.bypassIosRestrictions = value
                askForRestart?()
            case .oldInterface:
                UserDefaults.standard.set(value, forKey: oldInterfaceKey)
                if value {
                    // The old tab bar: every tab spread over the whole width, with its name
                    SGSimpleSettings.shared.wideTabBar = true
                    SGSimpleSettings.shared.showTabNames = true
                }
                askForRestart?()
            case .adsHideSponsored:
                SGSimpleSettings.shared.kalgramHideSponsored = value
            case .adsHideSimilarChannels:
                SGSimpleSettings.shared.kalgramHideSimilarChannels = value
            case .adsHideSearchAds:
                SGSimpleSettings.shared.kalgramHideSearchAds = value
            case .adsHidePremiumPromo:
                SGSimpleSettings.shared.kalgramHidePremiumPromo = value
            case .effectRemoveBackground:
                KalgramEffectSettings.removeBackground = value
            case .studyEnabled:
                KalgramStudySettings.isEnabled = value
            case .proxyAutoSwitch:
                KalgramProxySettings.autoSwitch = value
            case .proxyRespectVpn:
                KalgramProxySettings.respectVpn = value
            case .sendingAntiCaps:
                KalgramOutgoing.antiCaps = value
            case .sendingWordReplacement:
                KalgramOutgoing.wordReplacement = value
            case .sendingDelay:
                KalgramOutgoing.setSendDelayEnabled(value, accountPeerId: accountPeerId)
            case .ghostReadOnAction:
                KalgramOutgoing.setReadOnAction(value, accountPeerId: accountPeerId)
            case .revealSpoilers:
                KalgramTweaks.revealSpoilers = value
            case .hideGreetingSticker:
                KalgramTweaks.hideGreetingSticker = value
            case .longRecentSearch:
                KalgramTweaks.longRecentSearch = value
            case .moreAutolock:
                KalgramTweaks.moreAutolock = value
            case .hideBlockedMessages:
                KalgramBlockedPeers.isEnabled = value
            case .amoled:
                KalgramTweaks.amoled = value
                askForRestart?()
            case .hideSeparators:
                KalgramTweaks.hideSeparators = value
                askForRestart?()
            case .exactLastSeen:
                KalgramTweaks.exactLastSeen = value
            case .noSelectionBlur:
                KalgramTweaks.noSelectionBlur = value
            case .hideStoryRings:
                KalgramTweaks.hideStoryRings = value
            case .hideEmojiStatus:
                KalgramTweaks.hideEmojiStatus = value
            case .hideBubbleTails:
                KalgramTweaks.hideBubbleTails = value
                askForRestart?()
            case .hideSearchField:
                KalgramTweaks.hideSearchField = value
                askForRestart?()
            case .lockOnLaunch:
                KalgramTweaks.lockOnLaunch = value
            case .chatLockEnabled:
                if value {
                    KalgramChatLockSettings.isEnabled = true
                } else {
                    // Turning protection off is what an intruder would do: ask first
                    KalgramLocalAuth.authenticate(reason: "Изменить настройки безопасности", completion: { granted in
                        if granted {
                            KalgramChatLockSettings.isEnabled = false
                        }
                        reloadPromise.set(true)
                    })
                }
            case .chatLockAllChats:
                kalgramChangeSecurity(weakens: !value, reload: { reloadPromise.set(true) }, apply: {
                    KalgramChatLockSettings.allChats = value
                })
            case .chatLockAutolock:
                // With autolock one check opens every protected chat, so turning it on weakens the lock
                kalgramChangeSecurity(weakens: value, reload: { reloadPromise.set(true) }, apply: {
                    KalgramChatLockSettings.autolock = value
                })
            case .screenshotPrivacy:
                kalgramChangeSecurity(weakens: !value, reload: { reloadPromise.set(true) }, apply: {
                    KalgramChatLockSettings.screenshotPrivacy = value
                })
            case .screenshotPrivacyChatList:
                kalgramChangeSecurity(weakens: !value, reload: { reloadPromise.set(true) }, apply: {
                    KalgramChatLockSettings.screenshotPrivacyChatList = value
                })
            case .accountSwitchAuth:
                if value {
                    KalgramChatLockSettings.accountSwitchAuth = true
                } else {
                    KalgramLocalAuth.authenticate(reason: "Изменить настройки безопасности", completion: { granted in
                        if granted {
                            KalgramChatLockSettings.accountSwitchAuth = false
                        }
                        reloadPromise.set(true)
                    })
                }
            case .secretFolderProtects:
                kalgramChangeSecurity(weakens: !value, reload: { reloadPromise.set(true) }, apply: {
                    KalgramChatLockSettings.setSecretFolderProtectsChats(value, accountPeerId: accountPeerId)
                })
            }
            reloadPromise.set(true)
        },
        updateSliderValue: { setting, value in
            switch setting {
            case .effectDensity:
                KalgramEffectSettings.setPercent(KalgramEffectSettings.densityKey, Double(value))
            case .effectSpeed:
                KalgramEffectSettings.setPercent(KalgramEffectSettings.speedKey, Double(value))
            case .effectSize:
                KalgramEffectSettings.setPercent(KalgramEffectSettings.sizeKey, Double(value))
            case .effectSizeSpread:
                KalgramEffectSettings.setPercent(KalgramEffectSettings.sizeSpreadKey, Double(value))
            case .effectSpin:
                KalgramEffectSettings.setPercent(KalgramEffectSettings.spinKey, Double(value))
            case .effectSpinSpread:
                KalgramEffectSettings.setPercent(KalgramEffectSettings.spinSpreadKey, Double(value))
            case .effectOpacity:
                KalgramEffectSettings.setPercent(KalgramEffectSettings.opacityKey, Double(value))
            }
            reloadPromise.set(true)
        },
        setOneFromManyValue: { setting in
            switch setting {
            case .effectStyle:
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                let actionSheet = ActionSheetController(presentationData: presentationData)
                var items: [ActionSheetItem] = []
                for style in SGSimpleSettings.NYStyle.allCases {
                    items.append(ActionSheetButtonItem(title: effectStyleTitle(style.rawValue), color: .accent, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        let hasImage = !KalgramEffectSettings.pictureURLs().isEmpty
                        if style == .custom && !hasImage {
                            showToast?("Сначала выбери свою картинку")
                            return
                        }
                        SGSimpleSettings.shared.nyStyle = style.rawValue
                        reloadPromise.set(true)
                    }))
                }
                actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                    ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                    })
                ])])
                presentControllerImpl?(actionSheet, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            case .effectDirection:
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                let actionSheet = ActionSheetController(presentationData: presentationData)
                var items: [ActionSheetItem] = []
                for direction in KalgramEffectSettings.Direction.allCases {
                    items.append(ActionSheetButtonItem(title: effectDirectionTitle(direction), color: .accent, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        KalgramEffectSettings.direction = direction
                        reloadPromise.set(true)
                    }))
                }
                actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                    ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                    })
                ])])
                presentControllerImpl?(actionSheet, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            case .studyInterval:
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                let actionSheet = ActionSheetController(presentationData: presentationData)
                var items: [ActionSheetItem] = []
                for minutes in KalgramStudySettings.minuteChoices {
                    items.append(ActionSheetButtonItem(title: "\(minutes) мин", color: .accent, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        KalgramStudySettings.minutes = minutes
                        reloadPromise.set(true)
                    }))
                }
                actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                    ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                    })
                ])])
                presentControllerImpl?(actionSheet, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            case .chatLockTimeout:
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                let actionSheet = ActionSheetController(presentationData: presentationData)
                var items: [ActionSheetItem] = []
                for seconds in KalgramChatLockSettings.autolockChoices {
                    items.append(ActionSheetButtonItem(title: chatLockTimeoutTitle(seconds), color: .accent, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        // A longer timer keeps protected chats open for longer
                        kalgramChangeSecurity(weakens: seconds > KalgramChatLockSettings.autolockSeconds, reload: { reloadPromise.set(true) }, apply: {
                            KalgramChatLockSettings.autolockSeconds = seconds
                        })
                    }))
                }
                actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                    ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                    })
                ])])
                presentControllerImpl?(actionSheet, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            case .secretFolder:
                KalgramLocalAuth.authenticate(reason: "Изменить настройки безопасности", completion: { granted in
                    guard granted else {
                        return
                    }
                    let _ = (context.engine.peers.updatedChatListFilters()
                    |> take(1)
                    |> deliverOnMainQueue).startStandalone(next: { filters in
                        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                        let actionSheet = ActionSheetController(presentationData: presentationData)
                        var items: [ActionSheetItem] = []
                        items.append(ActionSheetButtonItem(title: "Нет", color: .accent, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                            KalgramChatLockSettings.setSecretFolderId(0, accountPeerId: accountPeerId)
                            KalgramChatLockSettings.setSecretFolderPeers([], accountPeerId: accountPeerId)
                            reloadPromise.set(true)
                        }))
                        for filter in filters {
                            if case let .filter(folderId, title, _, _) = filter {
                                items.append(ActionSheetButtonItem(title: title.text.isEmpty ? "#\(folderId)" : title.text, color: .accent, action: { [weak actionSheet] in
                                    actionSheet?.dismissAnimated()
                                    KalgramChatLockSettings.setSecretFolderId(folderId, accountPeerId: accountPeerId)
                                    reloadPromise.set(true)
                                }))
                            }
                        }
                        actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                            ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                            })
                        ])])
                        presentControllerImpl?(actionSheet, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                    })
                })
            case .sendingDelaySeconds:
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                let actionSheet = ActionSheetController(presentationData: presentationData)
                var items: [ActionSheetItem] = []
                for seconds in KalgramOutgoing.sendDelayChoices {
                    items.append(ActionSheetButtonItem(title: "\(seconds) с", color: .accent, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        KalgramOutgoing.setSendDelaySeconds(seconds, accountPeerId: accountPeerId)
                        reloadPromise.set(true)
                    }))
                }
                actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                    ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                    })
                ])])
                presentControllerImpl?(actionSheet, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            case .roundVideoQuality:
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                let actionSheet = ActionSheetController(presentationData: presentationData)
                var items: [ActionSheetItem] = []
                for quality in SGSimpleSettings.RoundVideoQualityValues.allCases {
                    items.append(ActionSheetButtonItem(title: roundVideoQualityTitle(quality.rawValue), color: .accent, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        SGSimpleSettings.shared.roundVideoQuality = quality.rawValue
                        reloadPromise.set(true)
                    }))
                }
                actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                    ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                    })
                ])])
                presentControllerImpl?(actionSheet, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            case .backgroundMode:
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                let actionSheet = ActionSheetController(presentationData: presentationData)
                var items: [ActionSheetItem] = []
                for mode in KalgramTweaks.BackgroundMode.allCases {
                    items.append(ActionSheetButtonItem(title: backgroundModeTitle(mode), color: .accent, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        KalgramTweaks.backgroundMode = mode
                        reloadPromise.set(true)
                    }))
                }
                actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                    ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                    })
                ])])
                presentControllerImpl?(actionSheet, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            }
        },
        openDisclosureLink: { link in
            switch link {
            case .ntfyCopyTopic:
                UIPasteboard.general.string = KalgramNtfy.topic
                showToast?("Топик скопирован")
            case .badges:
                pushControllerImpl?(kalgramBadgesController(context: context))
            case .effectAddImage:
                KalgramImagePicker.shared.pickOriginal(completion: { data in
                    if KalgramEffectSettings.pictureURLs().count >= KalgramEffectSettings.maxPictures {
                        showToast?("Картинок уже \(KalgramEffectSettings.maxPictures), больше не добавить")
                        return
                    }
                    let removeBackground = KalgramEffectSettings.removeBackground
                    // Finding the subject takes a moment, so it is not done on the main thread
                    DispatchQueue.global(qos: .userInitiated).async {
                        let png = kalgramParticlePNG(from: data, removeBackground: removeBackground)
                        DispatchQueue.main.async {
                            if let png, KalgramEffectSettings.addPicture(png) {
                                SGSimpleSettings.shared.nyStyle = SGSimpleSettings.NYStyle.custom.rawValue
                            } else {
                                showToast?("Не получилось прочитать картинку")
                            }
                            reloadPromise.set(true)
                        }
                    }
                })
            case .effectRemoveImages:
                KalgramEffectSettings.removeAllPictures()
                if SGSimpleSettings.shared.nyStyle == SGSimpleSettings.NYStyle.custom.rawValue {
                    SGSimpleSettings.shared.nyStyle = SGSimpleSettings.NYStyle.default.rawValue
                }
                showToast?("Картинки убраны")
                reloadPromise.set(true)
            case .sendingAddRule:
                let alert = UIAlertController(title: "Правило замены", message: nil, preferredStyle: .alert)
                alert.addTextField { field in
                    field.placeholder = "Что заменять"
                }
                alert.addTextField { field in
                    field.placeholder = "На что"
                }
                alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
                alert.addAction(UIAlertAction(title: "Добавить", style: .default, handler: { [weak alert] _ in
                    KalgramOutgoing.addRule(source: alert?.textFields?.first?.text ?? "", replacement: alert?.textFields?.last?.text ?? "")
                    reloadPromise.set(true)
                }))
                KalgramImagePicker.topViewController()?.present(alert, animated: true)
            case .chatLockClear:
                KalgramLocalAuth.authenticate(reason: "Изменить настройки безопасности", completion: { granted in
                    if granted {
                        KalgramChatLockSettings.clearProtectedList(accountPeerId: accountPeerId)
                        reloadPromise.set(true)
                    }
                })
            case .secretFolderOpen:
                let folderId = KalgramChatLockSettings.secretFolderId(accountPeerId: accountPeerId)
                KalgramLocalAuth.authenticate(reason: "Открыть секретную папку", completion: { granted in
                    guard granted else {
                        return
                    }
                    let _ = KalgramChatLock.shared
                    KalgramChatLockSettings.unlockSecretFolder(accountPeerId: accountPeerId)
                    openFolderImpl?(folderId)
                })
            case .sendingRemoveRules:
                KalgramOutgoing.rules = []
                showToast?("Правила убраны")
                reloadPromise.set(true)
            }
        },
        action: { action in
            switch action {
            case .ntfySendTest:
                KalgramNtfy.sendTest(completion: { ok in
                    showToast?(ok ? "Отправлено. Если ntfy подписан на топик — сейчас придёт уведомление" : "Не получилось достучаться до ntfy.sh")
                })
            case .ntfyCheckTelegram:
                updateState { state in
                    var state = state
                    state.ntfyCheckResult = "проверяю…"
                    return state
                }
                KalgramNtfy.recentTelegramPushes(completion: { count, lastDate in
                    let result: String
                    if let count {
                        if count == 0 {
                            result = "за 12 часов Telegram ничего не присылал"
                        } else {
                            let formatter = DateFormatter()
                            formatter.dateFormat = "dd.MM HH:mm"
                            result = "Telegram прислал \(count) за 12 часов, последнее \(lastDate.flatMap { formatter.string(from: $0) } ?? "—")"
                        }
                    } else {
                        result = "ntfy.sh не отвечает"
                    }
                    updateState { state in
                        var state = state
                        state.ntfyCheckResult = result
                        return state
                    }
                })
            }
        }
    )

    let accountName: Signal<String, NoError> = context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: accountPeerId))
    |> map { peer -> String in
        return peer?.compactDisplayTitle ?? "этот аккаунт"
    }

    let signal = combineLatest(reloadPromise.get(), statePromise.get(), context.sharedContext.presentationData, accountName)
    |> map { _, state, presentationData, accountName -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let entries = kalgramProEntries(accountPeerId: accountPeerId, accountName: accountName, state: state)
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("kalgram Pro"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, ensureVisibleItemTag: nil, initialScrollToItem: nil)
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    presentControllerImpl = { [weak controller] c, a in
        controller?.present(c, in: .window(.root), with: a)
    }
    pushControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.pushViewController(c)
    }
    openFolderImpl = { [weak controller] folderId in
        guard let navigationController = controller?.navigationController as? NavigationController else {
            return
        }
        navigationController.popToRoot(animated: true)
        guard let tabBarController = navigationController.viewControllers.first as? TabBarController else {
            return
        }
        for (index, tab) in tabBarController.controllers.enumerated() {
            if let chatListController = tab as? ChatListController {
                tabBarController.selectedIndex = index
                chatListController.navigateToFolder(folderId: folderId, completion: {})
                break
            }
        }
    }
    showToast = { [weak context] text in
        guard let context else {
            return
        }
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        presentControllerImpl?(UndoOverlayController(presentationData: presentationData, content: .info(title: nil, text: text, timeout: 3.0, customUndoText: nil), elevatedLayout: false, action: { _ in return false }), nil)
    }
    askForRestart = { [weak context] in
        guard let context else {
            return
        }
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        presentControllerImpl?(UndoOverlayController(presentationData: presentationData, content: .info(title: nil, text: "Нужен перезапуск", timeout: nil, customUndoText: "Перезапустить"), elevatedLayout: false, action: { action in
            if action == .undo {
                exit(0)
            }
            return true
        }), nil)
    }
    return controller
}
