//
//  CanvasView.swift
//  Blurrify
//
//  Created by Neftali Samarey on 5/27/25.
//

import AlertKit
import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

public struct CanvasView: View {

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dimisss

    private let successAlert = AlertAppleMusic17View(title: "Image Saved Successfully", subtitle: nil, icon: .done)
    private let errorAlert = AlertAppleMusic17View(title: "Unable to save image", subtitle: nil, icon: .error)

    // image states
    @State private var startPoint: CGPoint? = nil
    @State private var currentPoint: CGPoint? = nil
    @State private var rectangles: [CGRect] = []
    @State private var rectanglesRepo: [CGRect] = []
    @State private var lastImageSize: CGSize = .zero
    @State private var blurIntensityRadius: CGFloat = 5

    // control states
    @State private var rectangleMaskSelected: Bool = false
    @State private var alertPresented: Bool = false
    @State private var errorPresented: Bool = false
    @State private var showTrashAlert = false

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
                    rectangleMaskSelected.toggle()
                case .blurIntensityGauge(let blurIntensity):
                    blurIntensityRadius = blurIntensity
                case .saving:
                    // process the image...
                    /*let format = UIGraphicsImageRendererFormat.default()
                    format.scale = uiImage.scale
                    let renderer = UIGraphicsImageRenderer(size: uiImage.size, format: format)

                    let image = renderer.image { context in
                        // Draw base image first
                        uiImage.draw(in: CGRect(origin: .zero, size: uiImage.size))

                        // Get the context to draw overlays
                        let cgContext = context.cgContext

                        // Scale factor if your image in SwiftUI was scaled down compared to uiImage
                        let scaleX = uiImage.size.width / lastImageSize.width
                        let scaleY = uiImage.size.height / lastImageSize.height

                        // Draw saved rectangles
                        for rect in rectangles {
                            let scaledRect = CGRect(
                                x: rect.origin.x * scaleX,
                                y: rect.origin.y * scaleY,
                                width: rect.size.width * scaleX,
                                height: rect.size.height * scaleY
                            )

                            cgContext.setFillColor(UIColor.black.cgColor)
                            cgContext.fill(scaledRect)
                        }
                    }

                    UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)*/

                    /*let format = UIGraphicsImageRendererFormat.default()
                    format.scale = uiImage.scale
                    let renderer = UIGraphicsImageRenderer(size: uiImage.size, format: format)*/

                    /*
                    // test
                    let context = CIContext()
                    let filter = CIFilter(name: "CISepiaTone")!
                    filter.setValue(0.8, forKey: kCIInputIntensityKey)
                    let testImage = CIImage(image: uiImage)
                    //testImage ~ immutable object representing an image.
                    filter.setValue(testImage, forKey: kCIInputImageKey)
                    let result = filter.outputImage!
                    let cgImage = context.createCGImage(result, from: result.extent)
                    guard let finalImage = cgImage else { return }

                    // conver the finalImage to UIImage.
                    let finalized = UIImage(cgImage: finalImage)
                    */
                    // end

                    // working sample below
                    /*
                     let format = UIGraphicsImageRendererFormat.default()
                    format.scale = uiImage.scale
                    let renderer = UIGraphicsImageRenderer(size: uiImage.size, format: format)

                    let image = renderer.image { context in
                        // Draw base image
                        uiImage.draw(in: CGRect(origin: .zero, size: uiImage.size))

                        let cgContext = context.cgContext

                        let scaleX = uiImage.size.width / lastImageSize.width
                        let scaleY = uiImage.size.height / lastImageSize.height

                        guard let ciImage = CIImage(image: uiImage) else { return }
                        let ciContext = CIContext(cgContext: cgContext, options: nil)

                        for rect in rectangles {
                            let scaledRect = CGRect(
                                x: rect.origin.x * scaleX,
                                y: rect.origin.y * scaleY,
                                width: rect.size.width * scaleX,
                                height: rect.size.height * scaleY
                            )

                            // Crop region from image
                            let cropped = ciImage.cropped(to: scaledRect)

                            // Apply blur
                            let blurFilter = CIFilter.boxBlur()
                            blurFilter.inputImage = cropped
                            blurFilter.radius = 10


                            guard let blurredOutput = blurFilter.outputImage else { continue }

                            // Draw blurred result back into context at the same position
                            ciContext.draw(blurredOutput, in: scaledRect, from: cropped.extent)
                        }
                    }*/

                    // called last after all edits.
                    saveImageToPhotos(uiImage) { error in
                        if let error = error {
                            errorPresented = true
                            print("Error saving to camera roll. Error: \(error)")
                            HapticFeedbackService.vibrate(.error)
                        } else {
                            alertPresented = true
                            HapticFeedbackService.vibrate(.success)
                        }
                    }
                case .trash:
                    showTrashAlert = true
                }
            }
            .alert("Are you sure you want to discard everything?", isPresented: $showTrashAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    completion(.trash)
                    dimisss()
                }
            } message: {
                Text("This action cannot be undone.")
            }
        }
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarLeading) {
                Button(action: {
                    // action

                    HapticFeedbackService.vibrate(.selection)
                }) {
                    Image(systemName: Icon.pan.systemName)
                }
                .hidden()
            }

            ToolbarItemGroup(placement: .topBarTrailing) {
                Button(action: {
                    // Undo action
                    if let lastItem = rectangles.popLast() {
                        rectanglesRepo.append(lastItem)
                    }

                    HapticFeedbackService.vibrate(.selection)
                }) {
                    Image(systemName: Icon.undo.systemName)
                }
                .disabled(rectangles.isEmpty)

                Button(action: {
                    // Redo action
                    if let lastmostItem = rectanglesRepo.popLast() {
                        rectangles.append(lastmostItem)
                    }

                    HapticFeedbackService.vibrate(.selection)
                }) {
                    Image(systemName: Icon.redo.systemName)
                }
                .disabled(rectanglesRepo.isEmpty)
            }
        }
        .alert(isPresent: $alertPresented, view: successAlert)
        .alert(isPresent: $errorPresented, view: errorAlert)
        .background(colorScheme == .dark ? Color.backgroundDarkBlue : Color.primaryWhite)
        .navigationBarBackButtonHidden(true)
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
                                    BackdropBlurView(radius: blurIntensityRadius)
                                        .frame(width: rect.width, height: rect.height)
                                        .clipShape(Rectangle())
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
                    .onAppear {
                        // not sure this works yet .. double check when time available.
                        lastImageSize = finalSize
                    }
                    .gesture(rectangleMaskSelected ? rectangleGestureMasking(size: finalSize) : nil)
                    Spacer()
                }
                .frame(maxWidth: outerGeometry.size.width)
            }
        }
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
                rectanglesRepo.removeAll()
                startPoint = nil
                currentPoint = nil
            }
    }
}
