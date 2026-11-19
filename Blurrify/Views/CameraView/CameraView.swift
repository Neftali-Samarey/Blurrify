//
//  CameraView.swift
//  Blurrify
//
//  Created by Neftali Samarey on 11/17/26.
//

import SwiftUI

struct CameraView: View {
    
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Binding var image: CGImage?
    
    var body: some View {
        GeometryReader { geometry in
            Group {
                if let image {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .scaledToFill()
                        .overlay(alignment: .bottom) {
                            cameraControlView
                                .frame(width: geometry.size.width * 0.90, height: 80)
                                .safeAreaPadding(.bottom)
                        }
                } else {
                    ContentUnavailableView("No camera feed", systemImage: "xmark.circle.fill")
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .ignoresSafeArea()
    }
}

fileprivate extension CameraView {
    var cameraControlView: some View {
        RoundedRectangle(cornerRadius: 16.0, style: .circular)
            .foregroundStyle(.black.opacity(0.6))
            .overlay(alignment: .center) {
                if verticalSizeClass == .compact {
                    Text("Lanscape")
                } else {
                    Text("Portrait")
                }
            }
    }
}

#Preview {
    CameraView(image: .constant(nil))
}
