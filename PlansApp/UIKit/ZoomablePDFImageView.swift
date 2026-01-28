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

    /// Coordenada normalizada del pin seleccionado (0...1). Si nil, no centra.
    let selectedPinNormalizedPoint: CGPoint?

    var onTapInImageSpace: (CGPoint) -> Void
    var onSelectPin: (UUID) -> Void
    var onEditPin: (UUID) -> Void
    var onPinScaleCommit: (UUID, CGFloat) -> Void

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

        // ✅ mejor respuesta de gestos en subviews
        scroll.delaysContentTouches = false
        scroll.canCancelContentTouches = true

        let imageView = UIImageView(image: image)
        imageView.isUserInteractionEnabled = true
        imageView.contentMode = .scaleAspectFit
        imageView.frame = CGRect(origin: .zero, size: image.size)

        let overlay = PinOverlayView(frame: imageView.bounds)
        overlay.backgroundColor = .clear
        overlay.isUserInteractionEnabled = true

        overlay.selectedPinID = selectedPinID
        overlay.onSelectPin = onSelectPin
        overlay.onEditPin = onEditPin
        overlay.onPinScaleCommit = onPinScaleCommit

        imageView.addSubview(overlay)
        scroll.addSubview(imageView)
        scroll.contentSize = image.size

        // Tap para agregar pin (pero NO si tocaste un pin)
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tap.delegate = context.coordinator
        tap.cancelsTouchesInView = false
        imageView.addGestureRecognizer(tap)

        context.coordinator.scrollView = scroll
        context.coordinator.imageView = imageView
        context.coordinator.overlay = overlay
        context.coordinator.onTap = onTapInImageSpace
        context.coordinator.lastImageSize = image.size
        context.coordinator.lastSelectedPinID = selectedPinID

        overlay.setPins(pins, imageSize: image.size)

        DispatchQueue.main.async {
            context.coordinator.configureZoomIfNeeded(for: image.size, reset: true)
            context.coordinator.centerContent()
            context.coordinator.applySelectionLock(selectedPinID: selectedPinID)

            if let norm = selectedPinNormalizedPoint {
                context.coordinator.centerOnNormalizedPoint(norm, animated: false)
            }
        }

        return scroll
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        guard let imageView = context.coordinator.imageView,
              let overlay = context.coordinator.overlay else { return }

        // ✅ lock/unlock cuando cambia selección
        context.coordinator.applySelectionLock(selectedPinID: selectedPinID)

        let newSize = image.size

        if context.coordinator.lastImageSize != newSize {
            imageView.image = image
            imageView.frame = CGRect(origin: .zero, size: newSize)
            uiView.contentSize = newSize

            context.coordinator.lastImageSize = newSize
            context.coordinator.didInitialFit = false

            DispatchQueue.main.async {
                context.coordinator.configureZoomIfNeeded(for: newSize, reset: true)
                context.coordinator.centerContent()
            }
        } else {
            uiView.contentSize = newSize
        }

        overlay.frame = imageView.bounds
        overlay.selectedPinID = selectedPinID
        overlay.onSelectPin = onSelectPin
        overlay.onEditPin = onEditPin
        overlay.onPinScaleCommit = onPinScaleCommit
        overlay.setPins(pins, imageSize: newSize)

        // ✅ si cambió el pin seleccionado, centra automáticamente
        if context.coordinator.lastSelectedPinID != selectedPinID {
            context.coordinator.lastSelectedPinID = selectedPinID
            if let norm = selectedPinNormalizedPoint {
                DispatchQueue.main.async {
                    context.coordinator.centerOnNormalizedPoint(norm, animated: true)
                }
            }
        }

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

        var lastSelectedPinID: UUID?

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

            let fitScale = min(boundsSize.width / imageSize.width, boundsSize.height / imageSize.height)
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

        /// ✅ Cuando hay pin seleccionado: bloquea COMPLETAMENTE el scroll (pan y pinch del PDF)
        func applySelectionLock(selectedPinID: UUID?) {
            guard let scrollView else { return }

            let locked = (selectedPinID != nil)

            // Bloquea arrastre y zoom del PDF (para que el pinch sea del pin)
            scrollView.isScrollEnabled = !locked
            scrollView.pinchGestureRecognizer?.isEnabled = !locked
        }

        /// ✅ Centra el PDF en el punto normalizado del pin seleccionado
        func centerOnNormalizedPoint(_ normalized: CGPoint, animated: Bool) {
            guard let scrollView, let imageView else { return }

            let imgSize = imageView.bounds.size
            guard imgSize.width > 0, imgSize.height > 0 else { return }

            // Punto en coordenadas de la imagen (antes de zoom)
            let pointInImage = CGPoint(x: normalized.x * imgSize.width,
                                       y: normalized.y * imgSize.height)

            // Coordenadas en el contenido actual (considera zoomScale)
            let z = scrollView.zoomScale
            let pointScaled = CGPoint(x: pointInImage.x * z, y: pointInImage.y * z)

            let bounds = scrollView.bounds.size
            let inset = scrollView.contentInset
            let content = scrollView.contentSize

            var targetX = pointScaled.x - bounds.width / 2
            var targetY = pointScaled.y - bounds.height / 2

            // Clamp con insets
            let minX = -inset.left
            let minY = -inset.top
            let maxX = max(content.width - bounds.width + inset.right, minX)
            let maxY = max(content.height - bounds.height + inset.bottom, minY)

            targetX = min(max(targetX, minX), maxX)
            targetY = min(max(targetY, minY), maxY)

            scrollView.setContentOffset(CGPoint(x: targetX, y: targetY), animated: animated)
        }

        // No agregar pin si tocaste un pin
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            var v: UIView? = touch.view
            while let current = v {
                if current is UIControl { return false }
                if String(describing: type(of: current)).contains("PinControl") { return false }
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


