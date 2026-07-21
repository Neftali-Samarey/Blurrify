//
//  CanvasView.swift
//  Blurrify
//
//  Created by Neftali Samarey on 5/27/25.
//

import AlertKit
import SwiftUI

fileprivate enum AutoResizeCorner: CaseIterable {
    case topLeft, topRight, bottomLeft, bottomRight

    func anchor(in rect: CGRect) -> CGPoint {
        switch self {
        case .topLeft: return CGPoint(x: rect.minX, y: rect.minY)
        case .topRight: return CGPoint(x: rect.maxX, y: rect.minY)
        case .bottomLeft: return CGPoint(x: rect.minX, y: rect.maxY)
        case .bottomRight: return CGPoint(x: rect.maxX, y: rect.maxY)
        }
    }
}

public struct CanvasView: View {

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dimisss

    private let successAlert = AlertAppleMusic17View(title: "Image Saved Successfully", subtitle: nil, icon: .done)
    private let errorAlert = AlertAppleMusic17View(title: "Unable to save image", subtitle: nil, icon: .error)

    // image states
    @State private var startPoint: CGPoint? = nil
    @State private var currentPoint: CGPoint? = nil
    @State private var maskEdits: [CanvasMaskEdit] = []
    @State private var maskEditsRedo: [CanvasMaskEdit] = []
    @State private var lastImageSize: CGSize = .zero
    @State private var blurIntensityRadius: CGFloat = 5
    @State private var editedImage: UIImage?

    // control states
    @State private var rectangleMaskSelected: Bool = false
    @State private var scribbleMaskSelected: Bool = false
    @State private var autoRedactMode: Bool = false
    @State private var selectedAutoMaskID: UUID?
    @State private var didRunVisionForCurrentAutoSession: Bool = false
    @State private var autoMoveDragBase: CGRect?
    @State private var autoResizeSession: (corner: AutoResizeCorner, startRect: CGRect)?
    @State private var currentStroke: [CGPoint] = []
    @State private var alertPresented: Bool = false
    @State private var errorPresented: Bool = false
    @State private var showTrashAlert = false
    @State private var shouldHideToolbar = false

    @State private var raiseToolbar = false
    @State private var viewHeight: CGFloat = 0
    @State private var screenHeight: CGFloat = UIScreen.main.bounds.height
    
    // new additions to attempt to pan/zoom
    @State var scale: CGFloat = 1.0
    @State var lastScale: CGFloat = 1.0
    @State var offset: CGSize = .zero
    @State var lastOffset: CGSize = .zero

    private let uiImage: UIImage
    private let completion: ((ControlEvent) -> Void)

    @State var blurProcessor: BoxBlurProcessor?

    public init(image: UIImage, completion: @escaping (ControlEvent) -> Void) {
        self.uiImage = image
        self.completion = completion
    }

    public var body: some View {
        snapshotView
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom) {
                Rectangle()
                    .frame(height: 75)
                    .overlay(alignment: .center) {
                        ControlView(autoRedactEnabled: $autoRedactMode, controlStyle: .overlay(style: .pill)) { controlEvents in
                            handleAction(for: controlEvents)
                        }
                        .padding(.horizontal, 12.5)
                    }
                    .foregroundStyle(Color.clear)
            }
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button(action: {
                        withAnimation(Animation.easeInOut(duration: 0.25)) {
                            resetImagePosition()
                        }
                        HapticFeedbackService.vibrate(.selection)
                    }) {
                        Image(systemName: Icon.pan.systemName)
                    }
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button(action: {
                        if let lastItem = maskEdits.popLast() {
                            maskEditsRedo.append(lastItem)
                        }

                        HapticFeedbackService.vibrate(.selection)
                    }) {
                        Image(systemName: Icon.undo.systemName)
                    }
                    .disabled(maskEdits.isEmpty)

