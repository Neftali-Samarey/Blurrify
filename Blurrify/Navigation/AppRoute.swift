//
//  Router.swift
//  Blurrify
//
//  Created by Neftali Samarey on 10/22/26.
//

import Foundation

/// Used for the main navigation of Blurrify's UI
/// Ex: `Root -> Canvas` or when dismissed `Canvas -> Root`.
enum AppRoute: Hashable {
    case root
    case canvas
}
