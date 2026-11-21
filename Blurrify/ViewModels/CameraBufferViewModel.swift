//
//  CameraBufferViewModel.swift
//  Blurrify
//
//  Created by Neftali Samarey on 11/19/26.
//

import Foundation
import CoreImage
import Observation
import UIKit

@Observable
class CameraBufferViewModel {
    
    var currentFrame: CGImage?
    private let cameraManager = CameraManager()
    private let imageSaver = ImageSaveHelper()
    private var isSavingPhoto = false
    
    init() {
        Task {
            await handleCameraPreviews()
        }
    }
    
    func handleCameraPreviews() async {
        for await image in cameraManager.previewStream {
            Task { @MainActor in
                currentFrame = image
            }
        }
    }
}

// MARK: Camera Shutter Action

extension CameraBufferViewModel {
    @MainActor
    func takePicture() async {
        guard !isSavingPhoto, let frame = currentFrame else {
            HapticFeedbackService.vibrate(.error)
            return
        }

        isSavingPhoto = true
        defer { isSavingPhoto = false }

        let image = UIImage(cgImage: frame)
        let saved = await saveToPhotoLibrary(image)
        HapticFeedbackService.vibrate(saved ? .success : .error)
    }
    
    private func saveToPhotoLibrary(_ image: UIImage) async -> Bool {
        await withCheckedContinuation { continuation in
            imageSaver.completion = { error in
                continuation.resume(returning: error == nil)
            }

            UIImageWriteToSavedPhotosAlbum(
                image,
                imageSaver,
                #selector(ImageSaveHelper.image(_:didFinishSavingWithError:contextInfo:)),
                nil
            )
        }
    }
}
