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

    /// Coordenadas normalizadas 0...1
    var x: CGFloat
    var y: CGFloat

    var type: DeviceType
    var note: String?

    /// Máximo 3 fotos por pin
    var photoFilenames: [String]

    init(
        id: UUID = UUID(),
        pageIndex: Int,
        x: CGFloat,
        y: CGFloat,
        type: DeviceType,
        note: String? = nil,
        photoFilenames: [String] = []
    ) {
        self.id = id
        self.pageIndex = pageIndex
        self.x = x
        self.y = y
        self.type = type
        self.note = note
        self.photoFilenames = photoFilenames
    }
}


