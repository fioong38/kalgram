import Foundation
import UIKit

// kalgram: a picture in the place of the Dynamic Island.
//
// iOS lets an app draw only inside its own windows, so the picture is drawn by
// the app exactly where the island is. Sized to the island, the island hides it
// on screen; a screenshot has no island, so the picture shows there instead of
// the black pill. The size, position and corners are adjustable because the
// island differs between iPhone models.
//
// The picture lives in the app's Documents directory; a static image costs
// nothing once it is composited.

public final class KalgramIsland: NSObject {
    public static let shared = KalgramIsland()

    private static let enabledKey = "kalgram.island.enabled"
    private static let widthKey = "kalgram.island.width"
    private static let heightKey = "kalgram.island.height"
    private static let topKey = "kalgram.island.top"
    private static let offsetXKey = "kalgram.island.offsetX"
    private static let cornerKey = "kalgram.island.corner"
    private static let fitKey = "kalgram.island.fit"

    // Slider ranges, in points
    private static let widthRange: ClosedRange<CGFloat> = 60.0 ... 200.0
    private static let heightRange: ClosedRange<CGFloat> = 20.0 ... 60.0
    private static let topRange: ClosedRange<CGFloat> = 0.0 ... 30.0
    private static let offsetXRange: ClosedRange<CGFloat> = -30.0 ... 30.0

    private var window: UIWindow?
    private var imageView: UIImageView?

    private var imageURL: URL? {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("kalgram-island.png")
    }

    public var isEnabled: Bool {
        get {
            return UserDefaults.standard.bool(forKey: KalgramIsland.enabledKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: KalgramIsland.enabledKey)
            self.update()
        }
    }

    public var hasImage: Bool {
        guard let imageURL = self.imageURL else {
            return false
        }
        return FileManager.default.fileExists(atPath: imageURL.path)
    }

    // The whole picture is shown instead of filling the shape
    public var fitsWhole: Bool {
        get {
            return UserDefaults.standard.bool(forKey: KalgramIsland.fitKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: KalgramIsland.fitKey)
            self.update()
        }
    }

    private func hostWindow() -> UIWindow? {
        let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap { $0.windows }
        return windows.first(where: { $0.isKeyWindow && $0 !== self.window }) ?? windows.first(where: { $0 !== self.window })
    }

    // Every iPhone with a Dynamic Island has a top safe inset of at least 59pt, notched ones less
    public var deviceHasIsland: Bool {
        guard UIDevice.current.userInterfaceIdiom == .phone, let hostWindow = self.hostWindow() else {
            return false
        }
        return hostWindow.safeAreaInsets.top >= 59.0
    }

    // The island of this iPhone: 126x37.33 at 11.33pt on the 14 and 15 Pro, a little
    // lower on the models with a 62pt inset and more
    private func defaultFrame() -> (width: CGFloat, height: CGFloat, top: CGFloat) {
        let topInset = self.hostWindow()?.safeAreaInsets.top ?? 59.0
        return (126.0, 37.33, topInset >= 62.0 ? 14.0 : 11.33)
    }

    private func value(_ key: String, _ defaultValue: CGFloat) -> CGFloat {
        if let value = UserDefaults.standard.object(forKey: key) as? Double {
            return CGFloat(value)
        }
        return defaultValue
    }

    private var width: CGFloat {
        return self.value(KalgramIsland.widthKey, self.defaultFrame().width)
    }
    private var height: CGFloat {
        return self.value(KalgramIsland.heightKey, self.defaultFrame().height)
    }
    private var top: CGFloat {
        return self.value(KalgramIsland.topKey, self.defaultFrame().top)
    }
    private var offsetX: CGFloat {
        return self.value(KalgramIsland.offsetXKey, 0.0)
    }
    // 100 is a capsule, 0 a rectangle
    private var cornerPercent: CGFloat {
        return self.value(KalgramIsland.cornerKey, 100.0)
    }

    private static func percent(_ value: CGFloat, in range: ClosedRange<CGFloat>) -> Int32 {
        return Int32(max(0.0, min(100.0, (value - range.lowerBound) / (range.upperBound - range.lowerBound) * 100.0)).rounded())
    }

    private static func points(_ percent: Int32, in range: ClosedRange<CGFloat>) -> CGFloat {
        let value = range.lowerBound + CGFloat(percent) / 100.0 * (range.upperBound - range.lowerBound)
        return (value * 2.0).rounded() / 2.0
    }

