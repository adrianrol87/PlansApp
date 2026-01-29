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

    private var overlayPinchGR: UIPinchGestureRecognizer?
    private var pinchStartScale: CGFloat = 1.0

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

    // MARK: - Pinch global sobre el overlay para escalar pin seleccionado
    @objc private func handleOverlayPinch(_ g: UIPinchGestureRecognizer) {
        guard let id = selectedPinID else { return }
        guard let pinView = findPinView(by: id) else { return }

        let minS: CGFloat = 0.7
        let maxS: CGFloat = 2.2

        switch g.state {
        case .began:
            pinchStartScale = pinView.storedScaleForExternalAccess

        case .changed:
            let temp = clamp(pinchStartScale * g.scale, minS, maxS)
            pinView.applyScaleFromOutside(temp)

        case .ended, .cancelled, .failed:
            let final = clamp(pinchStartScale * g.scale, minS, maxS)
            pinView.applyScaleFromOutside(final)
            pinView.storedScaleForExternalAccess = final
            onPinScaleCommit?(id, final)

        default:
            break
        }
    }

    private func findPinView(by id: UUID) -> PinControl? {
        for v in subviews {
            if let p = v as? PinControl, p.pinID == id { return p }
        }
        return nil
    }

    private func clamp(_ v: CGFloat, _ a: CGFloat, _ b: CGFloat) -> CGFloat {
        min(max(v, a), b)
    }

    // Solo permitir pinch si hay pin seleccionado
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer === overlayPinchGR {
            return selectedPinID != nil
        }
        return true
    }
}

// MARK: - PinControl (icono PDF como asset)
final class PinControl: UIView, UIGestureRecognizerDelegate {

    let pinID: UUID
    var onSelect: ((UUID) -> Void)?
    var onEdit: ((UUID) -> Void)?

    fileprivate var storedScaleForExternalAccess: CGFloat

    private let baseSize: CGFloat = 44
    private let imageView = UIImageView()

    init(pin: Pin, selected: Bool) {
        self.pinID = pin.id
        self.storedScaleForExternalAccess = pin.pinScale
        super.init(frame: CGRect(x: 0, y: 0, width: baseSize, height: baseSize))

        isUserInteractionEnabled = true
        backgroundColor = .clear

        // icono PDF (assetName = rawValue del DeviceType)
        imageView.contentMode = .scaleAspectFit
        imageView.frame = bounds
        imageView.image = UIImage(named: pin.type.rawValue)
        addSubview(imageView)

        // Highlight
        layer.cornerRadius = 10
        layer.borderWidth = selected ? 3 : 0
        layer.borderColor = selected ? UIColor.systemYellow.cgColor : UIColor.clear.cgColor
        layer.shadowColor = selected ? UIColor.systemYellow.cgColor : UIColor.clear.cgColor
        layer.shadowRadius = selected ? 6 : 0
        layer.shadowOpacity = selected ? 0.9 : 0
        layer.shadowOffset = .zero

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

    fileprivate func applyScaleFromOutside(_ s: CGFloat) {
        transform = CGAffineTransform(scaleX: s, y: s)
    }
}
