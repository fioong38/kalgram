import Foundation
import UIKit
import Display

// kalgram: badges, a picture shown in place of the Dynamic Island on screenshots.
//
// The badge is drawn by the app's main window inside the island (WindowContent's
// badgeView, offsets per iPhone model in SGAppBadgeOffset): the island covers it
// on the live screen, a screenshot has no island and shows it.
//
// A custom badge is stored as a .ggbadge document, the format Ghostgram exports:
// JSON whose enums use Swift's synthesized Codable shape ({"text":{"_0":{...}}}).

public struct KalgramBadgeColor: Codable, Equatable {
    public var hex: String

    public init(hex: String) {
        self.hex = hex
    }

    public init(_ color: UIColor) {
        var r: CGFloat = 0.0, g: CGFloat = 0.0, b: CGFloat = 0.0, a: CGFloat = 0.0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        let component: (CGFloat) -> Int = { Int((max(0.0, min(1.0, $0)) * 255.0).rounded()) }
        let value = (component(r) << 16) | (component(g) << 8) | component(b)
        if a < 1.0 {
            // #RRGGBBAA only when see-through, so opaque colours stay in Ghostgram's form
            self.hex = String(format: "#%06X%02X", value, component(a))
        } else {
            self.hex = String(format: "#%06X", value)
        }
    }

    public var uiColor: UIColor {
        var string = self.hex.trimmingCharacters(in: .whitespaces)
        if string.hasPrefix("#") {
            string.removeFirst()
        }
        let value = UInt64(string, radix: 16) ?? 0
        if string.count == 8 {
            return UIColor(red: CGFloat((value >> 24) & 0xFF) / 255.0, green: CGFloat((value >> 16) & 0xFF) / 255.0, blue: CGFloat((value >> 8) & 0xFF) / 255.0, alpha: CGFloat(value & 0xFF) / 255.0)
        }
        return UIColor(red: CGFloat((value >> 16) & 0xFF) / 255.0, green: CGFloat((value >> 8) & 0xFF) / 255.0, blue: CGFloat(value & 0xFF) / 255.0, alpha: 1.0)
    }
}

public struct KalgramBadgeText: Codable, Equatable {
    public var string: String
    public var color: KalgramBadgeColor
    public var fontSize: CGFloat
    public var weight: String
    public var isRounded: Bool
    public var strokeColor: KalgramBadgeColor
    public var strokeWidth: CGFloat
    public var tracking: CGFloat
    // kalgram additions; Ghostgram's files lack them and get the defaults
    // "serif" or "monospaced"; anything else is the system face (rounded per isRounded)
    public var design: String
    public var isItalic: Bool
    public var shadowColor: KalgramBadgeColor
    public var shadowRadius: CGFloat

    public init(string: String, color: KalgramBadgeColor = KalgramBadgeColor(hex: "#FFFFFF"), fontSize: CGFloat = 12.0, weight: String = "bold", isRounded: Bool = true, strokeColor: KalgramBadgeColor = KalgramBadgeColor(hex: "#000000"), strokeWidth: CGFloat = 0.0, tracking: CGFloat = 0.0, design: String = "default", isItalic: Bool = false, shadowColor: KalgramBadgeColor = KalgramBadgeColor(hex: "#000000"), shadowRadius: CGFloat = 0.0) {
        self.string = string
        self.color = color
        self.fontSize = fontSize
        self.weight = weight
        self.isRounded = isRounded
        self.strokeColor = strokeColor
        self.strokeWidth = strokeWidth
        self.tracking = tracking
        self.design = design
        self.isItalic = isItalic
        self.shadowColor = shadowColor
        self.shadowRadius = shadowRadius
    }

    enum CodingKeys: String, CodingKey {
        case string, color, fontSize, weight, isRounded, strokeColor, strokeWidth, tracking, design, isItalic, shadowColor, shadowRadius
    }

    // Missing fields take the defaults, files from other versions still open
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.string = (try? container.decode(String.self, forKey: .string)) ?? ""
        self.color = (try? container.decode(KalgramBadgeColor.self, forKey: .color)) ?? KalgramBadgeColor(hex: "#FFFFFF")
        self.fontSize = (try? container.decode(CGFloat.self, forKey: .fontSize)) ?? 12.0
        self.weight = (try? container.decode(String.self, forKey: .weight)) ?? "bold"
        self.isRounded = (try? container.decode(Bool.self, forKey: .isRounded)) ?? false
        self.strokeColor = (try? container.decode(KalgramBadgeColor.self, forKey: .strokeColor)) ?? KalgramBadgeColor(hex: "#000000")
        self.strokeWidth = (try? container.decode(CGFloat.self, forKey: .strokeWidth)) ?? 0.0
        self.tracking = (try? container.decode(CGFloat.self, forKey: .tracking)) ?? 0.0
        self.design = (try? container.decode(String.self, forKey: .design)) ?? "default"
        self.isItalic = (try? container.decode(Bool.self, forKey: .isItalic)) ?? false
        self.shadowColor = (try? container.decode(KalgramBadgeColor.self, forKey: .shadowColor)) ?? KalgramBadgeColor(hex: "#000000")
        self.shadowRadius = (try? container.decode(CGFloat.self, forKey: .shadowRadius)) ?? 0.0
    }
}

