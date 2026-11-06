import Foundation
import UIKit

// kalgram: the app's font, adapted from Ghostgram (GPLv2). Read once at launch, so changing it needs a
// restart, and with no font chosen the cost is one nil check per font request.
public let kalgramFontFamilyKey = "kalgram.fontFamily"

private let kalgramFontStyle: String? = UserDefaults.standard.string(forKey: kalgramFontFamilyKey)

private struct KalgramFontKey: Hashable {
    let size: CGFloat
    let weight: CGFloat
}

private let kalgramFontLock = NSLock()
private var kalgramFontCache: [KalgramFontKey: UIFont] = [:]

func kalgramSubstituteFont(size: CGFloat, weight: UIFont.Weight) -> UIFont? {
    guard let style = kalgramFontStyle else {
        return nil
    }
    let key = KalgramFontKey(size: size, weight: weight.rawValue)
    kalgramFontLock.lock()
    defer {
        kalgramFontLock.unlock()
    }
    if let cached = kalgramFontCache[key] {
        return cached
    }
    let system = UIFont.systemFont(ofSize: size, weight: weight)
    var font = system
    switch style {
    case "rounded":
        if let descriptor = system.fontDescriptor.withDesign(.rounded) {
            font = UIFont(descriptor: descriptor, size: size)
        }
    case "serif":
        if let descriptor = system.fontDescriptor.withDesign(.serif) {
            font = UIFont(descriptor: descriptor, size: size)
        }
    case "monospaced":
        if let descriptor = system.fontDescriptor.withDesign(.monospaced) {
            font = UIFont(descriptor: descriptor, size: size)
        }
    default:
        // A family of iOS. Where it has no Cyrillic, iOS draws those letters with the system font.
        let descriptor = UIFontDescriptor(fontAttributes: [
            .family: style,
            .traits: [UIFontDescriptor.TraitKey.weight: weight.rawValue]
        ])
        font = UIFont(descriptor: descriptor, size: size)
    }
    kalgramFontCache[key] = font
    return font
}
