import Foundation
import UIKit
import CoreImage
import Vision
import SGProUI

// kalgram: the subject of a picture, cut out of its background with Vision (iOS 17+).
// The result is cropped to the subject. Nil when Vision finds no subject, or fails.
@available(iOS 17.0, *)
func kalgramCutOutSubject(_ image: UIImage) -> UIImage? {
    guard let cgImage = image.cgImage else {
        return nil
    }
    let request = VNGenerateForegroundInstanceMaskRequest()
    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    do {
        try handler.perform([request])
        guard let observation = request.results?.first, !observation.allInstances.isEmpty else {
            return nil
        }
        let buffer = try observation.generateMaskedImage(ofInstances: observation.allInstances, from: handler, croppedToInstancesExtent: true)
        let ciImage = CIImage(cvPixelBuffer: buffer)
        let context = CIContext(options: nil)
        guard let output = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        return UIImage(cgImage: output)
    } catch {
        return nil
    }
}

// kalgram: a picture for the falling effect, as PNG at most 128 px: its subject cut out when asked
// and possible (iOS 17+), otherwise the picture as it is.
func kalgramParticlePNG(from data: Data, removeBackground: Bool) -> Data? {
    guard let image = UIImage(data: data) else {
        return nil
    }
    var source = image
    if removeBackground, #available(iOS 17.0, *) {
        // Vision works on a smaller copy: the subject's outline does not need more
        if let cutOut = kalgramCutOutSubject(KalgramImagePicker.downscaled(image, maxSide: 1024.0)) {
            source = cutOut
        }
    }
    return KalgramImagePicker.downscaled(source, maxSide: 128.0).pngData()
}
