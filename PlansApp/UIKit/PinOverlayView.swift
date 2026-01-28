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

    var selectedPinID: UUID?

    // Para pinch global (sobre el overlay completo)
    private var overlayPinchGR: UIPinchGestureRecognizer?
    private var pinchStartScale: CGFloat = 1.0
    private var isPinching: Bool = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = true
        isMultipleTouchEnabled = true

        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handleOverlayPinch(_:)))
        pinch.delegate = self
        addGestureRecognizer(pinch)
        overlayPinchGR = pinch
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        isUserInteractionEnabled = true
        isMultipleTouchEnabled = true

        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handleOverlayPinch(_:)))
        pinch.delegate = self
        addGestureRecognizer(pinch)
        overlayPinchGR = pinch
    }

    func setPins(_ pins: [Pin], imageSize: CGSize) {
        subviews.forEach { $0.removeFromSuperview() }

        for pin in pins {
            let p = CGPoint(x: pin.x * imageSize.width, y: pin.y * imageSize.height)

            let control = PinControl(pin: pin, selected: pin.id == selectedPinID)

            control.onSelect = { [weak self] id in
                self?.selectedPinID = id
                self?.onSelectPin?(id)
            }

            control.onEdit = { [weak self] id in
                self?.selectedPinID = id
                self?.onEditPin?(id)
            }

            control.center = p
            addSubview(control)
        }
    }

    // MARK: - Pinch global (cualquier parte del plano)
    @objc private func handleOverlayPinch(_ g: UIPinchGestureRecognizer) {
        guard let id = selectedPinID else { return }
        guard let pinView = findPinView(by: id) else { return }

        // Debug (déjalo hasta que confirmes que ya entra)
        print("OVERLAY PINCH → state:", g.state.rawValue, "scale:", g.scale)

        let minS: CGFloat = 0.7
        let maxS: CGFloat = 2.2

        switch g.state {
        case .began:
            isPinching = true
            pinchStartScale = pinView.storedScaleForExternalAccess
        case .changed:
            let temp = clamp(pinchStartScale * g.scale, minS, maxS)
            pinView.applyScaleFromOutside(temp)
        case .ended, .cancelled, .failed:
            let final = clamp(pinchStartScale * g.scale, minS, maxS)
            pinView.applyScaleFromOutside(final)
            pinView.storedScaleForExternalAccess = final
            onPinScaleCommit?(id, final)
            isPinching = false
        default:
            break
        }
    }

    private func findPinView(by id: UUID) -> PinControl? {
        for v in subviews {
            if let p = v as? PinControl, p.pinID == id {
                return p
            }
        }
        return nil
    }

    private func clamp(_ v: CGFloat, _ a: CGFloat, _ b: CGFloat) -> CGFloat {
        min(max(v, a), b)
    }

    // MARK: - UIGestureRecognizerDelegate
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // Solo permitir pinch si hay pin seleccionado
        if gestureRecognizer === overlayPinchGR {
            return selectedPinID != nil
        }
        return true
    }
}

// MARK: - PinControl (tap/double tap + render)
final class PinControl: UIView, UIGestureRecognizerDelegate {

    let pinID: UUID

    var onSelect: ((UUID) -> Void)?
    var onEdit: ((UUID) -> Void)?

    fileprivate var storedScaleForExternalAccess: CGFloat

    private let baseSize: CGFloat = 34

    init(pin: Pin, selected: Bool) {
        self.pinID = pin.id
        self.storedScaleForExternalAccess = pin.pinScale
        super.init(frame: CGRect(x: 0, y: 0, width: baseSize, height: baseSize))

        isUserInteractionEnabled = true

        backgroundColor = UIColor.systemBlue.withAlphaComponent(0.92)
        layer.cornerRadius = baseSize / 2

        layer.borderWidth = selected ? 3 : 1
        layer.borderColor = selected ? UIColor.systemYellow.cgColor
        : UIColor.white.withAlphaComponent(0.85).cgColor

        layer.shadowColor = selected ? UIColor.systemYellow.cgColor : UIColor.clear.cgColor
        layer.shadowRadius = selected ? 6 : 0
        layer.shadowOpacity = selected ? 0.9 : 0
        layer.shadowOffset = .zero

        let label = UILabel(frame: bounds)
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 12, weight: .bold)
        label.textColor = .white
        label.text = pin.type.shortCode
        label.isUserInteractionEnabled = false
        addSubview(label)

        applyScaleFromOutside(storedScaleForExternalAccess)

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap))
        doubleTap.numberOfTapsRequired = 2
        doubleTap.delegate = self
        addGestureRecognizer(doubleTap)

        let singleTap = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap))
        singleTap.numberOfTapsRequired = 1
        singleTap.delegate = self
        singleTap.require(toFail: doubleTap)
        addGestureRecognizer(singleTap)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func handleSingleTap() { onSelect?(pinID) }
    @objc private func handleDoubleTap() { onEdit?(pinID) }

    // Lo usa el overlay pinch
    fileprivate func applyScaleFromOutside(_ s: CGFloat) {
        transform = CGAffineTransform(scaleX: s, y: s)
    }
}
