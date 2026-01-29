//
//  FullscreenPhotoView.swift
//  PlansApp
//
//  Created by Adrian Rodriguez Llorens on 28/01/26.
//

import SwiftUI
import UIKit

struct FullscreenPhotoView: View {
    let image: UIImage
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            // La foto centrada con zoom/pan básico via ScrollView
            ScrollView([.horizontal, .vertical]) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 70) // ✅ deja espacio para la barra superior
                    .padding(.bottom, 20)
            }

            // ✅ Barra superior fuera de la foto (la X ya no tapa)
            HStack {
                Spacer()
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
        }
    }
}

