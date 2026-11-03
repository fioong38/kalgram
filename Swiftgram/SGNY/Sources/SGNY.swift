import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SGSimpleSettings


// kalgram: the falling effect, drawn at 30 frames per second.
//
// It used to be a CAEmitterLayer, which has no frame rate of its own: an open chat kept the screen at 120 Hz
// all the time. Each particle is now a layer of its own, moved by Core Animation (no work per frame in the
// app) with an animation that asks for at most 30 frames. The particles follow the emitter's motion: born
// in the same disc above the screen, accelerating down (or up) and sideways, spinning, gone after the same
// lifetime.
class WallpaperNYNode: ASDisplayNode {
    // One kind of particle, an emitter cell before
    private struct Cell {
        let contents: CGImage
        // points on screen for one pixel of `contents`, and its random spread
        let scale: CGFloat
        let scaleRange: CGFloat
        // radians per second, and its random spread
        let spin: CGFloat
        let spinRange: CGFloat
        let opacity: Float
        // points per second squared
        let xAcceleration: CGFloat
    }

    private static let frameRateRange = CAFrameRateRange(minimum: 20.0, maximum: 30.0, preferred: 30.0)

    // kalgram: bubbles rise from the bottom edge instead of falling from the top
    private var rising = false
    // kalgram: an NYStyle raw value, the chat's own or kalgram Pro's
    private let effectStyle: String

    private var isConfigured = false
    private var cells: [Cell] = []
    private var yAcceleration: CGFloat = 0.0
    private var lifetime: Double = 25.0
    // particles per second
    private var birthRate: Double = 0.0
    private var effectSize = CGSize()

    private var spawnTimer: Foundation.Timer?
    private var isOnScreen = false

    init(style: String) {
        self.effectStyle = style
        super.init()
    }

    deinit {
        self.spawnTimer?.invalidate()
    }

    override func didLoad() {
        super.didLoad()
        self.layer.masksToBounds = true
    }

    override func didEnterHierarchy() {
        super.didEnterHierarchy()
        self.isOnScreen = true
        self.updateSpawning()
    }

    override func didExitHierarchy() {
        super.didExitHierarchy()
        self.isOnScreen = false
        self.updateSpawning()
    }

    func updateLayout(size: CGSize) {
        self.effectSize = size
        if !self.isConfigured {
            self.isConfigured = true
            self.configure()
        }
        self.updateSpawning()
    }

