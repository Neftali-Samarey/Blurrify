//
//  View+Extensions.swift
//  Blurrify
//
//  Created by Neftali Samarey on 4/26/24.
//

import SwiftUI

extension View {

    func dottedBorder(_ color: Color) -> some View {
        self.overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(color, style: StrokeStyle(lineWidth: 1, dash: [5]))
        }
    }
}

extension UIImage {

    /*func blurredImageWithBlurredEdges(inputRadius: CGFloat) -> UIImage? {

        guard let currentFilter = CIFilter(name: "CIGaussianBlur") else {
            return nil
        }
        guard let beginImage = CIImage(image: self) else {
            return nil
        }
        currentFilter.setValue(beginImage, forKey: kCIInputImageKey)
        currentFilter.setValue(inputRadius, forKey: "inputRadius")
        guard let output = currentFilter.outputImage else {
            return nil
        }

        // UIKit and UIImageView .contentMode doesn't play well with
        // CIImage only, so we need to back the return UIImage with a CGImage
        let context = CIContext()

        // cropping rect because blur changed size of image
        guard let final = context.createCGImage(output, from: beginImage.extent) else {
            return nil
        }

        return UIImage(cgImage: final)
    }*/

    /*func blurredImageWithClippedEdges(inputRadius: CGFloat) -> UIImage? {

        guard let currentFilter = CIFilter(name: "CIGaussianBlur") else {
            return nil
        }

        guard let beginImage = CIImage(image: self) else {
            return nil
        }

        currentFilter.setValue(beginImage, forKey: kCIInputImageKey)
        currentFilter.setValue(inputRadius, forKey: "inputRadius")
        guard let output = currentFilter.outputImage else {
            return nil
        }

        // UIKit and UIImageView .contentMode doesn't play well with
        // CIImage only, so we need to back the return UIImage with a CGImage
        let context = CIContext()

        // cropping rect because blur changed size of image

        // to clear the blurred edges, use a fromRect that is
        // the original image extent insetBy (negative) 1/2 of new extent origins
        let newExtent = beginImage.extent.insetBy(dx: -output.extent.origin.x * 0.5, dy: -output.extent.origin.y * 0.5)
        guard let final = context.createCGImage(output, from: newExtent) else {
            return nil
        }
        return UIImage(cgImage: final)
    }*/

    func blurredImageWithClippedEdges(inputRadius: CGFloat) -> UIImage? {
        guard let currentFilter = CIFilter(name: "CIGaussianBlur"),
              let beginImage = CIImage(image: self)
        else { return nil }

        currentFilter.setValue(beginImage, forKey: kCIInputImageKey)
        currentFilter.setValue(inputRadius, forKey: kCIInputRadiusKey)

        guard let output = currentFilter.outputImage else { return nil }

        let context = CIContext()

        // Calculate the cropping rect
        /*
        let xOffset = -output.extent.origin.x * 0.5
        let yOffset = -output.extent.origin.y * 0.5
        let newExtent = CGRect(x: xOffset, y: yOffset, width: beginImage.extent.width, height: beginImage.extent.height)
        guard let final = context.createCGImage(output, from: newExtent) else { return nil }
         */

        /*let newExtent = beginImage.extent.insetBy(dx: -output.extent.origin.x * 0.5,
                                                  dy: -output.extent.origin.y * 0.5)
        guard let final = context.createCGImage(output, from: newExtent) else {
            return nil
        }*/
        guard let final = context.createCGImage(output, from: output.extent) else { return nil }

        return UIImage(cgImage: final)
    }
}
