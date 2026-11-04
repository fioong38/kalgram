import Foundation
import UIKit
import SwiftSignalKit
import TelegramCore

// kalgram: AMOLED black and hidden separators, on top of whatever theme is selected. Adapted from
// Ghostgram (GPLv2). A pure black pixel is off on an OLED screen, so this also saves battery. The
// derived theme is cached: a new theme instance would re-lay out every screen.
private let kalgramThemeCache = Atomic<(source: PresentationTheme, amoled: Bool, separators: Bool, result: PresentationTheme)?>(value: nil)

public func kalgramTransformedTheme(_ source: PresentationTheme) -> PresentationTheme {
    let amoled = KalgramTweaks.amoled && source.overallDarkAppearance
    let hideSeparators = KalgramTweaks.hideSeparators
    if !amoled && !hideSeparators {
        return source
    }
    if let cached = kalgramThemeCache.with({ $0 }), cached.source === source, cached.amoled == amoled, cached.separators == hideSeparators {
        return cached.result
    }

    var rootController = source.rootController
    var list = source.list
    var chatList = source.chatList
    var chat = source.chat
    var actionSheet = source.actionSheet
    var contextMenu = source.contextMenu
    var inAppNotification = source.inAppNotification

    if amoled {
        let black = UIColor(rgb: 0x000000)
        let elevated = UIColor(rgb: 0x0e0e0e)
        let raised = UIColor(rgb: 0x141414)
        let pressed = UIColor(rgb: 0x1d1d1d)

        list = list.withUpdated(blocksBackgroundColor: black, modalBlocksBackgroundColor: black, plainBackgroundColor: black, modalPlainBackgroundColor: black, itemBlocksBackgroundColor: elevated, itemModalBlocksBackgroundColor: elevated, itemHighlightedBackgroundColor: pressed)
        chatList = chatList.withUpdated(backgroundColor: black, itemBackgroundColor: black, pinnedItemBackgroundColor: elevated, itemHighlightedBackgroundColor: pressed, pinnedItemHighlightedBackgroundColor: pressed, itemSelectedBackgroundColor: pressed)
        rootController = rootController.withUpdated(
            tabBar: rootController.tabBar.withUpdated(backgroundColor: black),
            navigationBar: rootController.navigationBar.withUpdated(blurredBackgroundColor: black.withAlphaComponent(0.9), opaqueBackgroundColor: black),
            navigationSearchBar: rootController.navigationSearchBar.withUpdated(backgroundColor: black, inputFillColor: raised)
        )
        chat = chat.withUpdated(inputPanel: chat.inputPanel.withUpdated(panelBackgroundColor: black, panelBackgroundColorNoWallpaper: black, inputBackgroundColor: raised))
        actionSheet = actionSheet.withUpdated(opaqueItemBackgroundColor: elevated, opaqueItemHighlightedBackgroundColor: pressed)
        contextMenu = contextMenu.withUpdated(backgroundColor: elevated, itemHighlightedBackgroundColor: pressed)
        inAppNotification = inAppNotification.withUpdated(fillColor: elevated)
    }

    if hideSeparators {
        // Alpha 0 keeps the color, so code that derives another color from a separator still works
        func hidden(_ color: UIColor) -> UIColor {
            return color.withAlphaComponent(0.0)
        }
        list = list.withUpdated(itemBlocksSeparatorColor: hidden(list.itemBlocksSeparatorColor), itemPlainSeparatorColor: hidden(list.itemPlainSeparatorColor))
        chatList = chatList.withUpdated(itemSeparatorColor: hidden(chatList.itemSeparatorColor))
        rootController = rootController.withUpdated(
            tabBar: rootController.tabBar.withUpdated(separatorColor: hidden(rootController.tabBar.separatorColor)),
            navigationBar: rootController.navigationBar.withUpdated(separatorColor: hidden(rootController.navigationBar.separatorColor)),
            navigationSearchBar: rootController.navigationSearchBar.withUpdated(separatorColor: hidden(rootController.navigationSearchBar.separatorColor))
        )
        chat = chat.withUpdated(
            inputPanel: chat.inputPanel.withUpdated(panelSeparatorColor: hidden(chat.inputPanel.panelSeparatorColor)),
            inputMediaPanel: chat.inputMediaPanel.withUpdated(panelSeparatorColor: hidden(chat.inputMediaPanel.panelSeparatorColor)),
            inputButtonPanel: chat.inputButtonPanel.withUpdated(panelSeparatorColor: hidden(chat.inputButtonPanel.panelSeparatorColor))
        )
        actionSheet = actionSheet.withUpdated(opaqueItemSeparatorColor: hidden(actionSheet.opaqueItemSeparatorColor))
        contextMenu = contextMenu.withUpdated(itemSeparatorColor: hidden(contextMenu.itemSeparatorColor))
    }

    let result = PresentationTheme(name: source.name, index: source.index, referenceTheme: source.referenceTheme, overallDarkAppearance: source.overallDarkAppearance, intro: source.intro, passcode: source.passcode, rootController: rootController, list: list, chatList: chatList, chat: chat, actionSheet: actionSheet, contextMenu: contextMenu, inAppNotification: inAppNotification, chart: source.chart, preview: source.preview)
    result.starGift = source.starGift
    result.forceSync = source.forceSync
    let _ = kalgramThemeCache.swap((source, amoled, hideSeparators, result))
    return result
}
