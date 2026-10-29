import Foundation
internal import TelegramApi
import Postbox
import SwiftSignalKit

// kalgram: tells the server a chat is read now, even while ghost mode holds read
// receipts back. Only this chat, only this once; ghost mode stays on.
func _internal_kalgramSendReadReceipt(postbox: Postbox, network: Network, stateManager: AccountStateManager, peerId: PeerId) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Signal<Void, NoError> in
        guard let peer = transaction.getPeer(peerId) else {
            return .complete()
        }
        if peerId.namespace == Namespaces.Peer.CloudChannel {
            guard let inputChannel = apiInputChannel(peer) else {
                return .complete()
            }
            return network.request(Api.functions.channels.readHistory(channel: inputChannel, maxId: Int32.max - 1))
            |> `catch` { _ -> Signal<Api.Bool, NoError> in
                return .single(.boolFalse)
            }
            |> mapToSignal { _ -> Signal<Void, NoError> in
                return .complete()
            }
        } else if peerId.namespace == Namespaces.Peer.CloudUser || peerId.namespace == Namespaces.Peer.CloudGroup {
            guard let inputPeer = apiInputPeer(peer) else {
                return .complete()
            }
            return network.request(Api.functions.messages.readHistory(peer: inputPeer, maxId: Int32.max - 1))
            |> map(Optional.init)
            |> `catch` { _ -> Signal<Api.messages.AffectedMessages?, NoError> in
                return .single(nil)
            }
            |> mapToSignal { result -> Signal<Void, NoError> in
                if let result {
                    switch result {
                    case let .affectedMessages(affectedMessagesData):
                        stateManager.addUpdateGroups([.updatePts(pts: affectedMessagesData.pts, ptsCount: affectedMessagesData.ptsCount)])
                    }
                }
                return .complete()
            }
        }
        return .complete()
    }
    |> switchToLatest
}
