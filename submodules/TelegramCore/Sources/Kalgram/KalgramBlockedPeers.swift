import Foundation
import Postbox
import SwiftSignalKit

// kalgram: hides messages of blocked users in groups and channels. Adapted from Ghostgram (GPLv2).
//
// The list is read from an immutable set, because the history builder asks for every message. It is
// loaded only while the switch is on, at most once per 30 minutes per account, and only when a chat
// history is actually being built, so an idle app makes no requests for it.
public final class KalgramBlockedPeers {
    public static let shared = KalgramBlockedPeers()

    public static let enabledKey = "kalgram.hideBlockedMessages"

    public static var isEnabled: Bool {
        get {
            return UserDefaults.standard.bool(forKey: enabledKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: enabledKey)
        }
    }

    private static let refreshInterval: Double = 30.0 * 60.0

    private let sets = Atomic<[PeerId: Set<PeerId>]>(value: [:])
    private let lastLoads = Atomic<[PeerId: Double]>(value: [:])
    // Main thread
    private var loaders: [PeerId: (BlockedPeersContext, Disposable)] = [:]

    private init() {
    }

    public func isHidden(_ message: Message, account: Account) -> Bool {
        let namespace = message.id.peerId.namespace
        guard namespace == Namespaces.Peer.CloudGroup || namespace == Namespaces.Peer.CloudChannel else {
            return false
        }
        guard let author = message.author, author.id != account.peerId, author.id != message.id.peerId else {
            return false
        }
        return self.sets.with { $0[account.peerId]?.contains(author.id) ?? false }
    }

    // Called once per history build, on any queue
    public func refreshIfNeeded(account: Account) {
        let now = CFAbsoluteTimeGetCurrent()
        let accountPeerId = account.peerId
        let isStale = self.lastLoads.modify { current in
            if let last = current[accountPeerId], now - last < KalgramBlockedPeers.refreshInterval {
                return current
            }
            var current = current
            current[accountPeerId] = now
            return current
        }[accountPeerId] == now
        if isStale {
            Queue.mainQueue().async {
                self.load(account: account)
            }
        }
    }

    private func load(account: Account) {
        let accountPeerId = account.peerId
        if self.loaders[accountPeerId] != nil {
            return
        }
        let context = BlockedPeersContext(account: account, subject: .blocked)
        let disposable = (context.state
        |> deliverOnMainQueue).start(next: { [weak self, weak context] state in
            guard let self else {
                return
            }
            if state.canLoadMore {
                if !state.isLoadingMore {
                    context?.loadMore()
                }
                return
            }
            let peerIds = Set(state.peers.map { $0.peerId })
            let _ = self.sets.modify { current in
                var current = current
                current[accountPeerId] = peerIds
                return current
            }
            // The set is what gets read from now on, the context can go
            Queue.mainQueue().async {
                if let (_, disposable) = self.loaders.removeValue(forKey: accountPeerId) {
                    disposable.dispose()
                }
            }
        })
        self.loaders[accountPeerId] = (context, disposable)
    }
}
