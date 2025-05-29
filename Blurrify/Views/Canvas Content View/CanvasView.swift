//
//  CanvasView.swift
//  Blurrify
//
//  Created by Neftali Samarey on 5/21/25.
//

import AlertKit
import SwiftUI
import UIKit
import Zoomable
import CoreImage
import CoreImage.CIFilterBuiltins

public struct SnapshotView: View {
    let image: Image
    let imageSize: CGSize
    let overlay: AnyView?
    let renderAtActualSize: Bool

    public init(image: Image, imageSize: CGSize, overlay: AnyView? = nil, renderAtActualSize: Bool = false) {
        self.image = image
        self.imageSize = imageSize
        self.overlay = overlay
        self.renderAtActualSize = renderAtActualSize
    }

    public var contentImage: Image {
        image
    }

    public var body: some View {
        ZStack {
            image
                .resizable()
                .aspectRatio(contentMode: renderAtActualSize ? .fill : .fit)
                .frame(
                    width: renderAtActualSize ? imageSize.width : nil,
                    height: renderAtActualSize ? imageSize.height : nil
                )
                .border(Color.red)
            // overlay rec draw UI
            

        }
        .frame(
            width: renderAtActualSize ? imageSize.width : nil,
            height: renderAtActualSize ? imageSize.height : nil
        )
    }
}



public struct CanvasView: View {

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dimisss

    private let image: Image
    private let size: CGSize

    private let completion: ((ControlEvent) -> Void)
    private let successAlert = AlertAppleMusic17View(title: "Image Saved Successfully", subtitle: nil, icon: .done)

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var alertPresented: Bool = false
    @State private var showingDiscardAlet: Bool = false

    @State private var rectangleMaskSelected: Bool = false
    @State private var rectangleRect: CGRect = .zero

    // tbd
    @State private var startPoint: CGPoint? = nil
    @State private var currentPoint: CGPoint? = nil
    @State private var endPoint: CGPoint? = nil
    @GestureState private var dragOffset = CGSize.zero
    @State private var rectangles: [CGRect] = []
    @State private var rectanglesRepo: [CGRect] = []

    // Move into service
    @State private var blurRadius: CGFloat = 0.0
    @State private var imageSize: CGSize = CGSize(width: 1206, height: 2144)

    public init(image: Image, size: CGSize, completion: @escaping ((ControlEvent) -> Void)) {
        self.image = image
        self.size = size
        self.completion = completion
    }

    private var snapshotTestAreaView: some View {
        ZStack {
            SnapshotView(image: image, imageSize: size, renderAtActualSize: false)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var snapshotAreaView: some View {
        ZStack {
            // layer 0
            image
                .resizable()
                .scaledToFit()
                .blur(radius: blurRadius, opaque: true)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if startPoint == nil {
                                startPoint = value.startLocation
                            }
                            currentPoint = value.location
                        }
                        .onEnded { value in
                            guard let start = startPoint, let end = currentPoint else { return }
                            let rect = CGRect(
                                x: min(start.x, end.x),
                                y: min(start.y, end.y),
                                width: abs(end.x - start.x),
                                height: abs(end.y - start.y)
                            )
                            rectangles.append(rect)
                            startPoint = nil
                            currentPoint = nil
                        }
                )
                .onAppear {
                }

            // layer 1
            // Draw existing rectangles (Blur segments)
            ForEach(rectangles.indices, id: \.self) { index in
                let rect = rectangles[index]
                Rectangle()
                    .fill(Color.yellow)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
            }

            // Draw current dragging rectangle
            if let start = startPoint, let end = currentPoint {
                let tempRect = CGRect(
                    x: min(start.x, end.x),
                    y: min(start.y, end.y),
                    width: abs(end.x - start.x),
                    height: abs(end.y - start.y)
                )
                Rectangle()
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 2, dash: [6]))
                    .frame(width: tempRect.width, height: tempRect.height)
                    .position(x: tempRect.midX, y: tempRect.midY)
            }
        }
        .clipped()
    }

    public var body: some View {
        GeometryReader { geo in
            VStack {
                snapshotTestAreaView
                    .border(Color.blue)
                /*SnapshotView(image: image, imageSize: size, renderAtActualSize: false)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .border(Color.red)*/

                /*snapshotAreaView
                    .border(Color.red)*/
            }
            .frame(maxHeight: .infinity)
            .overlay(alignment: .bottom) {
                ControlView { event in
                    switch event {
                    case .scribble:
                        print("Scribble")
                    case .region:
                        self.rectangleMaskSelected = true
                    case .blurIntensityGauge(let blurIntensity):
                        blurRadius = blurIntensity
                    case .saving:
                        let renderer = UIGraphicsImageRenderer(size: imageSize)
                        let image = renderer.image { _ in
                            //let controller = UIHostingController(rootView: self.snapshotAreaView)
                            let controller = UIHostingController(rootView: self.snapshotTestAreaView)
                            controller.view.frame = CGRect(origin: .zero, size: imageSize)
                            controller.view.backgroundColor = .clear
                            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
                        }

                        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                    case .trash:
                        completion(.trash)
                        dimisss()
                    }
                }
            }
            .alert(isPresent: $alertPresented, view: successAlert)
            .toolbar{
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button(action: {
                        // Undo action
                        let lastItem = rectangles.removeLast()
                        rectanglesRepo.append(lastItem)
                    }) {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .disabled(rectangles.count < 1)

                    Button(action: {
                        // Redo action
                    }) {
                        Image(systemName: "arrow.uturn.forward")
                    }
                    .disabled(true)
                    //.disabled(rectanglesRepo.isEmpty)
                }
            }
            .background(colorScheme == .dark ? Color.backgroundDarkBlue : Color.white)
        }
    }

    // MARK: - Other Local Views
}

