import Foundation
import UIKit
import AccountContext
import UndoUI
import SGSimpleSettings

// kalgram: «Подготовка». Counts only the time the app is open: a timer runs while it is active and is
// gone in the background, so nothing ticks and nothing wakes the phone. Every N minutes of use a
// banner over the app says to go and study.
final class KalgramStudyReminder {
    static let shared = KalgramStudyReminder()

    private weak var sharedContext: SharedAccountContext?
    private var observers: [NSObjectProtocol] = []
    private var timer: Timer?
    private var activeSince: Date?
    private var phraseIndex = 0

    private var spent: TimeInterval {
        get {
            return UserDefaults.standard.double(forKey: KalgramStudySettings.spentKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: KalgramStudySettings.spentKey)
        }
    }

    func start(sharedContext: SharedAccountContext) {
        guard self.sharedContext == nil else {
            return
        }
        self.sharedContext = sharedContext
        let center = NotificationCenter.default
        self.observers.append(center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main, using: { [weak self] _ in
            self?.becameActive()
        }))
        self.observers.append(center.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main, using: { [weak self] _ in
            self?.resignedActive()
        }))
        self.observers.append(center.addObserver(forName: KalgramStudySettings.changedNotification, object: nil, queue: .main, using: { [weak self] _ in
            self?.settingsChanged()
        }))
        if UIApplication.shared.applicationState == .active {
            self.becameActive()
        }
    }

    private func becameActive() {
        if self.activeSince == nil {
            self.activeSince = Date()
        }
        self.schedule()
    }

    private func resignedActive() {
        self.collectSpent()
        self.activeSince = nil
        self.timer?.invalidate()
        self.timer = nil
    }

    private func settingsChanged() {
        if !KalgramStudySettings.isEnabled {
            self.spent = 0.0
            if self.activeSince != nil {
                self.activeSince = Date()
            }
        }
        self.schedule()
    }

    private func collectSpent() {
        if let activeSince = self.activeSince {
            self.spent += max(0.0, Date().timeIntervalSince(activeSince))
            self.activeSince = Date()
        }
    }

    private func schedule() {
        self.timer?.invalidate()
        self.timer = nil
        guard KalgramStudySettings.isEnabled, self.activeSince != nil else {
            return
        }
        self.collectSpent()
        let interval = TimeInterval(KalgramStudySettings.minutes * 60)
        let remaining = max(1.0, interval - self.spent)
        let timer = Timer(timeInterval: remaining, repeats: false, block: { [weak self] _ in
            self?.fire()
        })
        // The moment does not matter to the second: let iOS batch it with other wakeups
        timer.tolerance = 5.0
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func fire() {
        self.timer = nil
        self.spent = 0.0
        self.activeSince = Date()
        if let sharedContext = self.sharedContext {
            let phrases = KalgramStudySettings.phrases
            let text = phrases[self.phraseIndex % phrases.count]
            self.phraseIndex += 1
            let presentationData = sharedContext.currentPresentationData.with { $0 }
            sharedContext.presentGlobalController(UndoOverlayController(presentationData: presentationData, content: .info(title: "📚 Подготовка · \(KalgramStudySettings.minutes) мин", text: text, timeout: 8.0, customUndoText: nil), elevatedLayout: false, action: { _ in return true }), nil)
        }
        self.schedule()
    }
}
