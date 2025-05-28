//
//  CanvasContentView.swift
//  Blurrify
//
//  Created by Neftali Samarey on 5/27/25.
//

import SwiftUI

public struct CanvasContentView: View {

    @Environment(\.colorScheme) var colorScheme

    private let image: Image
    private let size: CGSize
    private let completion: ((ControlEvent) -> Void)

    public init(image: Image, size: CGSize, completion: @escaping (ControlEvent) -> Void) {
        self.image = image
        self.size = size
        self.completion = completion
    }

    public var body: some View {
        VStack {
            Text("Content View")
        }
        .background(colorScheme == .dark ? Color.backgroundDarkBlue : Color.white)
    }
}

#Preview {
    CanvasContentView(image: .init(""), size: CGSize()) { _ in }
}
