//
//  ContentView.swift
//  Blurrify
//
//  Created by Neftali Samarey on 4/26/24.
//

import SwiftUI
import PhotosUI

struct ContentView: View {

    @State private var pickerItem: PhotosPickerItem?
    @State private var selectedImage: Image?
    @State private var shouldLoadControls: Bool = false
    @State private var showingAlert = false
    @State private var blurRadius: CGFloat = 0.0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        VStack(alignment: .center) {
                            Image(systemName: "photo.badge.plus")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 55.0, height: 55.0)
                                .tint(Color.primaryBlue)
                            Text("Select Image")
                                .font(.headline)
                                .padding(.top, 5)
                        }
                        .padding([.top, .bottom], 70)
                        .padding([.leading, .trailing], 60)
                    }
                }
                .dottedBorder(Color.primaryBlue.opacity(0.5))

                /*PhotosPicker("Selection", selection: $pickerItem, matching: .images)
                    .frame(width: geometry.size.width, height: geometry.size.height)*/

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
                            if let isSaving = isSaving {
                                //
                            }

                            if let isDeleting = isDeleting {
                                showingAlert = isDeleting
                            }

                            if let blurIntensity = blurIntensity {
                                blurRadius = blurIntensity
                            }
                        }
                            .frame(height: 65)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(10)
                            .padding(.leading, 20)
                            .padding(.trailing, 20)
                            .padding(.bottom, 45)
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
    }

    private func clear() {
        self.blurRadius = 0.0
        self.pickerItem = nil
        self.selectedImage = nil
    }
}

public struct ControlView: View {

    @State private var blurIntensity: CGFloat = 0
    var completion: ((Bool?, Double?, Bool?) -> Void)?
    let minimumBlur: CGFloat = 0
    let maxiumBlur: CGFloat = 75

    init(completion: ((Bool?, Double?, Bool?) -> Void)? = nil) {
        self.completion = completion
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 15) {
            Spacer()
            Slider(value: Binding(get: {
                self.blurIntensity
            }, set: { (newVal) in
                self.blurIntensity = newVal
                guard let completion = completion else { return }
                completion(nil, self.blurIntensity, nil)
            }), in: minimumBlur...maxiumBlur)
            Spacer()
            Button {
                guard let completion = completion else { return }
                completion(true, nil, nil)
            } label: {
                Image(systemName: "square.and.arrow.down")
                    .foregroundStyle(.white)
                    .font(.system(size: 23.0))
            }
            Button {
                guard let completion = completion else { return }
                completion(nil, nil, true)
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.white)
                    .font(.system(size: 23.0))
            }
            Spacer()
        }
    }
}

#Preview {
    ContentView()
}