public struct KalgramBadgeImageRef: Codable, Equatable {
    public var assetId: String

    public init(assetId: String) {
        self.assetId = assetId
    }
}

public enum KalgramBadgeLayerContent: Codable, Equatable {
    case text(KalgramBadgeText)
    case image(KalgramBadgeImageRef)
}

public struct KalgramBadgeLayer: Codable, Equatable {
    public var id: String
    public var content: KalgramBadgeLayerContent
    public var isHidden: Bool
    public var offset: [CGFloat]
    public var opacity: CGFloat
    public var rotation: CGFloat
    public var scale: CGFloat

    public init(id: String = UUID().uuidString, content: KalgramBadgeLayerContent, isHidden: Bool = false, offset: [CGFloat] = [0.0, 0.0], opacity: CGFloat = 1.0, rotation: CGFloat = 0.0, scale: CGFloat = 1.0) {
        self.id = id
        self.content = content
        self.isHidden = isHidden
        self.offset = offset
        self.opacity = opacity
        self.rotation = rotation
        self.scale = scale
    }

    enum CodingKeys: String, CodingKey {
        case id, content, isHidden, offset, opacity, rotation, scale
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decode(String.self, forKey: .id)) ?? UUID().uuidString
        self.content = try container.decode(KalgramBadgeLayerContent.self, forKey: .content)
        self.isHidden = (try? container.decode(Bool.self, forKey: .isHidden)) ?? false
        self.offset = (try? container.decode([CGFloat].self, forKey: .offset)) ?? [0.0, 0.0]
        self.opacity = (try? container.decode(CGFloat.self, forKey: .opacity)) ?? 1.0
        self.rotation = (try? container.decode(CGFloat.self, forKey: .rotation)) ?? 0.0
        self.scale = (try? container.decode(CGFloat.self, forKey: .scale)) ?? 1.0
    }
}

public struct KalgramBadgeGradient: Codable, Equatable {
    public var colors: [KalgramBadgeColor]
    // Degrees, 0 runs left to right
    public var angle: CGFloat

    public init(colors: [KalgramBadgeColor], angle: CGFloat = 0.0) {
        self.colors = colors
        self.angle = angle
    }
}

public enum KalgramBadgeBackground: Codable, Equatable {
    case transparent
    case color(KalgramBadgeColor)
    case image(KalgramBadgeImageRef)
    // kalgram only
    case gradient(KalgramBadgeGradient)
}

// Layers that this version cannot read are skipped instead of failing the file
private struct LossyLayer: Decodable {
    let layer: KalgramBadgeLayer?

    init(from decoder: Decoder) throws {
        self.layer = try? KalgramBadgeLayer(from: decoder)
    }
}

public struct KalgramBadgeDocument: Codable, Equatable {
    public var id: String
    public var name: String
    public var background: KalgramBadgeBackground
    public var cornerRadius: CGFloat
    public var layers: [KalgramBadgeLayer]
    public var createdAt: String
    public var updatedAt: String
    // kalgram additions: the background picture's zoom, shift and opacity, and a border
    public var backgroundScale: CGFloat
    public var backgroundOffset: [CGFloat]
    public var backgroundOpacity: CGFloat
    public var borderWidth: CGFloat
    public var borderColor: KalgramBadgeColor

    public init(id: String = "custom.\(UUID().uuidString)", name: String, background: KalgramBadgeBackground, cornerRadius: CGFloat = 11.0, layers: [KalgramBadgeLayer], backgroundScale: CGFloat = 1.0, backgroundOffset: [CGFloat] = [0.0, 0.0], backgroundOpacity: CGFloat = 1.0, borderWidth: CGFloat = 0.0, borderColor: KalgramBadgeColor = KalgramBadgeColor(hex: "#FFFFFF")) {
        let now = ISO8601DateFormatter().string(from: Date())
        self.id = id
        self.name = name
        self.background = background
        self.cornerRadius = cornerRadius
        self.layers = layers
        self.createdAt = now
        self.updatedAt = now
        self.backgroundScale = backgroundScale
        self.backgroundOffset = backgroundOffset
        self.backgroundOpacity = backgroundOpacity
        self.borderWidth = borderWidth
        self.borderColor = borderColor
    }