// MARK: - UIKit Blur View Object
public struct BlurView: UIViewRepresentable {
    let style: UIBlurEffect.Style

    public func makeUIView(context: Context) -> UIVisualEffectView {
        let blurEffect = UIBlurEffect(style: style)
        let blurView = UIVisualEffectView(effect: blurEffect)
        return blurView
    }

    public func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        // No update needed
    }
}

public struct BlurView2: View {
    let image: UIImage
    let radius: CGFloat

    public var body: some View {
        GeometryReader { geometry in
            if let blurredImage = applyBlur(to: image, radius: radius) {
                Image(uiImage: blurredImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
            }
        }
    }

    private func applyBlur(to image: UIImage, radius: CGFloat) -> UIImage? {
        let ciImage = CIImage(image: image)
        let context = CIContext()
        let filter = CIFilter.gaussianBlur()
        filter.inputImage = ciImage
        filter.radius = Float(radius)

        guard let outputImage = filter.outputImage else { return nil }

        // Crop back to original image size to avoid growing due to blur spread
        let croppedImage = outputImage.cropped(to: ciImage!.extent)

        if let cgImage = context.createCGImage(croppedImage, from: ciImage!.extent) {
            return UIImage(cgImage: cgImage)
        }
        return nil
    }
}


// MARK - Creating a Snapshot for both image + overlay views
/*struct SnapshotView<Content: View>: UIViewRepresentable {
    let content: Content
    let size: CGSize

    init(size: CGSize, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.size = size
    }

    func makeUIView(context: Context) -> UIView {
        let controller = UIHostingController(rootView: content)
        controller.view.frame = CGRect(origin: .zero, size: size)
        controller.view.backgroundColor = .clear
        return controller.view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // No update needed
    }

    func snapshot() -> UIImage {
        let controller = UIHostingController(rootView: content)
        controller.view.frame = CGRect(origin: .zero, size: size)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }
}*/

/// A View in which content reflects all behind it
struct BackdropView: UIViewRepresentable {

    func makeUIView(context: Context) -> UIVisualEffectView {
        let view = UIVisualEffectView()
        let blur = UIBlurEffect()
        let animator = UIViewPropertyAnimator()
        animator.addAnimations { view.effect = blur }
        animator.fractionComplete = 0
        animator.stopAnimation(false)
        animator.finishAnimation(at: .current)
        return view
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) { }
}

/// A transparent View that blurs its background
struct BackdropBlurView: View {

    let radius: CGFloat

    @ViewBuilder
    var body: some View {
        BackdropView().blur(radius: radius, opaque: true)
    }
}
