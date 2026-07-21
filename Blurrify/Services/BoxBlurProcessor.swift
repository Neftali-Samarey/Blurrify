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

    /// Pass flattened rects (e.g. from `CanvasMaskGeometry.allBlurRects(from:scribbleBrushWidth:)`),
    /// expressed in the fitted canvas coordinate space (`lastImageSize`).
    init?(image: UIImage, lastImageSize: CGSize, rectangles: [CGRect]) {
        guard lastImageSize.width > 0, lastImageSize.height > 0 else { return nil }

        // Normalize orientation so the base draw and the CoreImage blur layer align.
        let normalized = BoxBlurProcessor.normalizedUp(image)
        guard let ciImage = CIImage(image: normalized) else { return nil }

        self.originalImage = normalized
        self.ciImage = ciImage
        self.ciContext = CIContext(options: nil)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = normalized.scale
        format.opaque = true
        self.format = format
        self.renderer = UIGraphicsImageRenderer(size: normalized.size, format: format)

        self.scaleX = normalized.size.width / lastImageSize.width
        self.scaleY = normalized.size.height / lastImageSize.height
        self.rectangles = rectangles
    }

    /// - Parameter blurIntensity: the preview radius (points in the fitted canvas space).
    ///   It is scaled up to native pixels so the exported blur matches the on-screen preview
    ///   once the full-resolution image is displayed at the fitted size.
    func applyBlur(with blurIntensity: CGFloat) -> UIImage? {
        guard blurIntensity > 0, !rectangles.isEmpty else { return originalImage }

        // Convert the preview radius (fitted points) into native pixels:
        // fitted points -> full-res points (scaleX) -> pixels (image.scale).
        let pixelRadius = blurIntensity * scaleX * originalImage.scale

        // Clamp so the blur samples surrounding pixels instead of fading at the edges.
        let clamped = ciImage.clampedToExtent()
        let blur = CIFilter.gaussianBlur()
        blur.inputImage = clamped
        blur.radius = Float(pixelRadius)

        guard let blurred = blur.outputImage?.cropped(to: ciImage.extent),
              let blurredCG = ciContext.createCGImage(blurred, from: ciImage.extent) else {
            return nil
        }

        let blurredImage = UIImage(
            cgImage: blurredCG,
            scale: originalImage.scale,
            orientation: .up
        )

        let fullFrame = CGRect(origin: .zero, size: originalImage.size)

        return renderer.image { context in
            originalImage.draw(in: fullFrame)

            let cgContext = context.cgContext
            cgContext.saveGState()

            // Clip to the union of every mask rect (mapped into full-res point space),
            // then paint the pre-blurred layer only inside those regions.
            let clipPath = CGMutablePath()
            for rect in rectangles {
                let mapped = CGRect(
                    x: rect.origin.x * scaleX,
                    y: rect.origin.y * scaleY,
                    width: rect.size.width * scaleX,
                    height: rect.size.height * scaleY
                )
                clipPath.addRect(mapped)
            }
            cgContext.addPath(clipPath)
            cgContext.clip()

            blurredImage.draw(in: fullFrame)

            cgContext.restoreGState()
        }
    }

    /// Redraws an image with a non-`.up` orientation into an upright bitmap so pixel
    /// coordinates line up between the base image and the CoreImage blur.
    private static func normalizedUp(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }
}