    enum CodingKeys: String, CodingKey {
        case id, name, background, cornerRadius, layers, createdAt, updatedAt, backgroundScale, backgroundOffset, backgroundOpacity, borderWidth, borderColor
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decode(String.self, forKey: .id)) ?? "custom.\(UUID().uuidString)"
        self.name = (try? container.decode(String.self, forKey: .name)) ?? "Бейдж"
        self.background = (try? container.decode(KalgramBadgeBackground.self, forKey: .background)) ?? .transparent
        self.cornerRadius = (try? container.decode(CGFloat.self, forKey: .cornerRadius)) ?? 11.0
        self.layers = ((try? container.decode([LossyLayer].self, forKey: .layers)) ?? []).compactMap { $0.layer }
        let now = ISO8601DateFormatter().string(from: Date())
        self.createdAt = (try? container.decode(String.self, forKey: .createdAt)) ?? now
        self.updatedAt = (try? container.decode(String.self, forKey: .updatedAt)) ?? now
        self.backgroundScale = (try? container.decode(CGFloat.self, forKey: .backgroundScale)) ?? 1.0
        self.backgroundOffset = (try? container.decode([CGFloat].self, forKey: .backgroundOffset)) ?? [0.0, 0.0]
        self.backgroundOpacity = (try? container.decode(CGFloat.self, forKey: .backgroundOpacity)) ?? 1.0
        self.borderWidth = (try? container.decode(CGFloat.self, forKey: .borderWidth)) ?? 0.0
        self.borderColor = (try? container.decode(KalgramBadgeColor.self, forKey: .borderColor)) ?? KalgramBadgeColor(hex: "#FFFFFF")
    }
}

// The whole .ggbadge file: the document and the pictures it uses
public struct KalgramBadgeFile: Codable {
    public var format: String
    public var version: Int
    public var document: KalgramBadgeDocument
    // Pictures by asset id, base64 in the file
    public var assets: [String: Data]

    public init(document: KalgramBadgeDocument, assets: [String: Data]) {
        self.format = "ggbadge"
        self.version = 1
        self.document = document
        self.assets = assets
    }

    enum CodingKeys: String, CodingKey {
        case format, version, document, assets
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.format = (try? container.decode(String.self, forKey: .format)) ?? "ggbadge"
        self.version = (try? container.decode(Int.self, forKey: .version)) ?? 1
        self.document = try container.decode(KalgramBadgeDocument.self, forKey: .document)
        self.assets = (try? container.decode([String: Data].self, forKey: .assets)) ?? [:]
    }

    public static func decode(_ data: Data) -> KalgramBadgeFile? {
        return try? JSONDecoder().decode(KalgramBadgeFile.self, from: data)
    }

    public func encoded() -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try? encoder.encode(self)
    }
}

public enum KalgramBadgeRenderer {
    // The size of Swiftgram's badges, which fits inside the island of every model
    public static let size = CGSize(width: 93.0, height: 22.0)

    private static func font(_ text: KalgramBadgeText) -> UIFont {
        let weight: UIFont.Weight
        switch text.weight {
        case "ultraLight":
            weight = .ultraLight
        case "thin":
            weight = .thin
        case "light":
            weight = .light
        case "regular":
            weight = .regular
        case "medium":
            weight = .medium
        case "semibold":
            weight = .semibold
        case "heavy":
            weight = .heavy
        case "black":
            weight = .black
        default:
            weight = .bold
        }
        let font = UIFont.systemFont(ofSize: max(1.0, text.fontSize), weight: weight)
        var descriptor = font.fontDescriptor
        let design: UIFontDescriptor.SystemDesign?
        switch text.design {
        case "serif":
            design = .serif
        case "monospaced":
            design = .monospaced
        default:
            design = text.isRounded ? .rounded : nil
        }
        if let design, let designed = descriptor.withDesign(design) {
            descriptor = designed
        }
        if text.isItalic, let italic = descriptor.withSymbolicTraits(descriptor.symbolicTraits.union(.traitItalic)) {
            descriptor = italic
        }
        return UIFont(descriptor: descriptor, size: font.pointSize)
    }

    // Decoded pictures by their bytes, so dragging a slider does not decode a photo every frame
    private static let imageCache: NSCache<NSData, UIImage> = {
        let cache = NSCache<NSData, UIImage>()
        cache.countLimit = 8
        return cache
    }()

    private static func cachedImage(_ file: KalgramBadgeFile, _ ref: KalgramBadgeImageRef) -> UIImage? {
        guard let data = file.assets[ref.assetId] else {
            return nil
        }
        let key = data as NSData
        if let image = imageCache.object(forKey: key) {
            return image
        }
        guard let image = UIImage(data: data) else {
            return nil
        }
        imageCache.setObject(image, forKey: key)
        return image
    }

