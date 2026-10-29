import Foundation

// kalgram: the settings of the falling effect in chats, and its pictures. Read by the wallpaper's
// effect (SGNY) and written by kalgram Pro. Percentages run 0...100, like the sliders.
public enum KalgramEffectSettings {
    public enum Direction: String, CaseIterable {
        case down
        case up
        case sway
    }

    public static let maxPictures = 5

    public static let densityKey = "kalgram.effect.density"
    public static let speedKey = "kalgram.effect.speed"
    public static let sizeKey = "kalgram.effect.size"
    public static let sizeSpreadKey = "kalgram.effect.sizeSpread"
    public static let spinKey = "kalgram.effect.spin"
    public static let spinSpreadKey = "kalgram.effect.spinSpread"
    public static let opacityKey = "kalgram.effect.opacity"
    public static let directionKey = "kalgram.effect.direction"
    public static let removeBackgroundKey = "kalgram.effect.removeBackground"

    public static func percent(_ key: String, default value: Double) -> Double {
        return UserDefaults.standard.object(forKey: key) as? Double ?? value
    }

    public static func setPercent(_ key: String, _ value: Double) {
        UserDefaults.standard.set(value, forKey: key)
    }

    public static var direction: Direction {
        get {
            return UserDefaults.standard.string(forKey: directionKey).flatMap(Direction.init(rawValue:)) ?? .down
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: directionKey)
        }
    }

    // Whether a picture loses its background when it is picked
    public static var removeBackground: Bool {
        get {
            return UserDefaults.standard.object(forKey: removeBackgroundKey) as? Bool ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: removeBackgroundKey)
        }
    }

    private static var documentsURL: URL? {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }

    private static func slotURL(_ slot: Int) -> URL? {
        return documentsURL?.appendingPathComponent("kalgram-particle-\(slot).png")
    }

    // The one picture from before there were slots, kept until the next pick moves it into slot 0
    private static var legacyURL: URL? {
        return documentsURL?.appendingPathComponent("kalgram-particle.png")
    }

    private static func exists(_ url: URL) -> Bool {
        return FileManager.default.fileExists(atPath: url.path)
    }

    // The pictures in use, in slot order
    public static func pictureURLs() -> [URL] {
        var urls: [URL] = []
        for slot in 0 ..< maxPictures {
            if let url = slotURL(slot), exists(url) {
                urls.append(url)
            }
        }
        if urls.isEmpty, let legacy = legacyURL, exists(legacy) {
            urls.append(legacy)
        }
        return urls
    }

    // Stores a picture (PNG) in the first free slot. False when every slot is taken or writing fails.
    public static func addPicture(_ data: Data) -> Bool {
        migrateLegacyPicture()
        for slot in 0 ..< maxPictures {
            guard let url = slotURL(slot), !exists(url) else {
                continue
            }
            return (try? data.write(to: url)) != nil
        }
        return false
    }

    public static func removeAllPictures() {
        for slot in 0 ..< maxPictures {
            if let url = slotURL(slot) {
                try? FileManager.default.removeItem(at: url)
            }
        }
        if let legacy = legacyURL {
            try? FileManager.default.removeItem(at: legacy)
        }
    }

    private static func migrateLegacyPicture() {
        guard let legacy = legacyURL, exists(legacy), let first = slotURL(0), !exists(first) else {
            return
        }
        try? FileManager.default.moveItem(at: legacy, to: first)
    }
}
