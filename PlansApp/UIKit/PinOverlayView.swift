//
//  PinOverlayView.swift
//  PlansApp
//
//  Created by Adrian Rodriguez Llorens on 27/01/26.
//

import UIKit

final class PinOverlayView: UIView {

    var onSelectPin: ((UUID) -> Void)?
    var selectedPinID: UUID?

    func setPins(_ pins: [Pin], imageSize: CGSize) {
        subviews.forEach { $0.removeFromSuperview() }

        for pin in pins {
            let p = CGPoint(x: pin.x * imageSize.width, y: pin.y * imageSize.height)
            let v = makePinView(for: pin, selected: pin.id == selectedPinID)
            v.center = p
            addSubview(v)
        }
    }

    private func makePinView(for pin: Pin, selected: Bool) -> UIControl {
        let size: CGFloat = 34
        let control = UIControl(frame: CGRect(x: 0, y: 0, width: size, height: size))

        // CONTENEDOR (esto no cambia nunca)
        control.backgroundColor = UIColor.systemBlue
        control.layer.cornerRadius = size / 2
        control.layer.borderWidth = selected ? 3 : 1
        control.layer.borderColor = selected
            ? UIColor.systemYellow.cgColor
            : UIColor.white.withAlphaComponent(0.8).cgColor

        // Sombra de selección
        control.layer.shadowColor = selected ? UIColor.systemYellow.cgColor : UIColor.clear.cgColor
        control.layer.shadowRadius = selected ? 6 : 0
        control.layer.shadowOpacity = selected ? 0.9 : 0
        control.layer.shadowOffset = .zero

        // ICONO (reemplazable mañana)
        let iconView: UIView

        // HOY: texto
        let label = UILabel(frame: control.bounds)
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 12, weight: .bold)
        label.textColor = .white
        label.text = pin.type.shortCode
        iconView = label

        // MAÑANA: iconos custom
        // let imageView = UIImageView(image: UIImage(named: pin.type.assetName))
        // imageView.contentMode = .scaleAspectFit
        // iconView = imageView

        iconView.isUserInteractionEnabled = false
        control.addSubview(iconView)

        control.accessibilityIdentifier = pin.id.uuidString
        control.addAction(UIAction { [weak self] _ in
            guard let idStr = control.accessibilityIdentifier,
                  let id = UUID(uuidString: idStr) else { return }
            self?.selectedPinID = id
            self?.onSelectPin?(id)
        }, for: .touchUpInside)

        return control
    }
}

