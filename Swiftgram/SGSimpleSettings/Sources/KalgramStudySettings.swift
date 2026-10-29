import Foundation

// kalgram: «Подготовка» — every N minutes spent in the app, a reminder to go and study
public enum KalgramStudySettings {
    public static let enabledKey = "kalgram.study.enabled"
    public static let minutesKey = "kalgram.study.minutes"
    // Time already spent in the app since the last reminder, kept across launches
    public static let spentKey = "kalgram.study.spent"
    public static let changedNotification = Notification.Name("KalgramStudySettingsChanged")

    public static let minuteChoices: [Int] = [10, 15, 20, 30, 45, 60, 90]

    public static var isEnabled: Bool {
        get {
            return UserDefaults.standard.bool(forKey: enabledKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: enabledKey)
            NotificationCenter.default.post(name: changedNotification, object: nil)
        }
    }

    public static var minutes: Int {
        get {
            let value = UserDefaults.standard.integer(forKey: minutesKey)
            return value > 0 ? value : 20
        }
        set {
            UserDefaults.standard.set(newValue, forKey: minutesKey)
            NotificationCenter.default.post(name: changedNotification, object: nil)
        }
    }

    public static let phrases: [String] = [
        "Хватит сидеть в телеге — иди занимайся 💪",
        "ЕГЭ сам себя не сдаст. Открывай учебник 📚",
        "Ещё один вариант решишь — тогда и вернёшься 😉",
        "Время вышло. Отложи телефон и учи 🧠",
        "Пролистал достаточно. Пора к задачам ✍️",
        "Через год скажешь себе спасибо. Иди учи 🎯"
    ]
}
