//
//  ControlView.swift
//  Blurrify
//
//  Created by Neftali Samarey on 5/11/24.
//

import SwiftUI

public enum ControlEvent {
    case scribble(isEnabled: Bool)
    case region(isEnabled: Bool)
    case autoRedacting(isEnabled: Bool)
    case blurIntensityChanged(CGFloat)
    case save
    case trash
}

public enum OverlayStyle {
    case rounded
    case pill
    case none
}

public enum ControlStyle {
    case overlay(style: OverlayStyle)
    case integrated
}

// MARK: - Toolbar Mode

private enum ActiveTool {
    case none
    case scribble
    case region
    case autoRedacting
}

public struct ControlView: View {

    @State private var blurIntensity: CGFloat = 5
    @State private var scribbleWidth: CGFloat = 5       // not being used at the moment
    @State private var activeTool: ActiveTool = .none
    @State private var isShowingBlurSlider = false
    @State private var isShowingScribbleSlider = false  // not being used at the moment

    private let controlStyle: ControlStyle
    private let eventCompletion: (ControlEvent) -> Void
    private let minimumBlur: CGFloat = 0
    private let maximumBlur: CGFloat = 20
    private let mininumWidth: CGFloat = 5               // not being used at the moment
    private let maximumWidth: CGFloat = 20              // not being used at the moment

    public init(
        controlStyle: ControlStyle = .overlay(style: .none),
        eventCompletion: @escaping (ControlEvent) -> Void
    ) {
        self.controlStyle = controlStyle
        self.eventCompletion = eventCompletion
    }

    public var body: some View {
        Group {
            if isShowingBlurSlider {
                blurSliderView
            } else {
                toolbarButtons
            }
        }
        .padding(.horizontal, Constants.horizontalGroupControlPadding)
        .frame(height: Constants.height)
        .background(styleMode)
        .cornerRadius(overlayStyle)
    }
}

// MARK: - Toolbar Content

private extension ControlView {
    var toolbarButtons: some View {
        HStack(spacing: 20) {
            toolbarButton(systemImage: Icon.scribble.systemName,
                          isSelected: activeTool == .scribble
            ) {
                toggleTool(.scribble)
                HapticFeedbackService.vibrate(.selection)
            } onLongPress: {
                if activeTool == .scribble {
                    isShowingScribbleSlider.toggle()
                    HapticFeedbackService.vibrate(.success)
                }
            }

            toolbarButton(
                systemImage: Icon.square.systemName,
                isSelected: activeTool == .region
            ) {
                toggleTool(.region)
                HapticFeedbackService.vibrate(.selection)
            }
            
            // AI
            toolbarButton(
                systemImage: Icon.glimmer.systemName,
                isSelected: activeTool == .autoRedacting
            ) {
                toggleTool(.autoRedacting)
                HapticFeedbackService.vibrate(.selection)
            }

            toolbarButton(
                systemImage: Icon.toggle.systemName
            ) {
                isShowingBlurSlider.toggle()
                HapticFeedbackService.vibrate(.selection)
            }

            Spacer(minLength: 10)

            toolbarButton(
                systemImage: Icon.download.systemName
            ) {
                eventCompletion(.save)
                HapticFeedbackService.vibrate(.success)
            }

            toolbarButton(
                systemImage: Icon.trash.systemName,
                tint: .red
            ) {
                eventCompletion(.trash)
                HapticFeedbackService.vibrate(.warning)
            }
        }
    }

    var blurSliderView: some View {
        HStack(spacing: 15) {
            Button {
                isShowingBlurSlider = false
                HapticFeedbackService.vibrate(.selection)
            } label: {
                Image(systemName: Icon.chevronLeft.systemName)
                    .font(.system(size: 20))
                    .foregroundStyle(.white)
            }

            Slider(
                value: $blurIntensity,
                in: minimumBlur...maximumBlur
            )
            .tint(.white)
            .onChange(of: blurIntensity) { _, newValue in
                eventCompletion(.blurIntensityChanged(newValue))
            }
        }
        .onAppear {
            eventCompletion(.blurIntensityChanged(blurIntensity))
        }
    }
    
    // legacy slider reference
    /*
     HStack(spacing: 25) {
         Slider(value: Binding(get: {
             self.blurIntensity
         }, set: { (newVal) in
             self.blurIntensity = newVal
         }), in: minimumBlur...maxiumBlur)
         .onChange(of: blurIntensity, { _, newValue in
             guard let eventCompletion = eventCompletion else { return }
             eventCompletion(.blurIntensityGauge(newValue))
         })
         .onAppear {
             // sets the initial value for the blur slider (i.e 5).
             eventCompletion?(.blurIntensityGauge(self.blurIntensity))
         }
     }
     */
}

// MARK: - Reusable Button Builder

private extension ControlView {

    @ViewBuilder
    func toolbarButton(
        systemImage: String,
        isSelected: Bool = false,
        tint: Color = .white,
        action: @escaping () -> Void,
        onLongPress: (() -> Void)? = nil
    ) -> some View {

        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 23))
                .foregroundStyle(
                    isSelected ? .blue : tint
                )
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    onLongPress?()
                }
        )
    }
}

// MARK: - Tool Logic

private extension ControlView {

    func toggleTool(_ tool: ActiveTool) {
        let previous = activeTool
        if activeTool == tool {
            activeTool = .none
        } else {
            activeTool = tool
        }

        if previous != activeTool {
            switch previous {
            case .scribble:
                eventCompletion(.scribble(isEnabled: false))
            case .region:
                eventCompletion(.region(isEnabled: false))
            case .autoRedacting:
                eventCompletion(.autoRedacting(isEnabled: false))
            case .none:
                break
            }
        }

        switch tool {
        case .scribble:
            eventCompletion(
                .scribble(isEnabled: activeTool == .scribble)
            )
        case .region:
            eventCompletion(
                .region(isEnabled: activeTool == .region)
            )
        case .autoRedacting:
            eventCompletion(
                .autoRedacting(isEnabled: activeTool == .autoRedacting)
            )
        case .none:
            break
        }
    }
}

// MARK: - Styling

private extension ControlView {
    var styleMode: Color {
        switch controlStyle {
        case .overlay: Color.black.opacity(0.85)
        default: Color.clear
        }
    }

    var overlayStyle: CGFloat {
        switch controlStyle {
        case .overlay(style: .pill): return Constants.height / 2
        default: return 0
        }
    }
}

// MARK: - Constants

private extension ControlView {
    enum Constants {
        static let height: CGFloat = 65
        static let horizontalGroupControlPadding: CGFloat = 17.5
    }
}

#Preview {
    ControlView { _ in }
}
