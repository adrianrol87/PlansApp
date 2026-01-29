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
        scroll.minimumZoomScale = 1
        scroll.maximumZoomScale = 6
        scroll.delegate = context.coordinator
        scroll.bouncesZoom = true
        scroll.showsHorizontalScrollIndicator = false
        scroll.showsVerticalScrollIndicator = false

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        scroll.addSubview(imageView)
        context.coordinator.imageView = imageView

        let overlay = PinOverlayView()
        overlay.backgroundColor = .clear
        imageView.addSubview(overlay)
        context.coordinator.overlay = overlay

        overlay.onSelectPin = { id in onSelectPin(id) }
        overlay.onEditPin = { id in onEditPin(id) }
        overlay.onPinScaleCommit = { id, scale in onPinScaleCommit(id, scale) }
        overlay.onMovePinCommit = { id, nx, ny in onMovePinCommit(id, nx, ny) }

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tap.cancelsTouchesInView = false
        imageView.addGestureRecognizer(tap)

        return scroll
    }

    func updateUIView(_ scroll: UIScrollView, context: Context) {
        guard let imageView = context.coordinator.imageView,
              let overlay = context.coordinator.overlay else { return }

        let size = image.size
        imageView.frame = CGRect(origin: .zero, size: size)
        scroll.contentSize = size

        overlay.frame = CGRect(origin: .zero, size: size)

        // ✅ SOLO reconstruir pins si cambiaron
        let snapshot = pins.map { PinSnapshot(id: $0.id, x: $0.x, y: $0.y, scale: $0.pinScale, type: $0.type.rawValue) }
        if snapshot != context.coordinator.lastPinsSnapshot {
            overlay.setPins(pins, imageSize: size)
            context.coordinator.lastPinsSnapshot = snapshot
        }

        // ✅ Selección se actualiza sin reconstruir pins
        overlay.selectedPinID = selectedPinID

        if let p = selectedPinNormalizedPoint {
            context.coordinator.centerOnNormalizedPoint(p, in: scroll)
        }
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
        weak var imageView: UIImageView?
        weak var overlay: PinOverlayView?

        var lastPinsSnapshot: [PinSnapshot] = []

        init(_ parent: ZoomablePDFImageView) {
            self.parent = parent
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

        @objc func handleTap(_ g: UITapGestureRecognizer) {
            guard let imageView else { return }
            let p = g.location(in: imageView)
            parent.onTapInImageSpace(p)
        }

        func centerOnNormalizedPoint(_ p: CGPoint, in scroll: UIScrollView) {
            guard let imageView else { return }

            let target = CGPoint(x: p.x * imageView.bounds.width, y: p.y * imageView.bounds.height)

            let zoom = scroll.zoomScale
            let viewSize = scroll.bounds.size

            let x = max(0, target.x * zoom - viewSize.width / 2)
            let y = max(0, target.y * zoom - viewSize.height / 2)

            scroll.setContentOffset(CGPoint(x: x, y: y), animated: true)
        }
    }
}




