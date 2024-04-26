//
//  View+Extensions.swift
//  Blurrify
//
//  Created by Neftali Samarey on 4/26/24.
//

import SwiftUI

extension View {

    func dottedBorder(_ color: Color) -> some View {
        self.overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(color, style: StrokeStyle(lineWidth: 1, dash: [5]))
        }
    }
}
