import Foundation
import SwiftSignalKit
import TelegramCore
import AccountContext

// kalgram: the locked secret folder does not exist for the tabs, menus and pickers. Adapted from
// Ghostgram (GPLv2).
public func kalgramVisibleFolders(_ signal: Signal<[ChatListFilter], NoError>, context: AccountContext) -> Signal<[ChatListFilter], NoError> {
    return combineLatest(signal, KalgramChatLockSettings.hiddenFolderId(accountPeerId: context.account.peerId))
    |> map { filters, hiddenId -> [ChatListFilter] in
        if hiddenId == 0 {
            return filters
        }
        return filters.filter { filter in
            if case let .filter(id, _, _, _) = filter {
                return id != hiddenId
            }
            return true
        }
    }
}

private struct KalgramFolderRefresh {
    var folderId: Int32
    var time: Double
}

private var kalgramFolderRefreshes: [Int64: KalgramFolderRefresh] = [:]

// Ghostgram keeps a live view of the folder to know its members. Here it is one read when the chat
// list appears, at most every 5 minutes unless the folder changed, so nothing runs while idle. A chat
// added to the folder is protected from the next read. Main thread.
func kalgramRefreshSecretFolderMembers(context: AccountContext) {
    let accountPeerId = context.account.peerId
    let folderId = KalgramChatLockSettings.secretFolderId(accountPeerId: accountPeerId)
    if folderId == 0 || !KalgramChatLockSettings.secretFolderProtectsChats(accountPeerId: accountPeerId) {
        return
    }
    let now = CFAbsoluteTimeGetCurrent()
    let key = accountPeerId.toInt64()
    if let last = kalgramFolderRefreshes[key], last.folderId == folderId, now - last.time < 5.0 * 60.0 {
        return
    }
    kalgramFolderRefreshes[key] = KalgramFolderRefresh(folderId: folderId, time: now)

    let _ = (context.engine.peers.updatedChatListFilters()
    |> take(1)
    |> mapToSignal { filters -> Signal<Set<Int64>, NoError> in
        var folderData: ChatListFilterData?
        for filter in filters {
            if case let .filter(id, _, _, data) = filter, id == folderId {
                folderData = data
            }
        }
        guard var data = folderData else {
            return .single(Set())
        }
        // A chat must not lose its protection because it was just read
        data.excludeRead = false
        data.excludeMuted = false
        var explicit = Set<Int64>()
        for peerId in data.includePeers.peers {
            explicit.insert(peerId.toInt64())
        }
        for peerId in data.includePeers.pinnedPeers {
            explicit.insert(peerId.toInt64())
        }
        return context.engine.peers.getChatListPeers(filterPredicate: chatListFilterPredicate(filter: data, accountPeerId: accountPeerId))
        |> map { peers -> Set<Int64> in
            var result = explicit
            for peer in peers {
                result.insert(peer.id.toInt64())
            }
            return result
        }
    }
    |> deliverOnMainQueue).startStandalone(next: { peers in
        KalgramChatLockSettings.setSecretFolderPeers(peers, accountPeerId: accountPeerId)
    })
}