    private func configure() {
        // kalgram: direction, opacity, speed, and for pictures size and spin, from kalgram Pro
        let direction = KalgramEffectSettings.direction
        self.rising = direction == .up
        let opacity = CGFloat(KalgramEffectSettings.percent(KalgramEffectSettings.opacityKey, default: 100.0) / 100.0)
        let speed = KalgramEffectSettings.percent(KalgramEffectSettings.speedKey, default: 50.0)
        // falls (or rises) the height of the screen within its lifetime
        let yAcceleration = 3.2 * (0.25 + speed / 50.0 * 0.75)
        // ~size points on screen whatever a picture's pixels, 26 by default
        let pictureSize = 8.0 + KalgramEffectSettings.percent(KalgramEffectSettings.sizeKey, default: 45.0) / 100.0 * 40.0
        let pictureSizeSpread = KalgramEffectSettings.percent(KalgramEffectSettings.sizeSpreadKey, default: 35.0) / 100.0
        // 50 does not spin; the spin range is 40 degrees by default
        let pictureSpin = (KalgramEffectSettings.percent(KalgramEffectSettings.spinKey, default: 50.0) - 50.0) / 50.0 * (Double.pi / 2.0)
        let pictureSpinRange = KalgramEffectSettings.percent(KalgramEffectSettings.spinSpreadKey, default: 22.0) / 100.0 * Double.pi

        let style = self.effectStyle
        var pictures: [UIImage] = []
        if style == SGSimpleSettings.NYStyle.custom.rawValue {
            // kalgram: the user's pictures, each one a cell of its own
            pictures = KalgramEffectSettings.pictureURLs().compactMap { UIImage(contentsOfFile: $0.path) }
        }

        // The cells of the style for one horizontal drift. Sway makes two sets, drifting left and right.
        func makeCells(drift: CGFloat) -> [Cell] {
            var result: [Cell] = []
            switch style {
                case SGSimpleSettings.NYStyle.lightning.rawValue:
                    if let image = UIImage(bundleImageName: "SwiftgramContextMenu"), let contents = paintImage(image, to: UIColor.white.cgColor).cgImage {
                        result.append(Cell(contents: contents, scale: 0.15, scaleRange: 0.25, spin: -28.6 * (.pi / 180.0), spinRange: 57.2 * (.pi / 180.0), opacity: Float(0.58 * opacity), xAcceleration: drift))
                    }
                case SGSimpleSettings.NYStyle.custom.rawValue:
                    for picture in pictures {
                        guard let contents = picture.cgImage else {
                            continue
                        }
                        let scale = CGFloat(pictureSize) / max(1.0, max(picture.size.width, picture.size.height))
                        // a picture keeps its colors
                        result.append(Cell(contents: contents, scale: scale, scaleRange: scale * CGFloat(pictureSizeSpread), spin: CGFloat(pictureSpin), spinRange: CGFloat(pictureSpinRange), opacity: Float(opacity), xAcceleration: drift))
                    }
                default:
                    if let contents = UIImage(bundleImageName: "SGSnowflake")?.cgImage {
                        result.append(Cell(contents: contents, scale: 0.04, scaleRange: 0.15, spin: -28.6 * (.pi / 180.0), spinRange: 57.2 * (.pi / 180.0), opacity: Float(0.58 * opacity), xAcceleration: drift))
                    }
            }
            return result
        }

        // Sway is a wind that changes side: one set of cells drifts left, another right
        let drifts: [CGFloat] = direction == .sway ? [1.0, -1.0] : [1.0]
        var cells: [Cell] = []
        for drift in drifts {
            cells += makeCells(drift: drift)
        }
        self.cells = cells
        self.yAcceleration = CGFloat(self.rising ? -yAcceleration : yAcceleration)
        self.lifetime = min(60.0, max(10.0, 25.0 * 3.2 / yAcceleration))

        // kalgram: density from kalgram Pro (0...100, 30 by default: ~75 particles on screen instead of ~550,
        // the main cost of the effect)
        let density = KalgramEffectSettings.percent(KalgramEffectSettings.densityKey, default: 30.0)
        var birthRate = max(0.5, density / 10.0)
        // kalgram: no snow at all in Low Power Mode
        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            birthRate = 0.0
        } else if UIAccessibility.isReduceMotionEnabled {
            birthRate = birthRate / 3.0
        }
        self.birthRate = birthRate
    }

    // New particles only while the chat is on screen; the ones already falling finish on their own
    private func updateSpawning() {
        let shouldSpawn = self.isOnScreen && self.isConfigured && self.birthRate > 0.0 && !self.cells.isEmpty && self.effectSize.width > 0.0 && self.effectSize.height > 0.0
        if shouldSpawn {
            if self.spawnTimer == nil {
                let timer = Foundation.Timer(timeInterval: 1.0 / self.birthRate, repeats: true, block: { [weak self] _ in
                    self?.spawnParticle()
                })
                timer.tolerance = 0.2 / self.birthRate
                RunLoop.main.add(timer, forMode: .common)
                self.spawnTimer = timer
            }
        } else if let spawnTimer = self.spawnTimer {
            self.spawnTimer = nil
            spawnTimer.invalidate()
        }
    }

    private func spawnParticle() {
        guard let cell = self.cells.randomElement() else {
            return
        }
        let size = self.effectSize

        // Born somewhere in the disc the emitter covered (its circle has a radius of emitterSize.width):
        // 1.5 widths around the top left corner, or below the bottom edge for bubbles
        let center = CGPoint(x: 0.0, y: self.rising ? size.height * 1.125 : -size.height / 8.0)
        let radius = size.width * 1.5 * sqrt(CGFloat.random(in: 0.0 ... 1.0))
        let angle = CGFloat.random(in: 0.0 ..< 2.0 * .pi)
        let start = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
        let duration = self.lifetime
        let travel = CGFloat(0.5 * duration * duration)
        let end = CGPoint(x: start.x + cell.xAcceleration * travel, y: start.y + self.yAcceleration * travel)

        let scale = max(0.0, cell.scale + CGFloat.random(in: -cell.scaleRange ... cell.scaleRange))
        let particleSize = CGSize(width: CGFloat(cell.contents.width) * scale, height: CGFloat(cell.contents.height) * scale)
        if particleSize.width < 0.5 || particleSize.height < 0.5 {
            return
        }
        let spin = cell.spin + CGFloat.random(in: -cell.spinRange ... cell.spinRange)

        let particle = CALayer()
        particle.contents = cell.contents
        particle.bounds = CGRect(origin: CGPoint(), size: particleSize)
        particle.position = end
        particle.opacity = cell.opacity

        // Accelerating from rest: the distance grows with the square of the time, which this curve is exactly
        let position = CABasicAnimation(keyPath: "position")
        position.fromValue = NSValue(cgPoint: start)
        position.toValue = NSValue(cgPoint: end)
        position.timingFunction = CAMediaTimingFunction(controlPoints: 1.0 / 3.0, 0.0, 2.0 / 3.0, 1.0 / 3.0)

        let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.fromValue = 0.0 as NSNumber
        rotation.toValue = Double(spin) * duration as NSNumber
        rotation.timingFunction = CAMediaTimingFunction(name: .linear)

        let group = CAAnimationGroup()
        group.animations = [position, rotation]
        group.duration = duration
        group.preferredFrameRateRange = WallpaperNYNode.frameRateRange

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        CATransaction.setCompletionBlock({ [weak particle] in
            particle?.removeFromSuperlayer()
        })
        self.layer.addSublayer(particle)
        particle.add(group, forKey: "fall")
        CATransaction.commit()
    }
}


func paintImage(_ image: UIImage, to: CGColor) -> UIImage {
    let rect = CGRect(origin: .zero, size: image.size)

    UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
    guard let ctx = UIGraphicsGetCurrentContext() else { return image }

    // Flip context
    ctx.translateBy(x: 0, y: image.size.height)
    ctx.scaleBy(x: 1, y: -1)

    // Draw alpha mask
    ctx.setBlendMode(.normal)
    ctx.clip(to: rect, mask: image.cgImage!)

    // Fill with white
    ctx.setFillColor(to)
    ctx.fill(rect)

    let result = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()

    return result ?? image
}
