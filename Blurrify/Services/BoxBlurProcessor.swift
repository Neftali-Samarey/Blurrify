//
//  BoxBlurProcessor.swift
//  Blurrify
//
//  Created by Neftali Samarey on 5/12/26.
//

import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

public final class BoxBlurProcessor {
    private let originalImage: UIImage
    private let ciImage: CIImage
    private let ciContext: CIContext
    private let format: UIGraphicsImageRendererFormat
    private let renderer: UIGraphicsImageRenderer
    private let scaleX: CGFloat
    private let scaleY: CGFloat
    private let rectangles: [CGRect]

    /// Pass flattened rects (e.g. from `CanvasMaskGeometry.allBlurRects(from:scribbleBrushWidth:)`).
    init?(image: UIImage, lastImageSize: CGSize, rectangles: [CGRect]) {
        guard let ciImage = CIImage(image: image) else { return nil }

        self.originalImage = image
        self.ciImage = ciImage
        self.ciContext = CIContext(options: nil)
        self.format = UIGraphicsImageRendererFormat.default()
        self.format.scale = image.scale
        self.renderer = UIGraphicsImageRenderer(size: image.size, format: format)

        self.scaleX = image.size.width / lastImageSize.width
        self.scaleY = image.size.height / lastImageSize.height
        self.rectangles = rectangles
    }

    func applyBlur(with blurIntensity: CGFloat) -> UIImage? {
        let imageContext = renderer.image { context in
            // Draw base image
            originalImage.draw(in: CGRect(origin: .zero, size: originalImage.size))

            let cgContext = context.cgContext

            cgContext.saveGState()
            cgContext.translateBy(x: 0, y: originalImage.size.height)
            cgContext.scaleBy(x: 1.0, y: -1.0)

            for rect in rectangles {
                let scaledRect = CGRect(
                    x: rect.origin.x * scaleX,
                    y: rect.origin.y * scaleY,
                    width: rect.size.width * scaleX,
                    height: rect.size.height * scaleY
                )

                let cropped = ciImage.cropped(to: scaledRect)

                let blurFilter = CIFilter.boxBlur()
                blurFilter.inputImage = cropped
                blurFilter.radius = Float(blurIntensity)

                guard let blurredOutput = blurFilter.outputImage else { continue }

                ciContext.draw(blurredOutput, in: scaledRect, from: cropped.extent)
            }

            cgContext.restoreGState()
        }

        return imageContext
    }
}
