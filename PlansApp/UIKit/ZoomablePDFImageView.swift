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
    let selectedPinNormalizedPoint: CGPoint?

    let onTapInImageSpace: (CGPoint) -> Void
    let onSelectPin: (UUID) -> Void
    let onEditPin: (UUID) -> Void
    let onPinScaleCommit: (UUID, CGFloat) -> Void
    let onMovePinCommit: (UUID, CGFloat, CGFloat) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UIScrollView {
        let scroll = UIScrollView()
        scroll.delegate = context.coordinator
        scroll.bouncesZoom = true
        scroll.showsHorizontalScrollIndicator = false
        scroll.showsVerticalScrollIndicator = false
        scroll.alwaysBounceVertical = false
        scroll.alwaysBounceHorizontal = false

        // valores iniciales (se ajustan cuando sepamos bounds)
        scroll.minimumZoomScale = 1
        scroll.maximumZoomScale = 6

        context.coordinator.scrollView = scroll

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        scroll.addSubview(imageView)
        context.coordinator.imageView = imageView

        let overlay = PinOverlayView()
        overlay.backgroundColor = .clear
        overlay.isUserInteractionEnabled = true
        imageView.addSubview(overlay)
        context.coordinator.overlay = overlay

        overlay.onSelectPin = { id in onSelectPin(id) }
        overlay.onEditPin = { id in onEditPin(id) }
        overlay.onPinScaleCommit = { id, scale in onPinScaleCommit(id, scale) }
        overlay.onMovePinCommit = { id, nx, ny in onMovePinCommit(id, nx, ny) }

        // ✅ Tap: capturado en overlay (espacio exacto de los pines)
        let tapOnOverlay = UITapGestureRecognizer(target: context.coordinator,
                                                  action: #selector(Coordinator.handleOverlayTap(_:)))
        tapOnOverlay.cancelsTouchesInView = false
        overlay.addGestureRecognizer(tapOnOverlay)

        return scroll
    }

    func updateUIView(_ scroll: UIScrollView, context: Context) {
        guard let imageView = context.coordinator.imageView,
              let overlay = context.coordinator.overlay else { return }

        // ✅ 1) Solo actualizar layout “duro” si cambió la imagen o cambió bounds
        context.coordinator.ensureLayout(scroll: scroll, imageView: imageView, overlay: overlay, image: image)

        // ✅ 2) Pins: solo reconstruir si cambiaron
        let snapshot = pins.map {
            PinSnapshot(id: $0.id, x: $0.x, y: $0.y, scale: $0.pinScale, type: $0.type.rawValue)
        }
        if snapshot != context.coordinator.lastPinsSnapshot {
            overlay.setPins(pins, imageSize: image.size)
            context.coordinator.lastPinsSnapshot = snapshot
        }

        // ✅ 3) Selección sin tocar zoom/layout
        overlay.selectedPinID = selectedPinID

        // ✅ 4) Auto-centrado solo si pin fuera de vista (y sin tocar minZoom)
        context.coordinator.maybeCenterOnSelectedPin(
            selectedID: selectedPinID,
            normalizedPoint: selectedPinNormalizedPoint
        )
    }

    // MARK: - Snapshot
    struct PinSnapshot: Equatable {
        let id: UUID
        let x: CGFloat
        let y: CGFloat
        let scale: CGFloat
        let type: String
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        var parent: ZoomablePDFImageView

        weak var scrollView: UIScrollView?
        weak var imageView: UIImageView?
        weak var overlay: PinOverlayView?

        var lastPinsSnapshot: [PinSnapshot] = []

        // ✅ Estado estable
        private var lastImageRef: UIImage?
        private var lastImageSize: CGSize = .zero
        private var lastScrollBounds: CGSize = .zero

        // min zoom “base” fijo por imagen
        private var baseMinZoom: CGFloat?
        private var didApplyInitialFit = false

        // para no centrar repetidamente
        private var lastAutoCenteredPinID: UUID?

        init(_ parent: ZoomablePDFImageView) { self.parent = parent }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerContentIfNeeded(scrollView)
        }

        // ✅ Tap (overlay)
        @objc func handleOverlayTap(_ g: UITapGestureRecognizer) {
            guard let overlay else { return }
            let p = g.location(in: overlay)
            parent.onTapInImageSpace(p)
        }

        // ✅ Layout/fit estable: solo cuando cambia imagen o bounds
        func ensureLayout(scroll: UIScrollView, imageView: UIImageView, overlay: PinOverlayView, image: UIImage) {
            let boundsSize = scroll.bounds.size
            let imageSize = image.size

            let imageChanged = (lastImageRef !== image) || (lastImageSize != imageSize)
            let boundsChanged = (lastScrollBounds != boundsSize)

            // 1) Si cambió imagen: reset de estado y aplicar fit
            if imageChanged {
                lastImageRef = image
                lastImageSize = imageSize
                lastAutoCenteredPinID = nil
                didApplyInitialFit = false
                baseMinZoom = nil

                imageView.image = image

                // Layout base del contenido (solo cuando cambia imagen)
                imageView.frame = CGRect(origin: .zero, size: imageSize)
                overlay.frame = CGRect(origin: .zero, size: imageSize)
                scroll.contentSize = imageSize
            }

            // 2) Si cambió bounds (rotación/split), solo recalcular el “fitNow”
            if imageChanged || boundsChanged {
                lastScrollBounds = boundsSize

                // si bounds aún no están listos, salir
                guard boundsSize.width > 10, boundsSize.height > 10,
                      imageSize.width > 10, imageSize.height > 10 else { return }

                let fitNow = min(boundsSize.width / imageSize.width, boundsSize.height / imageSize.height)

                // baseMinZoom solo se fija o baja (nunca sube)
                if baseMinZoom == nil { baseMinZoom = fitNow }
                else { baseMinZoom = min(baseMinZoom!, fitNow) }

                let minZoom = baseMinZoom ?? fitNow
                scroll.minimumZoomScale = minZoom
                scroll.maximumZoomScale = max(6, minZoom * 12)

                // aplicar zoom inicial SOLO cuando cambió imagen (o primera vez con bounds validos)
                if !didApplyInitialFit {
                    didApplyInitialFit = true
                    DispatchQueue.main.async {
                        scroll.setZoomScale(minZoom, animated: false)
                        self.centerContentIfNeeded(scroll)
                    }
                } else {
                    // nunca empujamos zoom hacia arriba por updates; solo corregimos si quedó por debajo del mínimo
                    if scroll.zoomScale < minZoom {
                        scroll.setZoomScale(minZoom, animated: false)
                    }
                    // y centramos si es necesario (no cambia offsets agresivamente)
                    centerContentIfNeeded(scroll)
                }
            } else {
                // NO tocar layout/zoom si solo cambió pins/selección
            }
        }

        // ✅ Centrar contenido sin alterar zoomScale
        func centerContentIfNeeded(_ scrollView: UIScrollView) {
            guard let imageView = imageView else { return }

            let boundsSize = scrollView.bounds.size
            let scaled = CGSize(width: imageView.bounds.width * scrollView.zoomScale,
                                height: imageView.bounds.height * scrollView.zoomScale)

            let horizontalInset = max(0, (boundsSize.width - scaled.width) / 2)
            let verticalInset = max(0, (boundsSize.height - scaled.height) / 2)

            // Ojo: esto no debe causar “brincos” si no cambias zoom
            scrollView.contentInset = UIEdgeInsets(top: verticalInset,
                                                  left: horizontalInset,
                                                  bottom: verticalInset,
                                                  right: horizontalInset)
        }

        // ✅ Auto-centrado solo si está fuera de vista
        func maybeCenterOnSelectedPin(selectedID: UUID?, normalizedPoint: CGPoint?) {
            guard let scroll = scrollView else { return }
            guard let id = selectedID, let p = normalizedPoint else { return }
            guard id != lastAutoCenteredPinID else { return }

            let imageSize = lastImageSize
            guard imageSize.width > 0, imageSize.height > 0 else { return }

            let target = CGPoint(x: p.x * imageSize.width, y: p.y * imageSize.height)

            if isPointVisible(target, in: scroll) {
                lastAutoCenteredPinID = id
                return
            }

            centerOnPoint(target, in: scroll)
            lastAutoCenteredPinID = id
        }

        private func isPointVisible(_ p: CGPoint, in scroll: UIScrollView) -> Bool {
            let inset = scroll.contentInset
            let visibleOrigin = CGPoint(x: scroll.contentOffset.x + inset.left,
                                        y: scroll.contentOffset.y + inset.top)
            let visibleSize = CGSize(width: scroll.bounds.width - inset.left - inset.right,
                                     height: scroll.bounds.height - inset.top - inset.bottom)

            let zoom = scroll.zoomScale
            let rectInImage = CGRect(
                x: visibleOrigin.x / zoom,
                y: visibleOrigin.y / zoom,
                width: visibleSize.width / zoom,
                height: visibleSize.height / zoom
            ).insetBy(dx: -40, dy: -40)

            return rectInImage.contains(p)
        }

        private func centerOnPoint(_ pointInImage: CGPoint, in scroll: UIScrollView) {
            let zoom = scroll.zoomScale
            let inset = scroll.contentInset
            let viewSize = scroll.bounds.size

            let targetX = pointInImage.x * zoom
            let targetY = pointInImage.y * zoom

            let x = max(-inset.left, targetX - (viewSize.width / 2))
            let y = max(-inset.top, targetY - (viewSize.height / 2))

            scroll.setContentOffset(CGPoint(x: x, y: y), animated: true)
        }
    }
}




