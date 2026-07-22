//
//  Bundle+Extensions.swift
//  Blurrify
//
//  Created by Neftali Samarey on 7/22/26.
//

import Foundation

extension Bundle {
    /// Release version number (i.e 1.0.0)
    var releaseVersionNumber: String? {
        infoDictionary?["CFBundleShortVersionString"] as? String
    }
    
    /// Build version number (i.e 1.0)
    var buildVersionNumber: String? {
        infoDictionary?["CFBundleVersion"] as? String
    }
}
