//
//  PinOverlayView.swift
//  PlansApp
//
//  Created by Adrian Rodriguez Llorens on 27/01/26.
//

import UIKit

final class PinOverlayView: UIView, UIGestureRecognizerDelegate {

    var onSelectPin: ((UUID) -> Void)?
    var onEditPin: ((UUID) -> Void)?
    var onPinScaleCommit: ((UUID, CGFloat) -> Void)?
    var onMovePinCommit: ((UUID, CGFloat, CGFloat) -> Void)?

    var selectedPinID: UUID? {
        didSet { refreshSelectionBorders() }
    }

    private var overlayPinchGR: UIPinchGestureRecognizer?
    private var pinchStartScale: CGFloat = 1.0

    private var currentImageSize: CGSize = .zero

    // Cache: id -> view
    private var pinViews: [UUID: PinControl] = [:]

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        isUserInteractionEnabled = true
        isMultipleTouchEnabled = true
        backgroundColor = .clear

        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handleOverlayPinch(_:)))
        pinch.delegate = self
        addGestureRecognizer(pinch)
        overlayPinchGR = pinch
    }

    // ✅ Solo se llama cuando cambian pins (no cada update visual)
    func setPins(_ pins: [Pin], imageSize: CGSize) {
        currentImageSize = imageSize

        let newIDs = Set(pins.map { $0.id })
        let oldIDs = Set(pinViews.keys)

        // remove views that no longer exist
        for removed in oldIDs.subtracting(newIDs) {
            pinViews[removed]?.removeFromSuperview()
            pinViews.removeValue(forKey: removed)
        }

        // create/update existing
        for pin in pins {
            let center = CGPoint(x: pin.x * imageSize.width, y: pin.y * imageSize.height)

            if let view = pinViews[pin.id] {
                // update existing view (no re-create)
                view.updateVisual(typeRaw: pin.type.rawValue, scale: pin.pinScale)
                view.center = center
            } else {
                // create
                let control = PinControl(
                    pinID: pin.id,
                    typeRaw: pin.type.rawValue,
                    scale: pin.pinScale
                )

                control.onSingleTap = { [weak self] id in
                    guard let self else { return }
                    self.selectedPinID = id
                    self.onSelectPin?(id)
                }

                control.onDoubleTap = { [weak self] id in
                    guard let self else { return }
                    self.selectedPinID = id
                    self.onEditPin?(id)
                }

                // ✅ Drag: NO dispara onSelectPin en began (para no refrescar SwiftUI)
                control.onDragChanged = { [weak self] id, newCenter in
                    guard let self else { return }
                    // selecciona localmente (solo UI)
                    if self.selectedPinID != id {
                        self.selectedPinID = id
                    }
                    // clamp visual dentro de imagen
                    let clamped = self.clampPointToImage(newCenter)
                    self.pinViews[id]?.center = clamped
                }

                control.onDragEnded = { [weak self] id, finalCenter in
                    guard let self else { return }
                    let clamped = self.clampPointToImage(finalCenter)

                    let nx = min(max(clamped.x / max(self.currentImageSize.width, 1), 0), 1)
                    let ny = min(max(clamped.y / max(self.currentImageSize.height, 1), 0), 1)

                    // ahora sí avisamos a SwiftUI para persistir
                    self.onMovePinCommit?(id, nx, ny)
                }

                control.center = center
                addSubview(control)
                pinViews[pin.id] = control
            }
        }

        refreshSelectionBorders()
    }

    private func clampPointToImage(_ p: CGPoint) -> CGPoint {
        let w = currentImageSize.width
        let h = currentImageSize.height
        guard w > 0, h > 0 else { return p }

        return CGPoint(
            x: min(max(p.x, 0), w),
            y: min(max(p.y, 0), h)
        )
    }

    private func refreshSelectionBorders() {
        for (id, v) in pinViews {
            v.setHighlighted(id == selectedPinID)
        }
    }

    // MARK: - Pinch global sobre el overlay para escalar pin seleccionado
    @objc private func handleOverlayPinch(_ g: UIPinchGestureRecognizer) {
        guard let id = selectedPinID else { return }
        guard let pinView = pinViews[id] else { return }

        let minS: CGFloat = 0.7
        let maxS: CGFloat = 2.2

        switch g.state {
        case .began:
            pinchStartScale = pinView.currentScale

        case .changed:
            let temp = clamp(pinchStartScale * g.scale, minS, maxS)
            pinView.applyScale(temp)

        case .ended, .cancelled, .failed:
            let final = clamp(pinchStartScale * g.scale, minS, maxS)
            pinView.applyScale(final)
            onPinScaleCommit?(id, final)

        default:
            break
        }
    }

    private func clamp(_ v: CGFloat, _ a: CGFloat, _ b: CGFloat) -> CGFloat {
        min(max(v, a), b)
    }

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer === overlayPinchGR {
            return selectedPinID != nil
        }
        return true
    }
}

// MARK: - PinControl
final class PinControl: UIView, UIGestureRecognizerDelegate {

    let pinID: UUID
    private let baseSize: CGFloat = 44

    private let imageView = UIImageView()

    var onSingleTap: ((UUID) -> Void)?
    var onDoubleTap: ((UUID) -> Void)?

    var onDragChanged: ((UUID, CGPoint) -> Void)?
    var onDragEnded: ((UUID, CGPoint) -> Void)?

    private(set) var currentScale: CGFloat

    init(pinID: UUID, typeRaw: String, scale: CGFloat) {
        self.pinID = pinID
        self.currentScale = scale
        super.init(frame: CGRect(x: 0, y: 0, width: baseSize, height: baseSize))

        isUserInteractionEnabled = true
        backgroundColor = .clear

        imageView.contentMode = .scaleAspectFit
        imageView.frame = bounds
        imageView.image = UIImage(named: typeRaw)
        addSubview(imageView)

        layer.cornerRadius = 10
        setHighlighted(false)

        applyScale(scale)

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap))
        doubleTap.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTap)

        let singleTap = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap))
        singleTap.numberOfTapsRequired = 1
        singleTap.require(toFail: doubleTap)
        addGestureRecognizer(singleTap)

        let lp = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        lp.minimumPressDuration = 0.25
        addGestureRecognizer(lp)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func updateVisual(typeRaw: String, scale: CGFloat) {
        if imageView.image == nil || imageView.image?.accessibilityIdentifier != typeRaw {
            imageView.image = UIImage(named: typeRaw)
            imageView.image?.accessibilityIdentifier = typeRaw
        }
        applyScale(scale)
    }

    func setHighlighted(_ on: Bool) {
        layer.borderWidth = on ? 3 : 0
        layer.borderColor = on ? UIColor.systemYellow.cgColor : UIColor.clear.cgColor
        layer.shadowColor = on ? UIColor.systemYellow.cgColor : UIColor.clear.cgColor
        layer.shadowRadius = on ? 6 : 0
        layer.shadowOpacity = on ? 0.9 : 0
        layer.shadowOffset = .zero
    }

    @objc private func handleSingleTap() { onSingleTap?(pinID) }
    @objc private func handleDoubleTap() { onDoubleTap?(pinID) }

    func applyScale(_ s: CGFloat) {
        currentScale = s
        transform = CGAffineTransform(scaleX: s, y: s)
    }

    @objc private func handleLongPress(_ g: UILongPressGestureRecognizer) {
        guard let superV = superview else { return }
        let loc = g.location(in: superV)

        switch g.state {
        case .began, .changed:
            onDragChanged?(pinID, loc)
        case .ended, .cancelled, .failed:
            onDragEnded?(pinID, loc)
        default:
            break
        }
    }
}