                    Button(action: {
                        if let lastmostItem = maskEditsRedo.popLast() {
                            maskEdits.append(lastmostItem)
                        }

                        HapticFeedbackService.vibrate(.selection)
                    }) {
                        Image(systemName: Icon.redo.systemName)
                    }
                    .disabled(maskEditsRedo.isEmpty)
                }
            }
            .alert(isPresent: $alertPresented, view: successAlert)
            .alert(isPresent: $errorPresented, view: errorAlert)
            .alert("Are you sure you want to discard everything?", isPresented: $showTrashAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    completion(.trash)
                    dimisss()
                }
            } message: {
                Text("This action cannot be undone.")
            }
            .background(colorScheme == .dark ? Color.backgroundDarkBlue : Color.primaryWhite)
            .navigationBarBackButtonHidden(true)
    }
    
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
                            
                            // blur masks (rectangles + scribble strokes)
                            ZStack {
                                ForEach(maskEdits) { edit in
                                    switch edit.kind {
                                    case .rectangle(let rect):
                                        BackdropBlurView(radius: blurIntensityRadius)
                                            .frame(width: rect.width, height: rect.height)
                                            .clipShape(Rectangle())
                                            .position(x: rect.midX, y: rect.midY)
                                            .allowsHitTesting(false)
                                    case .scribble(let points):
                                        BackdropBlurView(radius: blurIntensityRadius)
                                            .mask(
                                                CanvasMaskGeometry.path(from: points)
                                                    .stroke(
                                                        Color.white,
                                                        style: StrokeStyle(
                                                            lineWidth: CanvasMaskGeometry.scribbleBrushWidth,
                                                            lineCap: .round,
                                                            lineJoin: .round
                                                        )
                                                    )
                                            )
                                            .allowsHitTesting(false)
                                    }
                                }
                                
                                if scribbleMaskSelected, !currentStroke.isEmpty {
                                    CanvasMaskGeometry.path(from: currentStroke)
                                        .stroke(
                                            Color.blue,
                                            style: StrokeStyle(
                                                lineWidth: 2,
                                                lineCap: .round,
                                                lineJoin: .round,
                                                dash: [6]
                                            )
                                        )
                                }
                                
                                if rectangleMaskSelected,
                                   let start = startPoint,
                                   let end = currentPoint {
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

                                if autoRedactMode {
                                    autoRedactChromeLayer(canvasSize: finalSize)
                                }
                            }
                            .clipped()
                            .optionalSimultaneousGesture(autoRedactMode, autoRedactCanvasTapGesture(canvasSize: finalSize))
                        }
                    }
                    .frame(width: finalSize.width, height: finalSize.height)
                    .onAppear {
                        // not sure this works yet .. double check when time available.
                        lastImageSize = finalSize
                        scheduleVisionScanIfReady()
                    }
                    .onChange(of: outerGeometry.size) { _, _ in
                        lastImageSize = finalSize
                        scheduleVisionScanIfReady()
                    }
                    .gesture((rectangleMaskSelected || scribbleMaskSelected) ? canvasMaskingGesture(size: finalSize) : nil)
                    Spacer()
                }
                .frame(maxWidth: outerGeometry.size.width)
                //.border(Color.green)
            }
            .scaleEffect(scale)
            .offset(offset)
            .gesture(
                SimultaneousGesture(
                    magnificationGesture,
                    dragGesture
                )
            )
        }
    }
}

// MARK: - Snapshot View - Gestures

extension CanvasView {

    /// Single drag gesture so rectangle and scribble masking both receive touches reliably.
    private func canvasMaskingGesture(size: CGSize) -> some Gesture {
        let imageFrame = CGRect(origin: .zero, size: size)
        let scribbleMinSample: CGFloat = 3

        return DragGesture(minimumDistance: 0)
            .onChanged { value in
                if rectangleMaskSelected {
                    if startPoint == nil {
                        startPoint = value.location
                    }
                    currentPoint = value.location
                } else if scribbleMaskSelected {
                    let p = clamp(point: value.location, to: imageFrame)
                    if let last = currentStroke.last {
                        let d = hypot(p.x - last.x, p.y - last.y)
                        guard d >= scribbleMinSample else { return }
                    }
                    currentStroke.append(p)
                }
            }
            .onEnded { _ in
                if rectangleMaskSelected {
                    guard let start = startPoint,
                          let end = currentPoint else {
                        startPoint = nil
                        currentPoint = nil
                        return
                    }

                    let clampedStart = clamp(point: start, to: imageFrame)
                    let clampedEnd = clamp(point: end, to: imageFrame)

                    let rect = CGRect(
                        x: min(clampedStart.x, clampedEnd.x),
                        y: min(clampedStart.y, clampedEnd.y),
                        width: abs(clampedEnd.x - clampedStart.x),
                        height: abs(clampedEnd.y - clampedStart.y)
                    )

                    maskEdits.append(CanvasMaskEdit(kind: .rectangle(rect)))
                    maskEditsRedo.removeAll()
                    startPoint = nil
                    currentPoint = nil
                } else if scribbleMaskSelected {
                    var points = currentStroke
                    currentStroke = []

                    guard !points.isEmpty else { return }

                    if points.count == 1 {
                        points.append(points[0])
                    }

                    maskEdits.append(CanvasMaskEdit(kind: .scribble(points)))
                    maskEditsRedo.removeAll()
                }
            }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = lastScale * value
            }
            .onEnded { _ in
                lastScale = scale
            }
    }
    
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }
}

