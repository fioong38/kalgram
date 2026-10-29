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
    case background
    case notifications
    case badges
    case effects
    case interface
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
    case effectRemoveBackground
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
}

private enum KalgramProLink: String {
    case ntfyCopyTopic
    case badges
    case effectAddImage
    case effectRemoveImages
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
    entries.append(.notice(id: id.count, section: .ghostPermanent, text: "Работает на этом аккаунте всегда, с первой секунды после входа, кнопка 👻 на это не влияет."))

    entries.append(.header(id: id.count, section: .history, text: "ЛИЧНЫЕ ЧАТЫ", badge: nil))
    entries.append(.toggle(id: id.count, section: .history, settingName: .keepDeletedMessages, value: KalgramTweaks.keepDeletedMessages, text: "Сохранять удалённые", enabled: true))
    entries.append(.toggle(id: id.count, section: .history, settingName: .keepEditHistory, value: KalgramTweaks.keepEditHistory, text: "Сохранять историю правок", enabled: true))
    entries.append(.notice(id: id.count, section: .history, text: "Удалённое собеседником остаётся, у времени появляется «удалено» — эту пометку ставит kalgram, текстом её не подделать. У изменённого ниже видно «✏️ было: …». Сохраняются сообщения, которые kalgram успел загрузить: если сообщение пришло и удалилось, пока приложение было закрыто, телефон его не получал."))

    entries.append(.header(id: id.count, section: .protection, text: "ОБХОДЫ", badge: nil))
    entries.append(.toggle(id: id.count, section: .protection, settingName: .bypassProtection, value: KalgramTweaks.bypassProtection, text: "Сохранять и скринить защищённое", enabled: true))
    entries.append(.toggle(id: id.count, section: .protection, settingName: .keepSelfDestructing, value: KalgramTweaks.keepSelfDestructing, text: "Сохранять одноразки", enabled: true))
    entries.append(.toggle(id: id.count, section: .protection, settingName: .bypassIosRestrictions, value: KalgramTweaks.bypassIosRestrictions, text: "Открывать каналы, скрытые на iOS", enabled: true))
    entries.append(.notice(id: id.count, section: .protection, text: "Одноразки не исчезают, и отправитель не видит, что ты открыл. Отметить просмотренной: долгий тап по сообщению → «🔥 Сжечь». Каналы с пометкой «нарушал правила App Store» открываются; блокировки по закону остаются."))

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
    entries.append(.notice(id: id.count, section: .effects, text: "Меняется в чатах, открытых после настройки. В режиме энергосбережения эффект выключается сам."))

    entries.append(.header(id: id.count, section: .interface, text: "ИНТЕРФЕЙС", badge: nil))
    entries.append(.toggle(id: id.count, section: .interface, settingName: .oldInterface, value: UserDefaults.standard.bool(forKey: oldInterfaceKey), text: "Старый интерфейс", enabled: true))
    entries.append(.notice(id: id.count, section: .interface, text: "Как до «жидкого стекла»: плоские панели без бликов и теней, панель вкладок во всю ширину внизу экрана с подписями. Нужен перезапуск."))

    return entries
}

public func kalgramProController(context: AccountContext) -> ViewController {
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments?) -> Void)?
    var pushControllerImpl: ((ViewController) -> Void)?
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
            case .effectRemoveBackground:
                KalgramEffectSettings.removeBackground = value
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
