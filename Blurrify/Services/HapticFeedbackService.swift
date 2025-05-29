//
//  HapticFeedbackService.swift
//  Blurrify
//
//  Created by Neftali Samarey on 5/28/25.
//

import AudioToolbox
import Foundation
import UIKit

public enum Feedback {
    case success
    case error
    case warning
    case light
    case medium
    case heavy
    case selection

    public func vibrate() {
        switch self {
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .error:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        case .warning:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .light:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .medium:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .heavy:
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        case .selection:
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }
}

class HapticFeedbackService {

    static func vibrate(_ feedback: Feedback) {
        feedback.vibrate()
    }
}