// MARK: - Auto redact (Vision + layout)

extension CanvasView {

    private func scheduleVisionScanIfReady() {
        guard autoRedactMode, !didRunVisionForCurrentAutoSession, lastImageSize.width > 0, lastImageSize.height > 0 else {
            return
        }
        didRunVisionForCurrentAutoSession = true
        performSensitiveTextScan()
    }

    private func performSensitiveTextScan() {
        let image = uiImage
        let size = lastImageSize
        Task {
            let scanResult = await Task.detached(priority: .userInitiated) {
                SensitiveTextVisionService.scanSensitiveCanvasRects(in: image, canvasSize: size)
            }.value
            await MainActor.run {
                guard autoRedactMode else { return }
                let pad: CGFloat = 6
                let canvasBounds = CGRect(origin: .zero, size: size)
                var firstNewSelection: UUID?
                for rect in scanResult.rects {
                    let expanded = rect.insetBy(dx: -pad, dy: -pad)
                    let clamped = expanded.intersection(canvasBounds)
                    guard clamped.width > 8, clamped.height > 8 else { continue }
                    let edit = CanvasMaskEdit(kind: .rectangle(clamped), isAutoDetected: true)
                    maskEdits.append(edit)
                    if firstNewSelection == nil {
                        firstNewSelection = edit.id
                    }
                }
                guard firstNewSelection != nil else {
                    AlertKitAPI.present(
                        title: "No Sensitive Text Detected",
                        icon: .error,
                        style: .iOS17AppleMusic,
                        haptic: .error
                    )
                    handleAction(for: .autoRedacting(isEnabled: false))
                    HapticFeedbackService.vibrate(.warning)
                    return
                }
                maskEditsRedo.removeAll()
                selectedAutoMaskID = firstNewSelection
                HapticFeedbackService.vibrate(.success)
            }
        }
    }

    @ViewBuilder
    private func autoRedactChromeLayer(canvasSize: CGSize) -> some View {
        if let sid = selectedAutoMaskID,
           let edit = maskEdits.first(where: { $0.id == sid }),
           edit.isAutoDetected,
           case .rectangle(let r) = edit.kind {
            autoRedactSelectionViews(rect: r, maskId: sid, canvasSize: canvasSize)
        }
    }

    @ViewBuilder
    private func autoRedactSelectionViews(rect: CGRect, maskId: UUID, canvasSize: CGSize) -> some View {
        Rectangle()
            .stroke(Color.blue, style: StrokeStyle(lineWidth: 2, dash: [6]))
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
            .allowsHitTesting(false)

        Rectangle()
            .fill(Color.clear)
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
            .contentShape(Rectangle())
            .gesture(autoRedactMoveGesture(maskId: maskId, canvasSize: canvasSize))

        ForEach(Array(AutoResizeCorner.allCases), id: \.self) { corner in
            Circle()
                .fill(Color.white)
                .overlay(Circle().stroke(Color.blue, lineWidth: 2))
                .frame(width: 22, height: 22)
                .position(corner.anchor(in: rect))
                .highPriorityGesture(autoRedactResizeGesture(corner: corner, maskId: maskId, canvasSize: canvasSize))
        }
    }

    private func autoRedactCanvasTapGesture(canvasSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onEnded { value in
                guard autoRedactMode else { return }
                let drag = hypot(value.translation.width, value.translation.height)
                guard drag < 12 else { return }
                handleAutoRedactTap(at: value.startLocation, canvasSize: canvasSize)
            }
    }

