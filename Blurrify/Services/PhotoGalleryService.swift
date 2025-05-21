//
//  PhotoGalleryService.swift
//  Blurrify
//
//  Created by Neftali Samarey on 4/26/24.
//

import Foundation
import Photos
import UIKit

public class ImageSaver: NSObject {
    var successHandler: (() -> Void)?
    var errorHandler: ((Error) ->Void)?

    //***Method to save to Disk
    //The location we want to Save.
    func writeToDisk(image: UIImage, imageName: String) {
        let savePath = FileManager.documentsDirectory.appendingPathComponent("\(imageName).jpg") //Where are I want to store my data
        if let jpegData = image.jpegData(compressionQuality: 0.5) { // I can adjust the compression quality.
            try? jpegData.write(to: savePath, options: [.atomic, .completeFileProtection])
        }
    }
}

extension FileManager {
    static var documentsDirectory: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
}

/*class PhotoGalleryService: ObservableObject {
    var authorizationStatus: PHAuthorizationStatus = .notDetermined

    func requestAuthorization(handleError: ((AuthorizationError?) -> Void)? = nil) {
        /// This is the code that does the permission requests
        PHPhotoLibrary.requestAuthorization { [weak self] status in
            self?.authorizationStatus = status
            /// We can determine permission granted by the status
            switch status {
                /// Fetch all photos if the user granted us access
                /// This won't be the photos themselves but the
                /// references only.
            case .authorized, .limited:
                self?.fetchAllPhotos()

                /// For denied response, we should show an error
            case .denied, .notDetermined, .restricted:
                handleError?(.restrictedAccess)

            @unknown default:
                break
            }
        }
    }
}*/
