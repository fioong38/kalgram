import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SGSimpleSettings


class WallpaperNYNode: ASDisplayNode {
    private var emitterLayer: CAEmitterLayer?
    // kalgram: bubbles rise from the bottom edge instead of falling from the top
    private var rising = false
    // kalgram: an NYStyle raw value, the chat's own or kalgram Pro's
    private let style: String

    init(style: String) {
        self.style = style
        super.init()
    }

    func updateLayout(size: CGSize) {
        if self.emitterLayer == nil {
            let particlesLayer = CAEmitterLayer()
            self.emitterLayer = particlesLayer

            self.layer.addSublayer(particlesLayer)
            self.layer.masksToBounds = true

            particlesLayer.backgroundColor = UIColor.clear.cgColor
            particlesLayer.emitterShape = .circle
            particlesLayer.emitterMode = .surface
            particlesLayer.renderMode = .oldestLast

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

            let style = self.style
            var pictures: [UIImage] = []
            if style == SGSimpleSettings.NYStyle.custom.rawValue {
                // kalgram: the user's pictures, each one a cell of its own
                pictures = KalgramEffectSettings.pictureURLs().compactMap { UIImage(contentsOfFile: $0.path) }
            }

            // The cells of the style for one horizontal drift. Sway makes two sets, drifting left and right.
            func makeCells(drift: CGFloat) -> [CAEmitterCell] {
                var result: [CAEmitterCell] = []
                switch style {
                    case SGSimpleSettings.NYStyle.lightning.rawValue:
                        let cell = CAEmitterCell()
                        // cell1.contents = generateTintedImage(image: UIImage(bundleImageName: "SwiftgramContextMenu"), color: .white)
                        if let image = UIImage(bundleImageName: "SwiftgramContextMenu") {
                            cell.contents = paintImage(image, to: UIColor.white.cgColor).cgImage
                        }
                        cell.name = "lightning"
                        cell.scale = 0.15
                        cell.scaleRange = 0.25
                        cell.spin = -28.6 * (.pi / 180.0)
                        cell.spinRange = 57.2 * (.pi / 180.0)
                        cell.color = UIColor.white.withAlphaComponent(0.58 * opacity).cgColor
                        result.append(cell)
                    case SGSimpleSettings.NYStyle.custom.rawValue:
                        for picture in pictures {
                            guard let contents = picture.cgImage else {
                                continue
                            }
                            let cell = CAEmitterCell()
                            cell.contents = contents
                            cell.name = "custom"
                            cell.scale = CGFloat(pictureSize) / max(1.0, max(picture.size.width, picture.size.height))
                            cell.scaleRange = cell.scale * CGFloat(pictureSizeSpread)
                            cell.spin = CGFloat(pictureSpin)
                            cell.spinRange = CGFloat(pictureSpinRange)
                            // a picture keeps its colors
                            cell.color = UIColor.white.withAlphaComponent(opacity).cgColor
                            result.append(cell)
                        }
                    default:
                        let cell = CAEmitterCell()
                        cell.contents = UIImage(bundleImageName: "SGSnowflake")?.cgImage
                        cell.name = "snow"
                        cell.scale = 0.04
                        cell.scaleRange = 0.15
                        cell.spin = -28.6 * (.pi / 180.0)
                        cell.spinRange = 57.2 * (.pi / 180.0)
                        cell.color = UIColor.white.withAlphaComponent(0.58 * opacity).cgColor
                        result.append(cell)
                }
                for cell in result {
                    cell.velocity = 1.0
                    cell.velocityRange = -1.5
                    cell.xAcceleration = drift
                    cell.yAcceleration = CGFloat(self.rising ? -yAcceleration : yAcceleration)
                    cell.lifetime = Float(min(60.0, max(10.0, 25.0 * 3.2 / yAcceleration)))
                    cell.emissionRange = .pi
                }
                return result
            }

            // Sway is a wind that changes side: one set of cells drifts left, another right
            let drifts: [CGFloat] = direction == .sway ? [1.0, -1.0] : [1.0]
            var cells: [CAEmitterCell] = []
            for drift in drifts {
                cells += makeCells(drift: drift)
            }

            // kalgram: density from kalgram Pro (0...100, 30 by default: ~75 particles on screen instead of ~550,
            // the main cost of the effect). It is split between the cells, so the total stays the same.
            let density = KalgramEffectSettings.percent(KalgramEffectSettings.densityKey, default: 30.0)
            var birthRate = Float(max(0.5, density / 10.0))
            // kalgram: no snow at all in Low Power Mode
            if ProcessInfo.processInfo.isLowPowerModeEnabled {
                birthRate = 0.0
            } else if UIAccessibility.isReduceMotionEnabled {
                birthRate = birthRate / 3
            }
            for cell in cells {
                cell.birthRate = birthRate / Float(cells.count)
            }
            particlesLayer.emitterCells = cells
        }

        if let emitterLayer = self.emitterLayer {
            var emitterWidthK: CGFloat = 1.5
            switch self.style {
                case SGSimpleSettings.NYStyle.lightning.rawValue:
                    emitterWidthK = 1.5
                default:
                    break
            }
            emitterLayer.emitterPosition = CGPoint(x: 0.0, y: self.rising ? size.height * 1.125 : -size.height / 8.0)
            emitterLayer.emitterSize = CGSize(width: size.width * emitterWidthK, height: size.height)
            emitterLayer.frame = CGRect(x: 0.0, y: 0.0, width: size.width, height: size.height)
        }
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
