//
//  BackdropView.swift
//  Blurrify
//
//  Created by Neftali Samarey on 5/28/25.
//
import SwiftUI
import UIKit

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
