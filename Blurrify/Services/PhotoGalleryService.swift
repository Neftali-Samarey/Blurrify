//
//  PhotoGalleryService.swift
//  Blurrify
//
//  Created by Neftali Samarey on 4/26/24.
//

import Foundation
import Photos

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