    private func autoRedactMoveGesture(maskId: UUID, canvasSize: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                if autoMoveDragBase == nil {
                    autoMoveDragBase = rectForAutoMask(id: maskId)
                }
                guard let base = autoMoveDragBase else { return }
                let proposed = base.offsetBy(dx: value.translation.width, dy: value.translation.height)
                let clamped = clampRedactRect(proposed, canvas: canvasSize)
                replaceAutoMaskRect(id: maskId, with: clamped)
            }
            .onEnded { _ in
                autoMoveDragBase = nil
            }
    }

    private func autoRedactResizeGesture(corner: AutoResizeCorner, maskId: UUID, canvasSize: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                if autoResizeSession == nil {
                    guard let start = rectForAutoMask(id: maskId) else { return }
                    autoResizeSession = (corner, start)
                }
                guard let session = autoResizeSession else { return }
                let next = resizedRect(
                    from: session.startRect,
                    corner: session.corner,
                    translation: value.translation,
                    canvas: canvasSize
                )
                replaceAutoMaskRect(id: maskId, with: next)
            }
            .onEnded { _ in
                autoResizeSession = nil
            }
    }

    private func handleAutoRedactTap(at point: CGPoint, canvasSize: CGSize) {
        let bounds = CGRect(origin: .zero, size: canvasSize)
        guard bounds.contains(point) else {
            selectedAutoMaskID = nil
            return
        }
        for edit in maskEdits.reversed() where edit.isAutoDetected {
            if case .rectangle(let r) = edit.kind, r.contains(point) {
                selectedAutoMaskID = edit.id
                HapticFeedbackService.vibrate(.selection)
                return
            }
        }
        selectedAutoMaskID = nil
    }

    private func rectForAutoMask(id: UUID) -> CGRect? {
        guard let edit = maskEdits.first(where: { $0.id == id }),
              edit.isAutoDetected,
              case .rectangle(let r) = edit.kind else { return nil }
        return r
    }

    private func replaceAutoMaskRect(id: UUID, with newRect: CGRect) {
        guard let index = maskEdits.firstIndex(where: { $0.id == id }) else { return }
        var edit = maskEdits[index]
        guard edit.isAutoDetected else { return }
        guard case .rectangle = edit.kind else { return }
        edit.kind = .rectangle(newRect)
        maskEdits[index] = edit
    }

    private func clampRedactRect(_ rect: CGRect, canvas: CGSize, minSide: CGFloat = 28) -> CGRect {
        var r = rect
        r.size.width = max(r.size.width, minSide)
        r.size.height = max(r.size.height, minSide)
        if r.minX < 0 { r.origin.x = 0 }
        if r.minY < 0 { r.origin.y = 0 }
        if r.maxX > canvas.width {
            r.origin.x = max(0, canvas.width - r.width)
        }
        if r.maxY > canvas.height {
            r.origin.y = max(0, canvas.height - r.height)
        }
        r.size.width = min(r.size.width, canvas.width - r.origin.x)
        r.size.height = min(r.size.height, canvas.height - r.origin.y)
        return r
    }

    private func resizedRect(
        from start: CGRect,
        corner: AutoResizeCorner,
        translation: CGSize,
        canvas: CGSize,
        minSide: CGFloat = 28
    ) -> CGRect {
        let tx = translation.width
        let ty = translation.height
        let r: CGRect
        switch corner {
        case .bottomRight:
            let w = max(minSide, start.width + tx)
            let h = max(minSide, start.height + ty)
            r = CGRect(x: start.minX, y: start.minY, width: w, height: h)
        case .bottomLeft:
            let newMinX = min(start.maxX - minSide, start.minX + tx)
            let h = max(minSide, start.height + ty)
            r = CGRect(x: newMinX, y: start.minY, width: start.maxX - newMinX, height: h)
        case .topRight:
            let newMinY = min(start.maxY - minSide, start.minY + ty)
            let w = max(minSide, start.width + tx)
            r = CGRect(x: start.minX, y: newMinY, width: w, height: start.maxY - newMinY)
        case .topLeft:
            let newMinX = min(start.maxX - minSide, start.minX + tx)
            let newMinY = min(start.maxY - minSide, start.minY + ty)
            r = CGRect(x: newMinX, y: newMinY, width: start.maxX - newMinX, height: start.maxY - newMinY)
        }
        return clampRedactRect(r, canvas: canvas, minSide: minSide)
    }
}

// MARK: - Image action events

