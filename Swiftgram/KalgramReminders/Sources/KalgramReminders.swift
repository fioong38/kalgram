import Foundation
import UserNotifications

/// A "remind me about this message" entry. Persisted in `Documents/kalgram_reminders.json`.
public struct KalgramReminder: Codable, Equatable {
    public let id: String
    public let accountPeerId: Int64
    public let peerId: Int64
    public let messageNamespace: Int32
    public let messageId: Int32
    public let chatTitle: String
    public let preview: String
    public var fireDate: Date

    public init(id: String, accountPeerId: Int64, peerId: Int64, messageNamespace: Int32, messageId: Int32, chatTitle: String, preview: String, fireDate: Date) {
        self.id = id
        self.accountPeerId = accountPeerId
        self.peerId = peerId
        self.messageNamespace = messageNamespace
        self.messageId = messageId
        self.chatTitle = chatTitle
        self.preview = preview
        self.fireDate = fireDate
    }
}

/// Quick times offered in the "Напомнить" submenu.
public enum KalgramReminderPreset: CaseIterable {
    case inOneHour
    case evening
    case tomorrowMorning

    public var title: String {
        switch self {
        case .inOneHour:
            return "Через час"
        case .evening:
            return "Вечером (20:00)"
        case .tomorrowMorning:
            return "Завтра утром (9:00)"
        }
    }

    public func fireDate(now: Date = Date(), calendar: Calendar = .current) -> Date {
        switch self {
        case .inOneHour:
            return now.addingTimeInterval(60 * 60)
        case .evening:
            var date = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: now) ?? now.addingTimeInterval(60 * 60)
            if date <= now {
                date = calendar.date(byAdding: .day, value: 1, to: date) ?? date
            }
            return date
        case .tomorrowMorning:
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
            return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) ?? tomorrow
        }
    }
}

/// JSON-file backed list of reminders. Access is serialized through a private queue.
public final class KalgramReminderStore {
    public static let shared = KalgramReminderStore()

    private let queue = DispatchQueue(label: "kalgram.reminders.store")
    private let fileUrl: URL?

    private init() {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        self.fileUrl = directory?.appendingPathComponent("kalgram_reminders.json")
    }

    public func all() -> [KalgramReminder] {
        return self.queue.sync {
            return self.readLocked()
        }
    }

    public func get(id: String) -> KalgramReminder? {
        return self.all().first(where: { $0.id == id })
    }

    public func upsert(_ reminder: KalgramReminder) {
        self.queue.sync {
            var items = self.readLocked()
            items.removeAll(where: { $0.id == reminder.id })
            items.append(reminder)
            self.writeLocked(items)
        }
    }

    public func remove(id: String) {
        self.queue.sync {
            var items = self.readLocked()
            items.removeAll(where: { $0.id == id })
            self.writeLocked(items)
        }
    }

    private func readLocked() -> [KalgramReminder] {
        guard let fileUrl = self.fileUrl, let data = try? Data(contentsOf: fileUrl) else {
            return []
        }
        return (try? JSONDecoder().decode([KalgramReminder].self, from: data)) ?? []
    }

    private func writeLocked(_ items: [KalgramReminder]) {
        guard let fileUrl = self.fileUrl else {
            return
        }
        do {
            let data = try JSONEncoder().encode(items)
            try data.write(to: fileUrl, options: .atomic)
        } catch {
        }
    }
}

/// Local notifications for reminders, with snooze actions.
public enum KalgramReminderCenter {
    public static let categoryIdentifier = "kalgram_reminder"
    public static let snoozeTenMinutesAction = "kalgram_snooze_10"
    public static let snoozeHourAction = "kalgram_snooze_60"
    public static let snoozeTomorrowAction = "kalgram_snooze_tomorrow"

    public static var category: UNNotificationCategory {
        let actions: [UNNotificationAction] = [
            UNNotificationAction(identifier: snoozeTenMinutesAction, title: "Отложить на 10 мин", options: []),
            UNNotificationAction(identifier: snoozeHourAction, title: "На час", options: []),
            UNNotificationAction(identifier: snoozeTomorrowAction, title: "До завтра", options: [])
        ]
        return UNNotificationCategory(identifier: categoryIdentifier, actions: actions, intentIdentifiers: [], options: [])
    }

    /// Adds the reminder category to whatever categories are already registered. It never replaces them.
    public static func installCategory() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationCategories { existing in
            var categories = existing.filter({ $0.identifier != categoryIdentifier })
            categories.insert(category)
            center.setNotificationCategories(categories)
        }
    }

    /// Reads the message the reminder points at from a notification's userInfo.
    public static func target(from userInfo: [AnyHashable: Any]) -> (accountPeerId: Int64, peerId: Int64, messageNamespace: Int32, messageId: Int32)? {
        guard let accountPeerId = userInfo["kalgram.accountPeerId"] as? Int64,
              let peerId = userInfo["kalgram.peerId"] as? Int64,
              let messageNamespace = userInfo["kalgram.messageNamespace"] as? Int32,
              let messageId = userInfo["kalgram.messageId"] as? Int32 else {
            return nil
        }
        return (accountPeerId, peerId, messageNamespace, messageId)
    }

    /// Stores the reminder and schedules its notification.
    public static func create(_ reminder: KalgramReminder) {
        KalgramReminderStore.shared.upsert(reminder)
        schedule(reminder)
    }

    public static func cancel(id: String) {
        KalgramReminderStore.shared.remove(id: id)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])
        center.removeDeliveredNotifications(withIdentifiers: [id])
    }

    /// Reschedules the reminder for a snooze action. Unknown actions are ignored.
    public static func snooze(id: String, action: String, now: Date = Date(), calendar: Calendar = .current) {
        guard var reminder = KalgramReminderStore.shared.get(id: id) else {
            return
        }
        let fireDate: Date
        switch action {
        case snoozeTenMinutesAction:
            fireDate = now.addingTimeInterval(10 * 60)
        case snoozeHourAction:
            fireDate = now.addingTimeInterval(60 * 60)
        case snoozeTomorrowAction:
            fireDate = KalgramReminderPreset.tomorrowMorning.fireDate(now: now, calendar: calendar)
        default:
            return
        }
        reminder.fireDate = fireDate
        let center = UNUserNotificationCenter.current()
        center.removeDeliveredNotifications(withIdentifiers: [id])
        center.removePendingNotificationRequests(withIdentifiers: [id])
        KalgramReminderStore.shared.upsert(reminder)
        schedule(reminder)
    }

    private static func schedule(_ reminder: KalgramReminder) {
        installCategory()

        let content = UNMutableNotificationContent()
        content.title = "Напоминание"
        content.body = "\(reminder.chatTitle): \(reminder.preview)"
        content.sound = .default
        content.categoryIdentifier = categoryIdentifier
        content.userInfo = [
            "kalgram.reminderId": reminder.id,
            "kalgram.accountPeerId": reminder.accountPeerId,
            "kalgram.peerId": reminder.peerId,
            "kalgram.messageNamespace": reminder.messageNamespace,
            "kalgram.messageId": reminder.messageId
        ]

        let interval = max(1.0, reminder.fireDate.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: reminder.id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}
