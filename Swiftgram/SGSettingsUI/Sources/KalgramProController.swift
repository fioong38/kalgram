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

// kalgram: every setting of the mod, behind the "kalgram Pro" row in Settings.
// Ghost mode is shown for the account the screen was opened from.

private enum KalgramProSection: Int32, SGItemListSection {
    case ghostQuick
    case ghostPermanent
    case history
    case protection
    case notifications
    case island
    case islandSize
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
    case islandEnabled
    case islandFitsWhole
    case oldInterface
}

private enum KalgramProSlider: String {
    case islandWidth
    case islandHeight
    case islandTop
    case islandOffsetX
    case islandCorners
    case effectDensity
    case effectSpeed
}

private enum KalgramProSelector: String {
    case effectStyle
}

private enum KalgramProLink: String {
    case ntfyCopyTopic
    case islandPickImage
    case effectPickImage
}

private enum KalgramProAction: Hashable {
    case ntfySendTest
    case ntfyCheckTelegram
    case islandReset
}

private struct KalgramProState: Equatable {
    var ntfyCheckResult: String?
}

private typealias KalgramProEntry = SGItemListUIEntry<KalgramProSection, KalgramProToggle, KalgramProSlider, KalgramProSelector, KalgramProLink, KalgramProAction>

private let oldInterfaceKey = "kalgram.oldInterface"
private let effectDensityKey = "kalgram.effect.density"
private let effectSpeedKey = "kalgram.effect.speed"

private var effectImageURL: URL? {
    return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("kalgram-particle.png")
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

    entries.append(.header(id: id.count, section: .notifications, text: "УВЕДОМЛЕНИЯ (NTFY)", badge: nil))
    entries.append(.disclosure(id: id.count, section: .notifications, link: .ntfyCopyTopic, text: "Скопировать топик"))
    entries.append(.action(id: id.count, section: .notifications, actionType: .ntfySendTest, text: "Прислать тестовое уведомление", kind: .generic))
    entries.append(.action(id: id.count, section: .notifications, actionType: .ntfyCheckTelegram, text: "Проверить, шлёт ли Telegram", kind: .generic))
    var notificationsNotice = "1. Поставь ntfy из App Store.\n2. Нажми «Скопировать топик», в ntfy нажми + и вставь (сервер ntfy.sh).\n3. Нажми «Прислать тестовое» — должно прийти уведомление от ntfy.\n\nТопик: \(KalgramNtfy.topic)\nРегистрация: \(KalgramNtfy.lastStatus ?? "ещё не было, перезапусти приложение")"
    if let ntfyCheckResult = state.ntfyCheckResult {
        notificationsNotice += "\nПроверка: \(ntfyCheckResult)"
    }
    entries.append(.notice(id: id.count, section: .notifications, text: notificationsNotice))

    let island = KalgramIsland.shared
    entries.append(.header(id: id.count, section: .island, text: "КАРТИНКА ВМЕСТО DYNAMIC ISLAND", badge: nil))
    entries.append(.toggle(id: id.count, section: .island, settingName: .islandEnabled, value: island.isEnabled && island.hasImage, text: "Показывать", enabled: island.hasImage))
    entries.append(.disclosure(id: id.count, section: .island, link: .islandPickImage, text: island.hasImage ? "Сменить картинку" : "Выбрать картинку"))
    entries.append(.toggle(id: id.count, section: .island, settingName: .islandFitsWhole, value: island.fitsWhole, text: "Вписать картинку целиком", enabled: island.hasImage))
    entries.append(.notice(id: id.count, section: .island, text: island.deviceHasIsland ? "Картинка рисуется ровно под островком: вживую её закрывает чёрный островок, а на скриншотах вместо него видна картинка, как логотип в приложении Озон. Если по краям что-то торчит — уменьши ширину и высоту ниже." : "На этом айфоне нет Dynamic Island."))

    entries.append(.header(id: id.count, section: .islandSize, text: "ШИРИНА", badge: nil))
    entries.append(.percentageSlider(id: id.count, section: .islandSize, settingName: .islandWidth, value: island.widthPercent))
    entries.append(.header(id: id.count, section: .islandSize, text: "ВЫСОТА", badge: nil))
    entries.append(.percentageSlider(id: id.count, section: .islandSize, settingName: .islandHeight, value: island.heightPercent))
    entries.append(.header(id: id.count, section: .islandSize, text: "ОТСТУП СВЕРХУ", badge: nil))
    entries.append(.percentageSlider(id: id.count, section: .islandSize, settingName: .islandTop, value: island.topPercent))
    entries.append(.header(id: id.count, section: .islandSize, text: "СДВИГ ВЛЕВО / ВПРАВО", badge: nil))
    entries.append(.percentageSlider(id: id.count, section: .islandSize, settingName: .islandOffsetX, value: island.offsetXPercent))
    entries.append(.header(id: id.count, section: .islandSize, text: "СКРУГЛЕНИЕ", badge: nil))
    entries.append(.percentageSlider(id: id.count, section: .islandSize, settingName: .islandCorners, value: island.cornerPercentValue))
    entries.append(.action(id: id.count, section: .islandSize, actionType: .islandReset, text: "Подогнать под мой iPhone", kind: .generic))
    entries.append(.notice(id: id.count, section: .islandSize, text: "Сейчас: \(island.frameDescription). Проверяй скриншотом."))

    let style = SGSimpleSettings.shared.nyStyle
    let hasEffectImage = effectImageURL.flatMap { FileManager.default.fileExists(atPath: $0.path) } ?? false
    entries.append(.header(id: id.count, section: .effects, text: "ПАДАЮЩИЙ ЭФФЕКТ В ЧАТАХ", badge: nil))
    entries.append(.oneFromManySelector(id: id.count, section: .effects, settingName: .effectStyle, text: "Что падает", value: effectStyleTitle(style), enabled: true))
    entries.append(.disclosure(id: id.count, section: .effects, link: .effectPickImage, text: hasEffectImage ? "Сменить свою картинку" : "Выбрать свою картинку"))
    entries.append(.header(id: id.count, section: .effects, text: "СКОЛЬКО", badge: nil))
    entries.append(.percentageSlider(id: id.count, section: .effects, settingName: .effectDensity, value: Int32(UserDefaults.standard.object(forKey: effectDensityKey) as? Double ?? 30.0)))
    entries.append(.header(id: id.count, section: .effects, text: "СКОРОСТЬ", badge: nil))
    entries.append(.percentageSlider(id: id.count, section: .effects, settingName: .effectSpeed, value: Int32(UserDefaults.standard.object(forKey: effectSpeedKey) as? Double ?? 50.0)))
    entries.append(.notice(id: id.count, section: .effects, text: "Меняется в чатах, открытых после настройки. В режиме энергосбережения эффект выключается сам."))

    entries.append(.header(id: id.count, section: .interface, text: "ИНТЕРФЕЙС", badge: nil))
    entries.append(.toggle(id: id.count, section: .interface, settingName: .oldInterface, value: UserDefaults.standard.bool(forKey: oldInterfaceKey), text: "Старый интерфейс", enabled: true))
    entries.append(.notice(id: id.count, section: .interface, text: "Плоские полупрозрачные панели вместо «жидкого стекла»: без бликов, теней и линз. Нужен перезапуск."))

    return entries
}

