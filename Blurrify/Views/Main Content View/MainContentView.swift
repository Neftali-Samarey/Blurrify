//
//  ContentView.swift
//  Blurrify
//
//  Created by Neftali Samarey on 4/26/24.
//

import SwiftUI
import PhotosUI
import AlertKit

struct MainContentView: View {

    @Environment(\.colorScheme) var colorScheme

    @State private var pickerItem: PhotosPickerItem?
    @State private var selectedImage: Image?
    @State private var imageToSave: UIImage?
    @State private var shouldLoadControls: Bool = false
    @State private var showingAlert = false
    @State private var showingSavedAlert = true
    @State private var blurRadius: CGFloat = 0.0

    let alertView = AlertAppleMusic17View(title: "Saved to Photo Album", subtitle: nil, icon: .done)
    let imageSaver = ImageSaver()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        VStack(alignment: .center) {
                            Image(systemName: "photo.badge.plus")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 40.0, height: 40.0)
                                .tint(colorScheme == .dark ? Color.white : Color.primaryBlue)
                            Text("Select Image")
                                .font(.headline)
                                .padding(.top, 5)
                        }
                        .padding([.top, .bottom], 70)
                        .padding([.leading, .trailing], 60)
                    }
                }
                .dottedBorder(colorScheme == .dark ? Color.white : Color.primaryBlue.opacity(0.5))

                // This is the overlay view
                selectedImage?
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .blur(radius: blurRadius, opaque: true)
                    .onAppear(perform: {
                        guard selectedImage != nil else {
                            return
                        }

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.0) {
                            // TODO: - Animate slide up
                            withAnimation {
                                self.shouldLoadControls = true
                            }
                        }
                    })

                if shouldLoadControls {
                    VStack {
                        Spacer()
                        ControlView { isSaving, blurIntensity, isDeleting  in
                            if let _ = isSaving {
                                guard let image = selectedImage else { return }
                                convert(image: image) { editedImage in
                                    guard let convertedImage = editedImage else { return }

                                    let test = convertedImage.blurredImageWithClippedEdges(inputRadius: blurRadius)
                                    guard let image = test else { return }
                                    save(image: image)

                                    //let uiImage = CIImage(image: convertedImage)

                                    // Convert CIImage to UIImage
                                    /*let context = CIContext()
                                    if let blurredUIImage = blurredImage.flatMap({
                                        context.createCGImage($0, from: $0.extent)
                                    }).flatMap({
                                        UIImage(cgImage: $0)
                                    }) {
                                        self.imageToSave = blurredUIImage

                                        // Save the blurred image to the photo library
                                        UIImageWriteToSavedPhotosAlbum(blurredUIImage, nil, nil, nil)
                                    }*/
                                }
                                //guard let uiImage = self.selectedImage?.uiImage else { return }
                            }

                            if let isDeleting = isDeleting {
                                showingAlert = isDeleting
                            }

                            if let blurIntensity = blurIntensity {
                                blurRadius = blurIntensity
                            }
                        }
                            //.alert(isPresent: $showingSavedAlert, view: alertView)
                    }
                    .alert("Start all over?", isPresented: $showingAlert) {
                        // delete
                        Button("Delete", role: .destructive) {
                            clear()
                            DispatchQueue.main.async {
                                withAnimation {
                                    // TODO: - Animate slide down
                                    self.shouldLoadControls = false
                                }
                            }
                        }

                        // cancel
                        Button("Cancel", role: .cancel) { }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onChange(of: pickerItem) {
                Task {
                    selectedImage = try await pickerItem?.loadTransferable(type: Image.self)
                }
            }
            .edgesIgnoringSafeArea(.all)
        }
        .background(colorScheme == .dark ? Color.backgroundDarkBlue : Color.white)
    }

    private func clear() {
        self.blurRadius = 0.0
        self.pickerItem = nil
        self.selectedImage = nil
    }

    private func save(image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
    }

    public func convert(image: Image, callback: @escaping ((UIImage?) -> Void)) {
        DispatchQueue.main.async {
            let renderer = ImageRenderer(content: image)

            // to adjust the size, you can use this (or set a frame to get precise output size)
            // renderer.scale = 0.25

            // for CGImage use renderer.cgImage
            callback(renderer.uiImage)
        }
    }

    func getImageWithBlur(image: UIImage) -> UIImage? {

        let context = CIContext(options: nil)

        guard let currentFilter = CIFilter(name: "CIGaussianBlur") else { return nil }

        let beginImage = CIImage(image: image)
        currentFilter.setValue(beginImage, forKey: kCIInputImageKey)
        currentFilter.setValue(6.5, forKey: "inputRadius")

        let rect = CGRect(x: 0.0, y: 0.0, width: image.size.width, height: image.size.height)

        guard let output = currentFilter.outputImage?.unpremultiplyingAlpha().settingAlphaOne(in: rect) else { return nil }
        guard let cgimg = context.createCGImage(output, from: rect) else { return nil }

        print("image.size:    \(image.size)")
        print("output.extent: \(output.extent)")

        return UIImage(cgImage: cgimg)

    }

//    private func didSelectToSave() -> Bool {
//        
//    }
}

#Preview {
    MainContentView()
}
