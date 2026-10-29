import Foundation
import UIKit
import ImageIO
import Display
import AppBundle
import AccountContext

// kalgram: the badges to pick from, and the one in use.
//
// Built-in badges are Swiftgram's pictures plus a generated "kalgram" one. Badges
// the user makes or imports are .ggbadge files in Documents/kalgram-badges. The
// picked badge is rendered to Documents/kalgram-badge.png, which the window loads
// at launch (WindowContent).

public struct KalgramBadgeItem: Identifiable, Equatable {
    public enum Source: Equatable {
        case asset(String)
        case generated(KalgramBadgeDocument)
        case custom(KalgramBadgeDocument)
    }

    public let id: String
    public let name: String
    public let source: Source

    public var isCustom: Bool {
        if case .custom = self.source {
            return true
        }
        return false
    }
}

public final class KalgramBadgeStore {
    public static let shared = KalgramBadgeStore()

    private static let selectedKey = "kalgram.badge.selected"
    private static let disabledKey = "kalgram.badge.disabled"

    private var directory: URL? {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let url = documents.appendingPathComponent("kalgram-badges", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private var activeImageURL: URL? {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(kalgramBadgeFileName)
    }

    public var isEnabled: Bool {
        get {
            return !UserDefaults.standard.bool(forKey: KalgramBadgeStore.disabledKey)
        }
        set {
            UserDefaults.standard.set(!newValue, forKey: KalgramBadgeStore.disabledKey)
        }
    }

    public var selectedId: String {
        return UserDefaults.standard.string(forKey: KalgramBadgeStore.selectedKey) ?? "kalgram"
    }

    private static let kalgramDocument = KalgramBadgeDocument(
        id: "kalgram",
        name: "kalgram",
        background: .color(KalgramBadgeColor(hex: "#2AABEE")),
        cornerRadius: 11.0,
        layers: [KalgramBadgeLayer(content: .text(KalgramBadgeText(string: "kalgram", fontSize: 13.0)))]
    )

    private static let swiftgramAssets: [(String, String)] = [
        ("Swiftgram", "Components/AppBadge"),
        ("Sky", "SkyAppBadge"),
        ("Night", "NightAppBadge"),
        ("Titanium", "TitaniumAppBadge"),
        ("Pro", "ProAppBadge"),
        ("Day", "DayAppBadge"),
        ("Sparkling", "SparklingAppBadge")
    ]

    public func items() -> [KalgramBadgeItem] {
        var items: [KalgramBadgeItem] = [KalgramBadgeItem(id: "kalgram", name: "kalgram", source: .generated(KalgramBadgeStore.kalgramDocument))]
        for (name, asset) in KalgramBadgeStore.swiftgramAssets {
            items.append(KalgramBadgeItem(id: "asset:\(asset)", name: name, source: .asset(asset)))
        }
        for file in self.customFiles() {
            items.append(KalgramBadgeItem(id: file.document.id, name: file.document.name, source: .custom(file.document)))
        }
        return items
    }

    private func fileURL(id: String) -> URL? {
        let safeId = id.map { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "." ? $0 : "_" }
        return self.directory?.appendingPathComponent(String(safeId) + ".ggbadge")
    }

    private func customFiles() -> [KalgramBadgeFile] {
        guard let directory = self.directory, let urls = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return []
        }
        return urls.filter { $0.pathExtension == "ggbadge" }
            .compactMap { url in (try? Data(contentsOf: url)).flatMap(KalgramBadgeFile.decode) }
            .sorted { $0.document.createdAt < $1.document.createdAt }
    }

    public func file(id: String) -> KalgramBadgeFile? {
        if id == "kalgram" {
            return KalgramBadgeFile(document: KalgramBadgeStore.kalgramDocument, assets: [:])
        }
        return self.fileURL(id: id).flatMap { try? Data(contentsOf: $0) }.flatMap(KalgramBadgeFile.decode)
    }

    public func image(for item: KalgramBadgeItem) -> UIImage? {
        switch item.source {
        case let .asset(name):
            return UIImage(bundleImageName: name)
        case .generated, .custom:
            return self.file(id: item.id).map(KalgramBadgeRenderer.render)
        }
    }

    public func save(_ file: KalgramBadgeFile) {
        var file = file
        file.document.updatedAt = ISO8601DateFormatter().string(from: Date())
        if let url = self.fileURL(id: file.document.id), let data = file.encoded() {
            try? data.write(to: url)
        }
    }

    public func delete(id: String) {
        if let url = self.fileURL(id: id) {
            try? FileManager.default.removeItem(at: url)
        }
        if self.selectedId == id {
            UserDefaults.standard.removeObject(forKey: KalgramBadgeStore.selectedKey)
        }
    }

    // Makes the badge the one in use and shows it right away
    public func select(_ item: KalgramBadgeItem, context: AccountContext) {
        UserDefaults.standard.set(item.id, forKey: KalgramBadgeStore.selectedKey)
        self.apply(context: context)
    }

    public func setEnabled(_ enabled: Bool, context: AccountContext) {
        self.isEnabled = enabled
        self.apply(context: context)
    }

    public func apply(context: AccountContext) {
        self.apply(window: context.sharedContext.mainWindow)
    }

    public func apply(window: Window1?) {
        let item = self.items().first(where: { $0.id == self.selectedId }) ?? self.items()[0]
        let image = self.image(for: item)
        if let image, let data = image.pngData(), let url = self.activeImageURL {
            try? data.write(to: url)
        }
        window?.kalgramUpdateBadge(image: image, enabled: self.isEnabled)
    }

    // A .ggbadge file, or any picture (it becomes the badge's background)
    public func importBadge(data: Data, name: String) -> KalgramBadgeFile? {
        // A badge file comes from anywhere, so nothing in it may be large enough to hurt at launch
        guard data.count <= KalgramBadgeStore.maxImportSize else {
            return nil
        }
        if var file = KalgramBadgeFile.decode(data).map(KalgramBadgeStore.sanitized) {
            // A copy under its own id, so importing twice does not overwrite
            file.document.id = "custom.\(UUID().uuidString)"
            self.save(file)
            return file
        }
        if let png = KalgramBadgeStore.thumbnailPNG(data) {
            let assetId = UUID().uuidString
            let document = KalgramBadgeDocument(name: name, background: .image(KalgramBadgeImageRef(assetId: assetId)), layers: [])
            let file = KalgramBadgeFile(document: document, assets: [assetId: png])
            self.save(file)
            return file
        }
        return nil
    }
}

extension KalgramBadgeStore {
    static let maxImportSize = 30 * 1024 * 1024
    // A phone photo at full size, and no larger
    static let maxAssetSide: CGFloat = 4096.0

