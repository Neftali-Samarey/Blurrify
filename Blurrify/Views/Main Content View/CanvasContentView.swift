//
//  CanvasContentView.swift
//  Blurrify
//
//  Created by Neftali Samarey on 5/27/25.
//

import SwiftUI

public struct CanvasContentView: View {

    @Environment(\.colorScheme) var colorScheme

    private let uiImage: UIImage
    private let completion: ((ControlEvent) -> Void)

    public init(image: UIImage, completion: @escaping (ControlEvent) -> Void) {
        self.uiImage = image
        self.completion = completion
    }

    public var body: some View {
        VStack {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottom) {
            ControlView { event in
                switch event {
                case .scribble:
                    print("Scribble")
                case .region:
                    print("Region")
                case .fullBlur(let blurIntensity):
                    print("Blur Value: \(blurIntensity)")
                case .saving:
                    UIImageWriteToSavedPhotosAlbum(uiImage, nil, nil, nil)
                case .trash:
                    completion(.trash)
                }
            }
        }
        .background(colorScheme == .dark ? Color.backgroundDarkBlue : Color.white)
    }
}
