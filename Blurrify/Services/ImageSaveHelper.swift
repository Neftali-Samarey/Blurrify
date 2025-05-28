//
//  ImageSaveHelper.swift
//  Blurrify
//
//  Created by Neftali Samarey on 5/28/25.
//
import UIKit

class ImageSaveHelper: NSObject {
    static let shared = ImageSaveHelper()

    var completion: ((Error?) -> Void)?

    @objc func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer?) {
        completion?(error)
    }
}