    // Draws the badge at 3x, the scale the window reads it at
    public static func render(_ file: KalgramBadgeFile) -> UIImage {
        let document = file.document
        let size = KalgramBadgeRenderer.size
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3.0
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let context = ctx.cgContext
            let bounds = CGRect(origin: .zero, size: size)
            let radius = min(document.cornerRadius, size.height / 2.0)
            UIBezierPath(roundedRect: bounds, cornerRadius: radius).addClip()

            switch document.background {
            case .transparent:
                break
            case let .color(color):
                context.setFillColor(color.uiColor.cgColor)
                context.fill(bounds)
            case let .image(ref):
                if let image = cachedImage(file, ref) {
                    context.saveGState()
                    context.setAlpha(max(0.0, min(1.0, document.backgroundOpacity)))
                    let scale = max(0.05, document.backgroundScale)
                    let offsetX = document.backgroundOffset.count > 0 ? document.backgroundOffset[0] : 0.0
                    let offsetY = document.backgroundOffset.count > 1 ? document.backgroundOffset[1] : 0.0
                    let rect = CGRect(x: offsetX + size.width * (1.0 - scale) / 2.0, y: offsetY + size.height * (1.0 - scale) / 2.0, width: size.width * scale, height: size.height * scale)
                    drawAspectFill(image, in: rect)
                    context.restoreGState()
                }
            case let .gradient(gradient):
                let colors = (gradient.colors.isEmpty ? [KalgramBadgeColor(hex: "#000000")] : gradient.colors).map { $0.uiColor.cgColor }
                if let cgGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: (colors.count == 1 ? colors + colors : colors) as CFArray, locations: nil) {
                    let angle = gradient.angle * .pi / 180.0
                    let half = CGPoint(x: cos(angle) * size.width / 2.0, y: sin(angle) * size.height / 2.0)
                    let center = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
                    context.drawLinearGradient(cgGradient, start: CGPoint(x: center.x - half.x, y: center.y - half.y), end: CGPoint(x: center.x + half.x, y: center.y + half.y), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
                }
            }

            for layer in document.layers where !layer.isHidden {
                context.saveGState()
                context.setAlpha(max(0.0, min(1.0, layer.opacity)))
                let offsetX = layer.offset.count > 0 ? layer.offset[0] : 0.0
                let offsetY = layer.offset.count > 1 ? layer.offset[1] : 0.0
                context.translateBy(x: size.width / 2.0 + offsetX, y: size.height / 2.0 + offsetY)
                context.rotate(by: layer.rotation * .pi / 180.0)
                context.scaleBy(x: layer.scale, y: layer.scale)
                switch layer.content {
                case let .text(text):
                    var attributes: [NSAttributedString.Key: Any] = [
                        .font: font(text),
                        .foregroundColor: text.color.uiColor,
                        .kern: text.tracking
                    ]
                    if text.strokeWidth > 0.0 {
                        // Negative: stroke and fill
                        attributes[.strokeWidth] = -text.strokeWidth * 10.0
                        attributes[.strokeColor] = text.strokeColor.uiColor
                    }
                    if text.shadowRadius > 0.0 {
                        context.setShadow(offset: .zero, blur: text.shadowRadius, color: text.shadowColor.uiColor.cgColor)
                    }
                    let string = NSAttributedString(string: text.string, attributes: attributes)
                    let textSize = string.boundingRect(with: CGSize(width: 1000.0, height: 1000.0), options: .usesLineFragmentOrigin, context: nil).size
                    string.draw(at: CGPoint(x: -textSize.width / 2.0, y: -textSize.height / 2.0))
                case let .image(ref):
                    if let image = cachedImage(file, ref) {
                        // Fits the badge's height, as large as the badge at scale 1
                        let height = size.height
                        let width = height * image.size.width / max(1.0, image.size.height)
                        image.draw(in: CGRect(x: -width / 2.0, y: -height / 2.0, width: width, height: height))
                    }
                }
                context.restoreGState()
            }

            if document.borderWidth > 0.0 {
                let width = min(document.borderWidth, size.height / 2.0)
                let path = UIBezierPath(roundedRect: bounds.insetBy(dx: width / 2.0, dy: width / 2.0), cornerRadius: max(0.0, radius - width / 2.0))
                path.lineWidth = width
                document.borderColor.uiColor.setStroke()
                path.stroke()
            }
        }
    }

    private static func drawAspectFill(_ image: UIImage, in rect: CGRect) {
        let scale = max(rect.width / max(1.0, image.size.width), rect.height / max(1.0, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        image.draw(in: CGRect(x: rect.midX - size.width / 2.0, y: rect.midY - size.height / 2.0, width: size.width, height: size.height))
    }
}
