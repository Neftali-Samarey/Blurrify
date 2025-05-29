//
//  Icons.swift
//  Blurrify
//
//  Created by Neftali Samarey on 5/28/25.
//

import Foundation

public enum Icon: String, CaseIterable {
    case addImage
    case chevronLeft
    case download
    case pan
    case scribble
    case square
    case redo
    case toggle
    case trash
    case undo

    var systemName: String {
        switch self {
        case .addImage:
            return "photo.badge.plus"
        case .chevronLeft:
            return "chevron.left"
        case .download:
            return "square.and.arrow.down"
        case .pan:
            return "rectangle.and.arrow.up.right.and.arrow.down.left"
        case .scribble:
            return "scribble.variable"
        case .square:
            return "square"
        case .redo:
            return "arrow.uturn.forward"
        case .toggle:
            return "switch.2"
        case .trash:
            return "trash"
        case .undo:
            return "arrow.uturn.backward"
        }
    }
}
