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

        // Tap en overlay (coordenadas exactas del espacio de imagen)
        let tap = UITapGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.handleOverlayTap(_:)))
        tap.cancelsTouchesInView = false
        overlay.addGestureRecognizer(tap)

        return scroll
    }

    func updateUIView(_ scroll: UIScrollView, context: Context) {
        guard let imageView = context.coordinator.imageView,
              let overlay = context.coordinator.overlay else { return }

        context.coordinator.ensureLayout(scroll: scroll, imageView: imageView, overlay: overlay, image: image)

        // pins: solo reconstruir si cambiaron
        let snapshot = pins.map {
            PinSnapshot(id: $0.id, x: $0.x, y: $0.y, scale: $0.pinScale, type: $0.type.rawValue)
        }
        if snapshot != context.coordinator.lastPinsSnapshot {
            overlay.setPins(pins, imageSize: image.size)
            context.coordinator.lastPinsSnapshot = snapshot
        }

        overlay.selectedPinID = selectedPinID

        context.coordinator.maybeCenterOnSelectedPin(
            selectedID: selectedPinID,
            normalizedPoint: selectedPinNormalizedPoint
        )
    }

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

        private var lastImageRef: UIImage?
        private var lastImageSize: CGSize = .zero
        private var lastScrollBounds: CGSize = .zero

        private var baseMinZoom: CGFloat?
        private var didApplyInitialFit = false

        private var lastAutoCenteredPinID: UUID?

        // ✅ NUEVO: evita loops; reintenta fit cuando bounds aún no están listos
        private var pendingFitRetry = false

        init(_ parent: ZoomablePDFImageView) { self.parent = parent }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerContentIfNeeded(scrollView)
        }

        @objc func handleOverlayTap(_ g: UITapGestureRecognizer) {
            guard let overlay else { return }
            let p = g.location(in: overlay)
            parent.onTapInImageSpace(p)
        }

        func ensureLayout(scroll: UIScrollView, imageView: UIImageView, overlay: PinOverlayView, image: UIImage) {
            let boundsSize = scroll.bounds.size
            let imageSize = image.size

            let imageChanged = (lastImageRef !== image) || (lastImageSize != imageSize)
            let boundsChanged = (lastScrollBounds != boundsSize)

            if imageChanged {
                lastImageRef = image
                lastImageSize = imageSize
                lastAutoCenteredPinID = nil
                didApplyInitialFit = false
                baseMinZoom = nil
                pendingFitRetry = false

                imageView.image = image
                imageView.frame = CGRect(origin: .zero, size: imageSize)
                overlay.frame = CGRect(origin: .zero, size: imageSize)
                scroll.contentSize = imageSize
            }

            if imageChanged || boundsChanged {
                lastScrollBounds = boundsSize

                // ❗ Si bounds todavía no están “bien”, reintenta en el siguiente ciclo
                if boundsSize.width < 20 || boundsSize.height < 20 {
                    scheduleFitRetry(scroll: scroll, imageSize: imageSize)
                    return
                }

                applyStableFit(scroll: scroll, boundsSize: boundsSize, imageSize: imageSize)
            }
        }

        private func scheduleFitRetry(scroll: UIScrollView, imageSize: CGSize) {
            guard !pendingFitRetry else { return }
            pendingFitRetry = true

            DispatchQueue.main.async { [weak self, weak scroll] in
                guard let self, let scroll else { return }
                self.pendingFitRetry = false

                let bounds = scroll.bounds.size
                if bounds.width >= 20, bounds.height >= 20 {
                    self.applyStableFit(scroll: scroll, boundsSize: bounds, imageSize: imageSize)
                } else {
                    // si todavía no, reintenta una vez más
                    self.scheduleFitRetry(scroll: scroll, imageSize: imageSize)
                }
            }
        }

        private func applyStableFit(scroll: UIScrollView, boundsSize: CGSize, imageSize: CGSize) {
            guard imageSize.width > 10, imageSize.height > 10 else { return }

            let fitNow = min(boundsSize.width / imageSize.width, boundsSize.height / imageSize.height)

            if baseMinZoom == nil { baseMinZoom = fitNow }
            else { baseMinZoom = min(baseMinZoom!, fitNow) } // nunca subir

            let minZoom = baseMinZoom ?? fitNow
            scroll.minimumZoomScale = minZoom
            scroll.maximumZoomScale = max(6, minZoom * 12)

            if !didApplyInitialFit {
                didApplyInitialFit = true
                DispatchQueue.main.async {
                    scroll.setZoomScale(minZoom, animated: false)
                    self.centerContentIfNeeded(scroll)
                }
            } else {
                if scroll.zoomScale < minZoom {
                    scroll.setZoomScale(minZoom, animated: false)
                }
                centerContentIfNeeded(scroll)
            }
        }

        private func centerContentIfNeeded(_ scrollView: UIScrollView) {
            guard let imageView = imageView else { return }

            let boundsSize = scrollView.bounds.size
            let scaled = CGSize(width: imageView.bounds.width * scrollView.zoomScale,
                                height: imageView.bounds.height * scrollView.zoomScale)

            let horizontalInset = max(0, (boundsSize.width - scaled.width) / 2)
            let verticalInset = max(0, (boundsSize.height - scaled.height) / 2)

            scrollView.contentInset = UIEdgeInsets(top: verticalInset,
                                                  left: horizontalInset,
                                                  bottom: verticalInset,
                                                  right: horizontalInset)
        }

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



