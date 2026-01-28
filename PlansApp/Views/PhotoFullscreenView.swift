//
//  PhotoFullscreenView.swift
//  PlansApp
//
//  Created by Adrian Rodriguez Llorens on 27/01/26.
//

import SwiftUI

struct PhotoFullscreenView: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Barra superior (segura para el botón cerrar)
            HStack {
                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(Color.black.opacity(0.7))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(Color.black)
            .ignoresSafeArea(edges: .top)

            // Contenido
            ZStack {
                Color.black.ignoresSafeArea()

                ZoomableImage(image: image)
            }
        }
        .background(Color.black)
    }
}

// MARK: - Zoomable Image
private struct ZoomableImage: View {
    let image: UIImage

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .scaleEffect(scale)
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        scale = lastScale * value
                    }
                    .onEnded { _ in
                        // límites de zoom
                        scale = min(max(scale, 1), 6)
                        lastScale = scale
                    }
            )
            .onTapGesture(count: 2) {
                withAnimation(.easeInOut) {
                    scale = scale > 1 ? 1 : 3
                    lastScale = scale
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
