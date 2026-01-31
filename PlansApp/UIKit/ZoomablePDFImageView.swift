//
//  ZoomablePDFImageView.swift
//  PlansApp
//
//  Created by Adrian Rodriguez Llorens on 27/01/26.
//

import SwiftUI
import UIKit
import PencilKit

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

    // PencilKit
    let isDrawingMode: Bool
    @Binding var drawingData: Data?

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

        // Image view
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        scroll.addSubview(imageView)
        context.coordinator.imageView = imageView

        // Pins overlay
        let overlay = PinOverlayView()
        overlay.backgroundColor = .clear
        overlay.isUserInteractionEnabled = true
        imageView.addSubview(overlay)
        context.coordinator.overlay = overlay

        overlay.onSelectPin = { id in onSelectPin(id) }
        overlay.onEditPin = { id in onEditPin(id) }
        overlay.onPinScaleCommit = { id, scale in onPinScaleCommit(id, scale) }
        overlay.onMovePinCommit = { id, nx, ny in onMovePinCommit(id, nx, ny) }

        // PencilKit canvas overlay
        let canvas = PKCanvasView()
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.drawingPolicy = .anyInput
        canvas.delegate = context.coordinator

        // ✅ Tool por defecto SIEMPRE negro (para que no pase blanco)
        canvas.tool = PKInkingTool(.pen, color: .black, width: 6)

        imageView.addSubview(canvas)
        context.coordinator.canvas = canvas

        // ✅ ToolPicker setup con reintentos
        context.coordinator.attachToolPickerWhenPossible()

        // Tap para agregar pins (solo si NO es modo dibujo)
        let tap = UITapGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.handleOverlayTap(_:)))
        tap.cancelsTouchesInView = false
        overlay.addGestureRecognizer(tap)

        return scroll
    }

    func updateUIView(_ scroll: UIScrollView, context: Context) {
        guard let imageView = context.coordinator.imageView,
              let overlay = context.coordinator.overlay,
              let canvas = context.coordinator.canvas else { return }

        context.coordinator.parent = self

        context.coordinator.ensureLayout(
            scroll: scroll,
            imageView: imageView,
            overlay: overlay,
            canvas: canvas,
            image: image
        )

        // Pins
        let snapshot = pins.map {
            PinSnapshot(id: $0.id, x: $0.x, y: $0.y, scale: $0.pinScale, type: $0.type.rawValue)
        }
        if snapshot != context.coordinator.lastPinsSnapshot {
            overlay.setPins(pins, imageSize: image.size)
            context.coordinator.lastPinsSnapshot = snapshot
        }

        overlay.selectedPinID = selectedPinID

        // PencilKit: cargar data si cambió
        context.coordinator.applyDrawingDataIfNeeded(drawingData)

        // ✅ Modo dibujo/pins: aquí se fuerza tool negro y se muestra toolpicker
        context.coordinator.setMode(isDrawing: isDrawingMode)

        // Center pin si aplica
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

    final class Coordinator: NSObject, UIScrollViewDelegate, PKCanvasViewDelegate {
        var parent: ZoomablePDFImageView

        private var toolPicker: PKToolPicker?
        private var toolPickerAttached = false
        private var toolPickerAttachAttempts = 0

        weak var scrollView: UIScrollView?
        weak var imageView: UIImageView?
        weak var overlay: PinOverlayView?
        weak var canvas: PKCanvasView?

        var lastPinsSnapshot: [PinSnapshot] = []

        private var lastImageRef: UIImage?
        private var lastImageSize: CGSize = .zero
        private var lastScrollBounds: CGSize = .zero

        private var baseMinZoom: CGFloat?
        private var didApplyInitialFit = false
        private var lastAutoCenteredPinID: UUID?

        private var pendingFitRetry = false

        private var lastAppliedDrawingHash: Int?
        private var lastIsDrawingMode: Bool?

        init(_ parent: ZoomablePDFImageView) {
            self.parent = parent
        }

        // MARK: - ToolPicker (SwiftUI-safe attach with retries)

        func attachToolPickerWhenPossible() {
            // evita loops infinitos
            guard toolPickerAttached == false else { return }
            guard toolPickerAttachAttempts < 30 else { return } // ~30 intentos

            toolPickerAttachAttempts += 1

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
                guard let self else { return }
                guard let canvas = self.canvas else { return }

                // 1) Preferimos la window REAL del canvas
                if let window = canvas.window {
                    self.attachToolPicker(window: window, canvas: canvas)
                    return
                }

                // 2) Si aún no hay window, reintenta
                self.attachToolPickerWhenPossible()
            }
        }

        private func attachToolPicker(window: UIWindow, canvas: PKCanvasView) {
            guard #available(iOS 14.0, *) else { return }
            guard toolPickerAttached == false else { return }

            let picker = PKToolPicker.shared(for: window)
            toolPicker = picker

            picker?.addObserver(canvas)
            picker?.setVisible(false, forFirstResponder: canvas)

            toolPickerAttached = true
        }

        // MARK: UIScrollViewDelegate

        func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerContentIfNeeded(scrollView)
        }

        @objc func handleOverlayTap(_ g: UITapGestureRecognizer) {
            guard parent.isDrawingMode == false else { return }
            guard let overlay else { return }
            let p = g.location(in: overlay)
            parent.onTapInImageSpace(p)
        }

        // MARK: Layout

        func ensureLayout(scroll: UIScrollView, imageView: UIImageView, overlay: PinOverlayView, canvas: PKCanvasView, image: UIImage) {
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
                canvas.frame = CGRect(origin: .zero, size: imageSize)

                scroll.contentSize = imageSize
            }

            if imageChanged || boundsChanged {
                lastScrollBounds = boundsSize

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
                    self.scheduleFitRetry(scroll: scroll, imageSize: imageSize)
                }
            }
        }

        private func applyStableFit(scroll: UIScrollView, boundsSize: CGSize, imageSize: CGSize) {
            guard imageSize.width > 10, imageSize.height > 10 else { return }

            let fitNow = min(boundsSize.width / imageSize.width, boundsSize.height / imageSize.height)

            if baseMinZoom == nil { baseMinZoom = fitNow }
            else { baseMinZoom = min(baseMinZoom!, fitNow) }

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

        // MARK: PencilKit Mode

        func setMode(isDrawing: Bool) {
            guard let scroll = scrollView,
                  let overlay = overlay,
                  let canvas = canvas else { return }

            // asegurar toolpicker attach
            if toolPickerAttached == false {
                attachToolPickerWhenPossible()
            }

            // Evitar repetición
            if lastIsDrawingMode == isDrawing { return }
            lastIsDrawingMode = isDrawing

            overlay.isUserInteractionEnabled = !isDrawing
            canvas.isUserInteractionEnabled = isDrawing

            if isDrawing {
                // 2 dedos pan, 1 dedo dibuja
                scroll.panGestureRecognizer.minimumNumberOfTouches = 2

                // ✅ Forzar SIEMPRE un tool negro visible
                canvas.tool = PKInkingTool(.pen, color: .black, width: 6)

                // ✅ Mostrar ToolPicker
                DispatchQueue.main.async { [weak self, weak canvas] in
                    guard let self, let canvas else { return }
                    self.toolPicker?.setVisible(true, forFirstResponder: canvas)
                    canvas.becomeFirstResponder()
                }
            } else {
                scroll.panGestureRecognizer.minimumNumberOfTouches = 1

                // Ocultar ToolPicker
                DispatchQueue.main.async { [weak self, weak canvas] in
                    guard let self, let canvas else { return }
                    self.toolPicker?.setVisible(false, forFirstResponder: canvas)
                    canvas.resignFirstResponder()
                }
            }
        }

        func applyDrawingDataIfNeeded(_ data: Data?) {
            guard let canvas = canvas else { return }

            let hash = data?.hashValue ?? 0
            guard hash != lastAppliedDrawingHash else { return }
            lastAppliedDrawingHash = hash

            if let data, let drawing = try? PKDrawing(data: data) {
                canvas.drawing = drawing
            } else {
                canvas.drawing = PKDrawing()
            }
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            let data = canvasView.drawing.dataRepresentation()

            // ✅ Evitar warning morado en SwiftUI
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.parent.drawingData = data
            }
        }
    }
}