fileprivate extension CanvasView {
    
    func handleAction(for events: ControlEvent) {
        switch events {
        case .scribble(let isEnabled):
            scribbleMaskSelected = isEnabled
            if isEnabled {
                rectangleMaskSelected = false
                autoRedactMode = false
                selectedAutoMaskID = nil
                didRunVisionForCurrentAutoSession = false
                startPoint = nil
                currentPoint = nil
            } else {
                currentStroke = []
            }
        case .region(let isEnabled):
            rectangleMaskSelected = isEnabled
            if isEnabled {
                scribbleMaskSelected = false
                autoRedactMode = false
                selectedAutoMaskID = nil
                didRunVisionForCurrentAutoSession = false
                currentStroke = []
            } else {
                startPoint = nil
                currentPoint = nil
            }
        case .autoRedacting(let isEnabled):
            autoRedactMode = isEnabled
            if isEnabled {
                rectangleMaskSelected = false
                scribbleMaskSelected = false
                startPoint = nil
                currentPoint = nil
                currentStroke = []
                maskEdits.removeAll { $0.isAutoDetected }
                maskEditsRedo.removeAll()
                selectedAutoMaskID = nil
                didRunVisionForCurrentAutoSession = false
                scheduleVisionScanIfReady()
            } else {
                selectedAutoMaskID = nil
                didRunVisionForCurrentAutoSession = false
            }
        case .blurIntensityChanged(let blurIntensity):
            blurIntensityRadius = blurIntensity
        case .save:
            print("saving")
        case .trash:
            showTrashAlert = true
        }
    }
    
    /*
     case .saving:
         /*let blurImage = boxBlur(with: uiImage)
         guard let blurImage = blurImage else { return }*/
         guard let finalizedImage = editedImage else { return }

         // called last after all edits.
         saveImageToPhotos(finalizedImage) { error in
             if let error = error {
                 errorPresented = true
                 print("Error saving to camera roll. Error: \(error)")
                 HapticFeedbackService.vibrate(.error)
             } else {
                 print("Saving with blur preset: \(blurIntensityRadius)")
                 alertPresented = true
                 HapticFeedbackService.vibrate(.success)
             }
         }
     case .trash:
     */
}

// MARK: - Mask edits (rectangles + scribble strokes)

fileprivate enum CanvasMaskKind {
    case rectangle(CGRect)
    case scribble([CGPoint])
}

fileprivate struct CanvasMaskEdit: Identifiable {
    let id: UUID
    var kind: CanvasMaskKind
    let isAutoDetected: Bool

    init(id: UUID = UUID(), kind: CanvasMaskKind, isAutoDetected: Bool = false) {
        self.id = id
        self.kind = kind
        self.isAutoDetected = isAutoDetected
    }
}

fileprivate enum CanvasMaskGeometry {
    static let scribbleBrushWidth: CGFloat = 22
    static let scribbleSampleStep: CGFloat = 5

    static func path(from points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for p in points.dropFirst() {
            path.addLine(to: p)
        }
        return path
    }

    /// axis-aligned rects covering a polyline stroke (canvas coordinates).
    static func coverRectsForScribble(points: [CGPoint], brushWidth: CGFloat, step: CGFloat) -> [CGRect] {
        guard !points.isEmpty else { return [] }
        let half = brushWidth / 2
        var rects: [CGRect] = []

        func addRect(at point: CGPoint) {
            rects.append(CGRect(x: point.x - half, y: point.y - half, width: brushWidth, height: brushWidth))
        }

        addRect(at: points[0])
        guard points.count >= 2 else { return rects }

        for i in 1..<points.count {
            let a = points[i - 1]
            let b = points[i]
            let dist = hypot(b.x - a.x, b.y - a.y)
            let steps = max(1, Int(ceil(dist / max(step, 1))))
            for s in 1...steps {
                let t = CGFloat(s) / CGFloat(steps)
                let p = CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
                addRect(at: p)
            }
        }
        return rects
    }

    static func allBlurRects(from edits: [CanvasMaskEdit], scribbleBrushWidth: CGFloat) -> [CGRect] {
        var out: [CGRect] = []
        for edit in edits {
            switch edit.kind {
            case .rectangle(let rect):
                out.append(rect)
            case .scribble(let pts):
                out.append(contentsOf: coverRectsForScribble(points: pts, brushWidth: scribbleBrushWidth, step: scribbleSampleStep))
            }
        }
        return out
    }
}

/// Avoid attaching a zero-distance drag when idle so scribble/region gestures win after auto-redact.
fileprivate extension View {
    @ViewBuilder
    func optionalSimultaneousGesture<G: Gesture>(_ enabled: Bool, _ gesture: G) -> some View {
        if enabled {
            self.simultaneousGesture(gesture)
        } else {
            self
        }
    }
}

#Preview {
    let sampleImage = UIImage(named: "CityNeon") ?? UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1)).image { ctx in ctx.cgContext.setFillColor(UIColor.lightGray.cgColor); ctx.cgContext.fill(CGRect(origin: .zero, size: CGSize(width: 1, height: 1))) }
    CanvasView(image: sampleImage) { _ in }
}
