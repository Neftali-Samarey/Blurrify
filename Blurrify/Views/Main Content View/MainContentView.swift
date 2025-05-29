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
    @State private var selectedUIImage: UIImage?
    @State private var uiImageSize: CGSize = CGSize(width: 0, height: 0)

    var body: some View {
        NavigationStack {
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
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .edgesIgnoringSafeArea(.all)
            .navigationDestination(isPresented: Binding(
                get: { selectedUIImage != nil },
                set: { newValue in
                    if !newValue { selectedUIImage = nil }
                }
            )) {
                if let selectedImage = selectedUIImage {
                    CanvasContentView(image: selectedImage) { event in
                        switch event {
                        case .trash:
                            clear()
                        default: break
                        }
                    }
                }
            }
            .onChange(of: pickerItem) {
                Task {
                    if let data = try? await pickerItem?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        uiImageSize = uiImage.size
                        let fixedUIImage = uiImage.normalizedImage()
                        selectedUIImage = fixedUIImage
                    }
                }
            }
            .background(colorScheme == .dark ? Color.backgroundDarkBlue : Color.white)
        }
    }

    private func clear() {
        self.pickerItem = nil
        self.selectedUIImage = nil
    }
}
