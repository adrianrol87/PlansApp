//
//  PlanProject.swift
//  PlansApp
//
//  Created by Adrian Rodriguez Llorens on 27/01/26.
//

import Foundation
import CoreGraphics

struct PlanProject: Codable {
    var id: UUID = UUID()
    var name: String = "Plans App Project"

    /// Opcional: si luego guardas el PDF con bookmark para reabrir desde Files
    var pdfBookmarkData: Data? = nil

    var pageIndex: Int = 0
    var pins: [Pin] = []

    /// ✅ Nuevo: tamaño por defecto para pins nuevos
    var defaultPinScale: CGFloat = 1.0

    enum CodingKeys: String, CodingKey {
        case id, name, pdfBookmarkData, pageIndex, pins, defaultPinScale
    }

    // ✅ Esto evita que truene al cargar proyectos viejos (sin defaultPinScale)
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Plans App Project"
        pdfBookmarkData = try c.decodeIfPresent(Data.self, forKey: .pdfBookmarkData)

        pageIndex = try c.decodeIfPresent(Int.self, forKey: .pageIndex) ?? 0
        pins = try c.decodeIfPresent([Pin].self, forKey: .pins) ?? []

        defaultPinScale = try c.decodeIfPresent(CGFloat.self, forKey: .defaultPinScale) ?? 1.0
    }

    // ✅ Mantiene tu init normal (por defecto)
    init(
        id: UUID = UUID(),
        name: String = "Plans App Project",
        pdfBookmarkData: Data? = nil,
        pageIndex: Int = 0,
        pins: [Pin] = [],
        defaultPinScale: CGFloat = 1.0
    ) {
        self.id = id
        self.name = name
        self.pdfBookmarkData = pdfBookmarkData
        self.pageIndex = pageIndex
        self.pins = pins
        self.defaultPinScale = defaultPinScale
    }
}
