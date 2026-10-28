import Foundation
import SwiftSignalKit
import Postbox
internal import TelegramApi


public enum NotificationTokenType {
    case aps(encrypt: Bool)
    case voip
}

func _internal_unregisterNotificationToken(account: Account, token: Data, type: NotificationTokenType, otherAccountUserIds: [PeerId.Id]) -> Signal<Never, NoError> {
    let mappedType: Int32
    switch type {
        case .aps:
            mappedType = 1
        case .voip:
            mappedType = 9
    }
    return account.network.request(Api.functions.account.unregisterDevice(tokenType: mappedType, token: hexString(token), otherUids: otherAccountUserIds.map({ $0._internalGetInt64Value() })))
    |> retryRequest
    |> ignoreValues
}

// kalgram: a sideloaded build cannot receive APNs pushes from Telegram, so the
// server is asked to send a Simple Push (token_type 4, also used for
// UnifiedPush) to an ntfy topic instead. The ntfy app then delivers a real push.
// The server only sends a wake-up signal, no message content.
public enum KalgramNtfy {
    private static let topicKey = "kalgram.ntfy.topic"
    private static let statusKey = "kalgram.ntfy.status"

    public static var topic: String {
        if let topic = UserDefaults.standard.string(forKey: topicKey), !topic.isEmpty {
            return topic
        }
        let alphabet = Array("abcdefghijklmnopqrstuvwxyz0123456789")
        let topic = "kg" + String((0 ..< 24).map { _ in alphabet[Int.random(in: 0 ..< alphabet.count)] })
        UserDefaults.standard.set(topic, forKey: topicKey)
        return topic
    }

    public static var endpoint: String {
        return "https://ntfy.sh/\(topic)"
    }

    public static var lastStatus: String? {
        get {
            return UserDefaults.standard.string(forKey: statusKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: statusKey)
        }
    }
}

func _internal_registerSimplePushEndpoint(account: Account, endpoint: String, otherAccountUserIds: [PeerId.Id], excludeMutedChats: Bool) -> Signal<String?, NoError> {
    var flags: Int32 = 0
    if excludeMutedChats {
        flags |= 1 << 0
    }
    return account.network.request(Api.functions.account.registerDevice(flags: flags, tokenType: 4, token: endpoint, appSandbox: .boolFalse, secret: Buffer(data: Data()), otherUids: otherAccountUserIds.map({ $0._internalGetInt64Value() })))
    |> map { _ -> String? in
        return nil
    }
    |> `catch` { error -> Signal<String?, NoError> in
        return .single(error.errorDescription)
    }
}

func _internal_registerNotificationToken(account: Account, token: Data, type: NotificationTokenType, sandbox: Bool, otherAccountUserIds: [PeerId.Id], excludeMutedChats: Bool) -> Signal<Bool, NoError> {
    return masterNotificationsKey(account: account, ignoreDisabled: false)
    |> mapToSignal { masterKey -> Signal<Bool, NoError> in
        let mappedType: Int32
        var keyData = Data()
        switch type {
            case let .aps(encrypt):
                mappedType = 1
                if encrypt {
                    keyData = masterKey.data
                }
            case .voip:
                mappedType = 9
                keyData = masterKey.data
        }
        var flags: Int32 = 0
        if excludeMutedChats {
            flags |= 1 << 0
        }
        return account.network.request(Api.functions.account.registerDevice(flags: flags, tokenType: mappedType, token: hexString(token), appSandbox: sandbox ? .boolTrue : .boolFalse, secret: Buffer(data: keyData), otherUids: otherAccountUserIds.map({ $0._internalGetInt64Value() })))
        |> map { _ -> Bool in
            return true
        }
        |> `catch` { error -> Signal<Bool, NoError> in
            if error.errorDescription == "TOKEN_WAS_INVALIDATED" {
                return .single(false)
            } else {
                return .single(true)
            }
        }
    }
}
