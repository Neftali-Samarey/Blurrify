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
    @State private var uiImageSize: CGSize = .zero
    @State private var isLogoTapped: Bool = false

    var body: some View {
        NavigationStack {
            VStack {
                ZStack {
                    VStack {
                        PhotosPicker(selection: $pickerItem, matching: .images) {
                            VStack(alignment: .center) {
                                Image(systemName: Icon.addImage.systemName)
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
                    .dottedBorder(colorScheme == .dark ? Color.primaryWhite : Color.primaryBlue.opacity(0.5))
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
                        CanvasView(image: selectedImage) { event in
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

                footerInformation
            }
            .background(colorScheme == .dark ? Color.backgroundDarkBlue : Color.white)
        }
    }

    private func clear() {
        self.pickerItem = nil
        self.selectedUIImage = nil
    }
}

fileprivate extension MainContentView {
    
    var appLabel: some View {
        VStack(spacing: 1) {
            Image("westie_logo")
                .resizable()
                .scaledToFit()
                .frame(width: 55, height: 55)
                .foregroundStyle(.primary)
                .onTapGesture {
                    isLogoTapped.toggle()
                    HapticFeedbackService.vibrate(.selection)
                }

            HStack(spacing: 1) {
                if isLogoTapped {
                    Text("Neftali Samarey")
                        .font(.system(size: 14, weight: .bold, design: .default))
                    Text(" | NYC")
                        .font(.system(size: 14, weight: .regular, design: .default))
                } else {
                    Text("Scottie")
                        .font(.system(size: 14, weight: .bold, design: .default))

                    Text("Interactive")
                        .font(.system(size: 14, weight: .regular, design: .default))
                }
            }
        }
    }
    
    @ViewBuilder
    var releaseVersionInfoText: some View {
        if let releaseVersionNumber = Bundle.main.releaseVersionNumber {
            Text("v\(releaseVersionNumber)")
                .font(.footnote)
        }
    }
    
    var footerInformation: some View {
        VStack(spacing: 5) {
            appLabel
            releaseVersionInfoText
        }
        .accessibilityHidden(true)
    }
}