    // The picture as it is when it fits maxAssetSide, else shrunk to it without decoding it at full size
    static func thumbnailPNG(_ data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil), CGImageSourceGetCount(source) > 0 else {
            return nil
        }
        if let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any], let width = properties[kCGImagePropertyPixelWidth] as? Int, let height = properties[kCGImagePropertyPixelHeight] as? Int, width > 0, height > 0, CGFloat(max(width, height)) <= maxAssetSide, UIImage(data: data) != nil {
            return data
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxAssetSide
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        let result = UIImage(cgImage: image)
        let alpha = image.alphaInfo
        if alpha == .none || alpha == .noneSkipFirst || alpha == .noneSkipLast {
            return result.jpegData(compressionQuality: 0.92)
        }
        return result.pngData()
    }

    // Counted in scalars: one character can carry any number of combining marks
    private static func capped(_ string: String) -> String {
        var scalars = String.UnicodeScalarView()
        scalars.append(contentsOf: string.unicodeScalars.prefix(128))
        return String(scalars)
    }

    // Shrinks pictures and clamps every number the renderer draws with
    static func sanitized(_ file: KalgramBadgeFile) -> KalgramBadgeFile {
        var file = file
        var assets: [String: Data] = [:]
        for (id, data) in file.assets.prefix(16) {
            if let png = thumbnailPNG(data) {
                assets[id] = png
            }
        }
        file.assets = assets
        file.document.name = KalgramBadgeStore.capped(file.document.name)
        file.document.cornerRadius = max(0.0, min(11.0, file.document.cornerRadius))
        file.document.backgroundScale = max(0.05, min(10.0, file.document.backgroundScale))
        file.document.backgroundOffset = file.document.backgroundOffset.prefix(2).map { max(-200.0, min(200.0, $0)) }
        file.document.borderWidth = max(0.0, min(11.0, file.document.borderWidth))
        if case var .gradient(gradient) = file.document.background {
            gradient.colors = Array(gradient.colors.prefix(8))
            file.document.background = .gradient(gradient)
        }
        file.document.layers = file.document.layers.prefix(16).map { layer in
            var layer = layer
            layer.scale = max(0.05, min(8.0, layer.scale))
            layer.offset = layer.offset.prefix(2).map { max(-200.0, min(200.0, $0)) }
            if case var .text(text) = layer.content {
                text.string = KalgramBadgeStore.capped(text.string)
                text.fontSize = max(1.0, min(40.0, text.fontSize))
                text.strokeWidth = max(0.0, min(10.0, text.strokeWidth))
                text.tracking = max(-10.0, min(20.0, text.tracking))
                text.shadowRadius = max(0.0, min(20.0, text.shadowRadius))
                layer.content = .text(text)
            }
            return layer
        }
        return file
    }
}