public func kalgramProController(context: AccountContext) -> ViewController {
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments?) -> Void)?
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
            case .islandEnabled:
                KalgramIsland.shared.isEnabled = value
            case .islandFitsWhole:
                KalgramIsland.shared.fitsWhole = value
            case .oldInterface:
                UserDefaults.standard.set(value, forKey: oldInterfaceKey)
                askForRestart?()
            }
            reloadPromise.set(true)
        },
        updateSliderValue: { setting, value in
            switch setting {
            case .islandWidth:
                KalgramIsland.shared.widthPercent = value
            case .islandHeight:
                KalgramIsland.shared.heightPercent = value
            case .islandTop:
                KalgramIsland.shared.topPercent = value
            case .islandOffsetX:
                KalgramIsland.shared.offsetXPercent = value
            case .islandCorners:
                KalgramIsland.shared.cornerPercentValue = value
            case .effectDensity:
                UserDefaults.standard.set(Double(value), forKey: effectDensityKey)
            case .effectSpeed:
                UserDefaults.standard.set(Double(value), forKey: effectSpeedKey)
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
                        let hasImage = effectImageURL.flatMap { FileManager.default.fileExists(atPath: $0.path) } ?? false
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
            }
        },
        openDisclosureLink: { link in
            switch link {
            case .ntfyCopyTopic:
                UIPasteboard.general.string = KalgramNtfy.topic
                showToast?("Топик скопирован")
            case .islandPickImage:
                KalgramIsland.shared.pickImage(completion: {
                    reloadPromise.set(true)
                })
            case .effectPickImage:
                KalgramImagePicker.shared.pick(maxSide: 128.0, completion: { image in
                    if let url = effectImageURL {
                        try? image.pngData()?.write(to: url)
                        SGSimpleSettings.shared.nyStyle = SGSimpleSettings.NYStyle.custom.rawValue
                    }
                    reloadPromise.set(true)
                })
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
            case .islandReset:
                KalgramIsland.shared.resetToDevice()
                reloadPromise.set(true)
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
