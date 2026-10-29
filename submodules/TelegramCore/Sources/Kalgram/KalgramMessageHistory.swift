import Foundation
import Postbox

// kalgram: keep messages the other side deleted, and the previous text of edited
// messages, in private chats.
//
// The markers are appended to the stored text, never prepended, so the offsets of
// the message's text entities stay valid. Only the local copy changes; nothing is
// sent to the server.

// Builds before the local tag wrote this into the text
private let kalgramDeletedMarker = "🗑 Удалено"
private let kalgramEditMarker = "\n\n✏️ было: "

private func kalgramKeepsHistory(peerId: PeerId, accountPeerId: PeerId) -> Bool {
    return peerId.namespace == Namespaces.Peer.CloudUser && peerId != accountPeerId
}

private func storeMessage(_ message: StoreMessage, text: String) -> StoreMessage {
    guard case let .Id(id) = message.id else {
        return message
    }
    return StoreMessage(id: id, customStableId: message.customStableId, globallyUniqueId: message.globallyUniqueId, groupingKey: message.groupingKey, threadId: message.threadId, timestamp: message.timestamp, flags: message.flags, tags: message.tags, globalTags: message.globalTags, localTags: message.localTags, forwardInfo: message.forwardInfo, authorId: message.authorId, text: text, attributes: message.attributes, media: message.media)
}

// Splits a stored text into what the sender wrote last and the kept edit history
private func splitEditHistory(_ text: String) -> (current: String, history: String) {
    if let range = text.range(of: kalgramEditMarker) {
        return (String(text[..<range.lowerBound]), String(text[range.lowerBound...]))
    }
    return (text, "")
}

// Marks the messages that are kept instead of deleted and returns their ids
func kalgramKeepDeletedMessages(transaction: Transaction, accountPeerId: PeerId, ids: [MessageId]) -> [MessageId] {
    guard KalgramTweaks.keepDeletedMessages else {
        return []
    }
    var kept: [MessageId] = []
    for id in ids {
        guard kalgramKeepsHistory(peerId: id.peerId, accountPeerId: accountPeerId), id.namespace == Namespaces.Message.Cloud else {
            continue
        }
        guard let message = transaction.getMessage(id) else {
            continue
        }
        kept.append(id)
        // Marked with a local tag rather than in the text, so a sender cannot fake it:
        // the chat shows "удалено" next to the time (stringForMessageTimestampStatus)
        if message.localTags.contains(.KalgramDeleted) || message.text.hasSuffix(kalgramDeletedMarker) {
            continue
        }
        transaction.updateMessage(id, update: { currentMessage in
            var storeForwardInfo: StoreMessageForwardInfo?
            if let forwardInfo = currentMessage.forwardInfo {
                storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author?.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature, psaType: forwardInfo.psaType, flags: forwardInfo.flags)
            }
            var localTags = currentMessage.localTags
            localTags.insert(.KalgramDeleted)
            return .update(StoreMessage(id: currentMessage.id, customStableId: nil, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: currentMessage.attributes, media: currentMessage.media))
        })
    }
    return kept
}

// Applied to a server edit of an incoming private message: keeps what it said before
func kalgramMergeEditHistory(previous: Message, updated: StoreMessage, accountPeerId: PeerId) -> StoreMessage {
    guard KalgramTweaks.keepEditHistory, kalgramKeepsHistory(peerId: previous.id.peerId, accountPeerId: accountPeerId), previous.flags.contains(.Incoming) else {
        return updated
    }
    let (previousText, history) = splitEditHistory(previous.text)
    if updated.text == previousText {
        // Not a text edit (reactions, views): keep the history that is already there
        if history.isEmpty {
            return updated
        }
        return storeMessage(updated, text: updated.text + history)
    }
    if previousText.isEmpty {
        return updated
    }
    return storeMessage(updated, text: updated.text + kalgramEditMarker + previousText + history)
}
