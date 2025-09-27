//
//  Print.swift
//  Blurrify
//
//  Created by Neftali Samarey on 6/25/25.
//

import Foundation

public enum Print: CaseIterable {
    case madeWithLoveInNYC
    case easterEgg

    var context: String {
        switch self {
        case .madeWithLoveInNYC:
            return "Designed and developed with ❤️ in NYC"
        case .easterEgg:
            return "JK, made in NYC 😎"
        }
    }
}
