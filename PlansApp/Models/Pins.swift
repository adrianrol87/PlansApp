//
//  Pins.swift
//  PlansApp
//
//  Created by Adrian Rodriguez Llorens on 27/01/26.
//

import Foundation
import CoreGraphics

struct Pin: Identifiable, Codable, Equatable {
    let id: UUID
    var pageIndex: Int

    /// Coordenadas normalizadas 0...1 respecto a la imagen renderizada
    var x: CGFloat
    var y: CGFloat

    var type: DeviceType
    var note: String?

    init(id: UUID = UUID(), pageIndex: Int, x: CGFloat, y: CGFloat, type: DeviceType, note: String? = nil) {
        self.id = id
        self.pageIndex = pageIndex
        self.x = x
        self.y = y
        self.type = type
        self.note = note
    }
}
