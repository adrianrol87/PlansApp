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

        scroll.minimumZoomScale = 0.1
        scroll.maximumZoomScale = 8.0
        scroll.bouncesZoom = true
        scroll.showsVerticalScrollIndicator = false
        scroll.showsHorizontalScrollIndicator = false
        scroll.alwaysBounceVertical = false
        scroll.alwaysBounceHorizontal = false

        let imageView = UIImageView(image: image)
        imageView.isUserInteractionEnabled = true
        imageView.contentMode = .scaleAspectFit
        imageView.frame = CGRect(origin: .zero, size: image.size)

        let overlay = PinOverlayView(frame: imageView.bounds)
        overlay.backgroundColor = .clear
        overlay.isUserInteractionEnabled = true
        overlay.selectedPinID = selectedPinID
        overlay.onSelectPin = { id in onSelectPin(id) }

        imageView.addSubview(overlay)
        scroll.addSubview(imageView)
        scroll.contentSize = image.size

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tap.delegate = context.coordinator
        tap.cancelsTouchesInView = false
        imageView.addGestureRecognizer(tap)

        context.coordinator.scrollView = scroll
        context.coordinator.imageView = imageView
        context.coordinator.overlay = overlay
        context.coordinator.onTap = onTapInImageSpace
        context.coordinator.lastImageSize = image.size

        overlay.setPins(pins, imageSize: image.size)

        DispatchQueue.main.async {
            context.coordinator.configureZoomIfNeeded(for: image.size, reset: true)
            context.coordinator.centerContent()
        }

        return scroll
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        guard let imageView = context.coordinator.imageView,
              let overlay = context.coordinator.overlay else { return }

        // ✅ 1) Si cambió la imagen (nuevo PDF render), actualiza el UIImageView
        let newSize = image.size
        let imageChanged = (context.coordinator.lastImageSize != newSize)

        if imageChanged {
            imageView.image = image
            imageView.frame = CGRect(origin: .zero, size: newSize)
            uiView.contentSize = newSize

            // Nuevo plano = re-fit + centrar
            context.coordinator.lastImageSize = newSize
            context.coordinator.didInitialFit = false

            DispatchQueue.main.async {
                context.coordinator.configureZoomIfNeeded(for: newSize, reset: true)
                context.coordinator.centerContent()
            }
        } else {
            // Si no cambió, asegura contentSize correcto
            uiView.contentSize = newSize
        }

        // ✅ 2) Actualiza overlay/pins/highlight siempre
        overlay.frame = imageView.bounds
        overlay.selectedPinID = selectedPinID
        overlay.onSelectPin = { id in onSelectPin(id) }
        overlay.setPins(pins, imageSize: newSize)

        // ✅ 3) Si cambió tamaño de pantalla (rotación), recalcula
        context.coordinator.configureZoomIfNeeded(for: newSize, reset: false)
        context.coordinator.centerContent()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, UIScrollViewDelegate, UIGestureRecognizerDelegate {
        weak var scrollView: UIScrollView?
        weak var imageView: UIImageView?
        weak var overlay: PinOverlayView?

        var onTap: ((CGPoint) -> Void)?

        var lastBoundsSize: CGSize = .zero
        var lastImageSize: CGSize = .zero
        var didInitialFit = false

        func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerContent()
        }

        func configureZoomIfNeeded(for imageSize: CGSize, reset: Bool) {
            guard let scrollView else { return }
            let boundsSize = scrollView.bounds.size
            guard boundsSize.width > 0, boundsSize.height > 0,
                  imageSize.width > 0, imageSize.height > 0 else { return }

            if !reset, boundsSize == lastBoundsSize { return }
            lastBoundsSize = boundsSize

            let scaleX = boundsSize.width / imageSize.width
            let scaleY = boundsSize.height / imageSize.height
            let fitScale = min(scaleX, scaleY)

            let minScale = max(fitScale * 0.5, 0.05)
            let maxScale = max(fitScale * 8.0, 8.0)

            scrollView.minimumZoomScale = minScale
            scrollView.maximumZoomScale = maxScale

            if reset || !didInitialFit {
                scrollView.zoomScale = fitScale
                didInitialFit = true
            } else {
                let clamped = min(max(scrollView.zoomScale, minScale), maxScale)
                if clamped != scrollView.zoomScale {
                    scrollView.zoomScale = clamped
                }
            }
        }

        func centerContent() {
            guard let scrollView, let imageView else { return }

            let boundsSize = scrollView.bounds.size
            let contentSize = imageView.frame.size

            let offsetX = max((boundsSize.width - contentSize.width) * 0.5, 0)
            let offsetY = max((boundsSize.height - contentSize.height) * 0.5, 0)

            scrollView.contentInset = UIEdgeInsets(top: offsetY, left: offsetX, bottom: offsetY, right: offsetX)
        }

        // No agregar pin si tocas un pin existente
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            var v: UIView? = touch.view
            while let current = v {
                if current is UIControl { return false }
                v = current.superview
            }
            return true
        }

        @objc func handleTap(_ sender: UITapGestureRecognizer) {
            guard let iv = imageView else { return }
            let p = sender.location(in: iv)
            onTap?(p)
        }
    }
}