    // Slider positions (0...100) for the settings screen
    public var widthPercent: Int32 {
        get { return KalgramIsland.percent(self.width, in: KalgramIsland.widthRange) }
        set { self.set(KalgramIsland.points(newValue, in: KalgramIsland.widthRange), forKey: KalgramIsland.widthKey) }
    }
    public var heightPercent: Int32 {
        get { return KalgramIsland.percent(self.height, in: KalgramIsland.heightRange) }
        set { self.set(KalgramIsland.points(newValue, in: KalgramIsland.heightRange), forKey: KalgramIsland.heightKey) }
    }
    public var topPercent: Int32 {
        get { return KalgramIsland.percent(self.top, in: KalgramIsland.topRange) }
        set { self.set(KalgramIsland.points(newValue, in: KalgramIsland.topRange), forKey: KalgramIsland.topKey) }
    }
    public var offsetXPercent: Int32 {
        get { return KalgramIsland.percent(self.offsetX, in: KalgramIsland.offsetXRange) }
        set { self.set(KalgramIsland.points(newValue, in: KalgramIsland.offsetXRange), forKey: KalgramIsland.offsetXKey) }
    }
    public var cornerPercentValue: Int32 {
        get { return Int32(self.cornerPercent.rounded()) }
        set { self.set(CGFloat(newValue), forKey: KalgramIsland.cornerKey) }
    }

    public var frameDescription: String {
        return "\(Int(self.width.rounded()))×\(Int(self.height.rounded())) pt, сверху \(Int(self.top.rounded())) pt"
    }

    private func set(_ value: CGFloat, forKey key: String) {
        UserDefaults.standard.set(Double(value), forKey: key)
        self.update()
    }

    // Back to the island of this iPhone
    public func resetToDevice() {
        for key in [KalgramIsland.widthKey, KalgramIsland.heightKey, KalgramIsland.topKey, KalgramIsland.offsetXKey, KalgramIsland.cornerKey] {
            UserDefaults.standard.removeObject(forKey: key)
        }
        self.update()
    }

    // Shows, moves or hides the picture; safe to call at any time on the main thread
    public func update() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                self.update()
            }
            return
        }
        guard self.isEnabled, self.deviceHasIsland, let imageURL = self.imageURL, let image = UIImage(contentsOfFile: imageURL.path), let hostWindow = self.hostWindow(), let scene = hostWindow.windowScene else {
            self.window?.isHidden = true
            self.window = nil
            self.imageView = nil
            return
        }
        let size = CGSize(width: self.width, height: self.height)
        let frame = CGRect(x: floor((hostWindow.bounds.width - size.width) / 2.0) + self.offsetX, y: self.top, width: size.width, height: size.height)

        let window: UIWindow
        if let current = self.window {
            window = current
        } else {
            window = UIWindow(windowScene: scene)
            window.windowLevel = UIWindow.Level.statusBar + 1.0
            window.isUserInteractionEnabled = false
            window.backgroundColor = .clear
            let imageView = UIImageView()
            imageView.clipsToBounds = true
            window.addSubview(imageView)
            self.imageView = imageView
            self.window = window
        }
        window.frame = frame
        self.imageView?.frame = CGRect(origin: .zero, size: frame.size)
        self.imageView?.contentMode = self.fitsWhole ? .scaleAspectFit : .scaleAspectFill
        self.imageView?.layer.cornerRadius = min(frame.width, frame.height) / 2.0 * self.cornerPercent / 100.0
        if #available(iOS 13.0, *) {
            self.imageView?.layer.cornerCurve = .continuous
        }
        self.imageView?.image = image
        window.isHidden = false
    }

    public func pickImage(completion: @escaping () -> Void) {
        KalgramImagePicker.shared.pick(maxSide: 600.0, completion: { [weak self] image in
            guard let self, let imageURL = self.imageURL else {
                return
            }
            try? image.pngData()?.write(to: imageURL)
            UserDefaults.standard.set(true, forKey: KalgramIsland.enabledKey)
            self.update()
            completion()
        })
    }
}

// Picks a photo from the library and hands it over downscaled
public final class KalgramImagePicker: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    public static let shared = KalgramImagePicker()

    private var maxSide: CGFloat = 600.0
    private var onPicked: ((UIImage) -> Void)?

    public func pick(maxSide: CGFloat, completion: @escaping (UIImage) -> Void) {
        let presenter = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })?.rootViewController
        guard var top = presenter else {
            return
        }
        while let presented = top.presentedViewController {
            top = presented
        }
        self.maxSide = maxSide
        self.onPicked = completion
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.mediaTypes = ["public.image"]
        picker.delegate = self
        top.present(picker, animated: true)
    }

    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        if let image = info[.originalImage] as? UIImage {
            let scale = min(1.0, self.maxSide / max(image.size.width, image.size.height))
            let size = CGSize(width: max(1.0, floor(image.size.width * scale)), height: max(1.0, floor(image.size.height * scale)))
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1.0
            let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
                image.draw(in: CGRect(origin: .zero, size: size))
            }
            self.onPicked?(resized)
        }
        self.onPicked = nil
    }

    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
        self.onPicked = nil
    }
}