// Picks a photo from the library and hands it over downscaled
public final class KalgramImagePicker: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    public static let shared = KalgramImagePicker()

    private var maxSide: CGFloat = 600.0
    private var onPicked: ((UIImage) -> Void)?
    private var onPickedOriginal: ((Data) -> Void)?

    public static func downscaled(_ image: UIImage, maxSide: CGFloat) -> UIImage {
        let scale = min(1.0, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: max(1.0, floor(image.size.width * scale)), height: max(1.0, floor(image.size.height * scale)))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    public static func topViewController() -> UIViewController? {
        let root = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })?.rootViewController
        guard var top = root else {
            return nil
        }
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }

    public func pick(maxSide: CGFloat, completion: @escaping (UIImage) -> Void) {
        self.maxSide = maxSide
        self.onPicked = completion
        self.onPickedOriginal = nil
        self.present()
    }

    // The photo's own file, at its own resolution (shrunk only past KalgramBadgeStore.maxAssetSide)
    public func pickOriginal(completion: @escaping (Data) -> Void) {
        self.onPicked = nil
        self.onPickedOriginal = completion
        self.present()
    }

    private func present() {
        guard let top = KalgramImagePicker.topViewController() else {
            return
        }
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.mediaTypes = ["public.image"]
        picker.delegate = self
        top.present(picker, animated: true)
    }

    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        if let onPickedOriginal = self.onPickedOriginal {
            let fileData = (info[.imageURL] as? URL).flatMap { try? Data(contentsOf: $0) }
            if let fileData, let data = KalgramBadgeStore.thumbnailPNG(fileData) {
                onPickedOriginal(data)
            } else if let image = info[.originalImage] as? UIImage, let data = KalgramImagePicker.downscaled(image, maxSide: KalgramBadgeStore.maxAssetSide).jpegData(compressionQuality: 0.92) {
                onPickedOriginal(data)
            }
        } else if let image = info[.originalImage] as? UIImage {
            self.onPicked?(KalgramImagePicker.downscaled(image, maxSide: self.maxSide))
        }
        self.onPicked = nil
        self.onPickedOriginal = nil
    }

    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
        self.onPicked = nil
        self.onPickedOriginal = nil
    }
}
