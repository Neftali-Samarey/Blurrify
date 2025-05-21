//
//  ControlView.swift
//  Blurrify
//
//  Created by Neftali Samarey on 5/11/24.
//

import SwiftUI

public struct ControlView: View {

    @State private var blurIntensity: CGFloat = 0
    var completion: ((Bool?, Double?, Bool?) -> Void)?
    let minimumBlur: CGFloat = 0
    let maxiumBlur: CGFloat = 75

    public init(completion: ((Bool?, Double?, Bool?) -> Void)? = nil) {
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
        .frame(height: 65)
        .background(Color.black.opacity(0.6))
        .cornerRadius(10)
        .padding(.leading, 20)
        .padding(.trailing, 20)
        .padding(.bottom, 45)
    }
}


#Preview {
    ControlView()
}
