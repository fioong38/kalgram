import Foundation
import UIKit

// kalgram: a picture around the Dynamic Island, drawn by the app over its own
// content (iOS does not let an app draw over the system outside of it).
//
// The picture lives in the app's Documents directory; a static image costs
// nothing once it is composited.

public final class KalgramIsland: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    public static let shared = KalgramIsland()

    private static let enabledKey = "kalgram.island.enabled"

    private var window: UIWindow?
    private var imageView: UIImageView?
    private var onPicked: (() -> Void)?

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

    // The island's frame in screen points, nil on devices without one
    private func islandFrame(in hostWindow: UIWindow) -> CGRect? {
        // Every iPhone with a Dynamic Island has a top safe inset of at least 59pt, notched ones less
        guard UIDevice.current.userInterfaceIdiom == .phone, hostWindow.safeAreaInsets.top >= 59.0 else {
            return nil
        }
        let size = CGSize(width: 126.0, height: 37.33)
        return CGRect(x: floor((hostWindow.bounds.width - size.width) / 2.0), y: 11.0, width: size.width, height: size.height)
    }

    // Shows, moves or hides the picture; safe to call at any time on the main thread
    public func update() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                self.update()
            }
            return
        }
        let hostWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow }) ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first?.windows.first
        guard self.isEnabled, let imageURL = self.imageURL, let image = UIImage(contentsOfFile: imageURL.path), let hostWindow, let scene = hostWindow.windowScene, let islandFrame = self.islandFrame(in: hostWindow) else {
            self.window?.isHidden = true
            self.window = nil
            self.imageView = nil
            return
        }
        // Slightly larger than the island, so the picture shows around it
        let frame = islandFrame.insetBy(dx: -6.0, dy: -4.0)

        let window: UIWindow
        if let current = self.window {
            window = current
        } else {
            window = UIWindow(windowScene: scene)
            window.windowLevel = UIWindow.Level.statusBar + 1.0
            window.isUserInteractionEnabled = false
            window.backgroundColor = .clear
            let imageView = UIImageView()
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            window.addSubview(imageView)
            self.imageView = imageView
            self.window = window
        }
        window.frame = frame
        self.imageView?.frame = CGRect(origin: .zero, size: frame.size)
        self.imageView?.layer.cornerRadius = frame.height / 2.0
        self.imageView?.image = image
        window.isHidden = false
    }

    public func pickImage(completion: @escaping () -> Void) {
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
        self.onPicked = completion
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.mediaTypes = ["public.image"]
        picker.delegate = self
        top.present(picker, animated: true)
    }

    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        if let image = info[.originalImage] as? UIImage, let imageURL = self.imageURL {
            // Downscale: the island is ~130pt wide, a 600px picture is plenty
            let maxSide: CGFloat = 600.0
            let scale = min(1.0, maxSide / max(image.size.width, image.size.height))
            let size = CGSize(width: floor(image.size.width * scale), height: floor(image.size.height * scale))
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1.0
            let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
                image.draw(in: CGRect(origin: .zero, size: size))
            }
            try? resized.pngData()?.write(to: imageURL)
            UserDefaults.standard.set(true, forKey: KalgramIsland.enabledKey)
            self.update()
        }
        self.onPicked?()
        self.onPicked = nil
    }

    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
        self.onPicked = nil
    }
}
