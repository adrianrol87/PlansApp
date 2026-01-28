//
//  ZoomablePDFImageView.swift
//  PlansApp
//
//  Created by Adrian Rodriguez Llorens on 27/01/26.
//

import SwiftUI
import UIKit

struct ZoomablePDFImageView: UIViewRepresentable {
    let image: UIImage
    let pins: [Pin]
    let selectedPinID: UUID?

    var onTapInImageSpace: (CGPoint) -> Void
    var onSelectPin: (UUID) -> Void

    func makeUIView(context: Context) -> UIScrollView {
        let scroll = UIScrollView()
        scroll.delegate = context.coordinator
        scroll.minimumZoomScale = 1.0
        scroll.maximumZoomScale = 8.0
        scroll.bouncesZoom = true
        scroll.showsVerticalScrollIndicator = false
        scroll.showsHorizontalScrollIndicator = false

        let imageView = UIImageView(image: image)
        imageView.isUserInteractionEnabled = true
        imageView.contentMode = .scaleAspectFit
        imageView.frame = CGRect(origin: .zero, size: image.size)

        let overlay = PinOverlayView(frame: imageView.bounds)
        overlay.backgroundColor = .clear
        overlay.isUserInteractionEnabled = true

        overlay.selectedPinID = selectedPinID
        overlay.onSelectPin = { id in
            onSelectPin(id)
        }

        imageView.addSubview(overlay)
        scroll.addSubview(imageView)
        scroll.contentSize = image.size

        // Tap para AGREGAR pin (pero NO cuando tocas un pin existente)
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tap.delegate = context.coordinator
        tap.cancelsTouchesInView = false
        imageView.addGestureRecognizer(tap)

        context.coordinator.imageView = imageView
        context.coordinator.overlay = overlay
        context.coordinator.onTap = onTapInImageSpace

        overlay.setPins(pins, imageSize: image.size)

        return scroll
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        guard let imageView = context.coordinator.imageView,
              let overlay = context.coordinator.overlay else { return }

        overlay.frame = imageView.bounds
        overlay.selectedPinID = selectedPinID
        overlay.onSelectPin = { id in
            onSelectPin(id)
        }
        overlay.setPins(pins, imageSize: image.size)

        uiView.contentSize = image.size
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, UIScrollViewDelegate, UIGestureRecognizerDelegate {
        weak var imageView: UIImageView?
        weak var overlay: PinOverlayView?
        var onTap: ((CGPoint) -> Void)?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

        // ✅ CLAVE: si el toque cae en un UIControl (pin), NO dispares "agregar pin"
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            // Si tocaste un pin (UIControl) o algo dentro de él, ignorar el gesto
            var v: UIView? = touch.view
            while let current = v {
                if current is UIControl { return false }
                v = current.superview
            }
            return true
        }

        @objc func handleTap(_ sender: UITapGestureRecognizer) {
            guard let iv = imageView else { return }
            let p = sender.location(in: iv) // pixeles de la imagen
            onTap?(p)
        }
    }
}
