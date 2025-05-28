//
//  ControlView.swift
//  Blurrify
//
//  Created by Neftali Samarey on 5/11/24.
//

import SwiftUI

public enum ControlEvent {
    case scribble
    case region
    case fullBlur(CGFloat)
    case saving
    case trash
}

public struct ControlView: View {

    @State private var blurIntensity: CGFloat = 5
    @State private var isFullBlurSelected: Bool = false
    @State private var isScribbleSelected: Bool = false
    @State private var isShowingSliderItem: Bool = false

    var eventCompletion: ((ControlEvent) -> Void)?
    let minimumBlur: CGFloat = 0
    let maxiumBlur: CGFloat = 20

    public init(eventCompletion: ((ControlEvent) -> Void)? = nil) {
        self.eventCompletion = eventCompletion
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 15) {
            Spacer()
            mainToolbarSelectionView
            Spacer()
            Button {
                guard let eventCompletion = eventCompletion else { return }
                eventCompletion(.saving)
            } label: {
                Image(systemName: "square.and.arrow.down")
                    .foregroundStyle(.white)
                    .font(.system(size: 23.0))
            }
            Button {
                guard let eventCompletion = eventCompletion else { return }
                eventCompletion(.trash)
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.white)
                    .font(.system(size: 23.0))
            }
            Spacer()
        }
        .frame(height: 65)
        .background(Color.black.opacity(0.6))
        .cornerRadius(10)
        .padding(.leading, 20)
        .padding(.trailing, 20)
        .padding(.bottom, 45)
    }

    // MARK: - Toolbar items
    @ViewBuilder
    private var mainToolbarSelectionView: some View {
        if !isShowingSliderItem {
            HStack(alignment: .center, spacing: 35) {
                // scribble
                Button {
                    isFullBlurSelected = false
                    isScribbleSelected.toggle()
                    isShowingSliderItem = false

                    guard let eventCompletion = eventCompletion else { return }
                    eventCompletion(.scribble)
                } label: {
                    Image(systemName: "scribble.variable")
                        .foregroundStyle(isScribbleSelected ? .blue : .white)
                        .font(.system(size: 23.0))
                }

                // region
                Button {
                    isFullBlurSelected.toggle()
                    isScribbleSelected = false
                    isShowingSliderItem = false

                    guard let eventCompletion = eventCompletion else { return }
                    eventCompletion(.region)
                } label: {
                    Image(systemName: "square")
                        .foregroundStyle(isFullBlurSelected ? .blue : .white)
                        .font(.system(size: 23.0))
                }

                // whole screen
                Button {
                    isShowingSliderItem.toggle()
                } label: {
                    Image(systemName: "switch.2")
                        .foregroundStyle(.white)
                        .font(.system(size: 23.0))
                }
            }
            .frame(maxWidth: .infinity)
        } else {
            // back button
            Button {
                isShowingSliderItem.toggle()
            } label: {
                Image(systemName: "chevron.left")
                    .foregroundStyle(.white)
                    .font(.system(size: 23.0))
            }

            // slider
            HStack(spacing: 25) {
                Slider(value: Binding(get: {
                    self.blurIntensity
                }, set: { (newVal) in
                    self.blurIntensity = newVal
                    guard let eventCompletion = eventCompletion else { return }
                    eventCompletion(.fullBlur(self.blurIntensity))
                }), in: minimumBlur...maxiumBlur)
                .onAppear {
                    // sets the initial value for the blur slider (i.e 5).
                    eventCompletion?(.fullBlur(self.blurIntensity))
                }
            }
        }
    }
}


#Preview {
    ControlView { event in
        // intentionally empty
    }
}
