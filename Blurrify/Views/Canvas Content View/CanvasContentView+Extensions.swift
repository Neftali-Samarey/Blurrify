//
//  CanvasContentView+Extensions.swift
//  Blurrify
//
//  Created by Neftali Samarey on 5/28/25.
//
import SwiftUI

extension CanvasContentView {

    // Used to clamp the dragging rectangle to prevent going out of bounds
    func clamp(point: CGPoint, to rect: CGRect) -> CGPoint {
        CGPoint(
            x: min(max(point.x, rect.minX), rect.maxX),
            y: min(max(point.y, rect.minY), rect.maxY)
        )
    }
}
