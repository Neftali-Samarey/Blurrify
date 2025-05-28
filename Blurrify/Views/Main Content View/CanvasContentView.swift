//
//  CanvasContentView.swift
//  Blurrify
//
//  Created by Neftali Samarey on 5/27/25.
//

import SwiftUI

struct ImageFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

public struct CanvasContentView: View {

    @Environment(\.colorScheme) var colorScheme

    // image states
    @State private var startPoint: CGPoint? = nil
    @State private var currentPoint: CGPoint? = nil
    @State private var rectangles: [CGRect] = []

    // control states
    @State private var rectangleMaskSelected: Bool = false

    private let uiImage: UIImage
    private let completion: ((ControlEvent) -> Void)

    public init(image: UIImage, completion: @escaping (ControlEvent) -> Void) {
        self.uiImage = image
        self.completion = completion
    }

    public var body: some View {
        VStack {
            snapshotView
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottom) {
            ControlView { event in
                switch event {
                case .scribble:
                    rectangleMaskSelected = false
                case .region:
                    rectangleMaskSelected = true
                case .fullBlur(let blurIntensity):
                    print("Blur Value: \(blurIntensity)")
                    rectangleMaskSelected = false
                case .saving:
                    print("Saving action")
                    //UIImageWriteToSavedPhotosAlbum(uiImage, nil, nil, nil)
                case .trash:
                    completion(.trash)
                }
            }
        }
        .background(colorScheme == .dark ? Color.backgroundDarkBlue : Color.white)
    }

    // MARK: - Snapshot View

    private var snapshotView: some View {
        GeometryReader { outerGeometry in
            ZStack {
                let availableSize = outerGeometry.size
                let imageSize = uiImage.size
                let aspectRatio = imageSize.width / imageSize.height

                // Compute fitted size
                let fittedWidth = min(availableSize.width, availableSize.height * aspectRatio)
                let fittedHeight = min(availableSize.height, availableSize.width / aspectRatio)
                let finalSize = CGSize(width: fittedWidth, height: fittedHeight)

                VStack {
                    Spacer()

                    ZStack {
                        GeometryReader { imageGeometry in
                            let imageFrame = imageGeometry.frame(in: .local)

                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(width: finalSize.width, height: finalSize.height)
                                .clipped()

                            // Rectangles overlay
                            ZStack {
                                ForEach(rectangles.indices, id: \.self) { index in
                                    let rect = rectangles[index]
                                    Rectangle()
                                        .fill(Color.yellow.opacity(0.6))
                                        .frame(width: rect.width, height: rect.height)
                                        .position(x: rect.midX, y: rect.midY)
                                }

                                if let start = startPoint, let end = currentPoint {
                                    let clampedStart = clamp(point: start, to: imageFrame)
                                    let clampedEnd = clamp(point: end, to: imageFrame)

                                    let rect = CGRect(
                                        x: min(clampedStart.x, clampedEnd.x),
                                        y: min(clampedStart.y, clampedEnd.y),
                                        width: abs(clampedEnd.x - clampedStart.x),
                                        height: abs(clampedEnd.y - clampedStart.y)
                                    )

                                    Rectangle()
                                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 2, dash: [6]))
                                        .frame(width: rect.width, height: rect.height)
                                        .position(x: rect.midX, y: rect.midY)
                                }
                            }
                            .clipped()
                        }
                    }
                    .frame(width: finalSize.width, height: finalSize.height)
                    .gesture(rectangleMaskSelected ? rectangleGestureMasking(size: finalSize) : nil)
                    Spacer()
                }
            }
        }
    }

    private func clamp(point: CGPoint, to rect: CGRect) -> CGPoint {
        CGPoint(
            x: min(max(point.x, rect.minX), rect.maxX),
            y: min(max(point.y, rect.minY), rect.maxY)
        )
    }

    // MARK: - Gestures
    // Rectangle Gesture (Origin based, and image bound based).
    private func rectangleGestureMasking(size: CGSize) -> some Gesture {
        return DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard rectangleMaskSelected else { return }
                if startPoint == nil {
                    startPoint = value.location
                }
                currentPoint = value.location
            }
            .onEnded { value in
                guard rectangleMaskSelected,
                      let start = startPoint,
                      let end = currentPoint else {
                    startPoint = nil
                    currentPoint = nil
                    return
                }

                let imageFrame = CGRect(origin: .zero, size: size)

                let clampedStart = clamp(point: start, to: imageFrame)
                let clampedEnd = clamp(point: end, to: imageFrame)

                let rect = CGRect(
                    x: min(clampedStart.x, clampedEnd.x),
                    y: min(clampedStart.y, clampedEnd.y),
                    width: abs(clampedEnd.x - clampedStart.x),
                    height: abs(clampedEnd.y - clampedStart.y)
                )

                rectangles.append(rect)
                startPoint = nil
                currentPoint = nil
            }
    }

    // more gestures
}
