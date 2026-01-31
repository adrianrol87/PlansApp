//
//  PlanProject.swift
//  PlansApp
//
//  Created by Adrian Rodriguez Llorens on 27/01/26.
//

import Foundation

struct PlanProject: Codable {
    var id: UUID = UUID()
    var name: String = "Plans App Project"

    var pdfBookmarkData: Data? = nil
    var pageIndex: Int = 0
    var pins: [Pin] = []

    /// default para nuevos pins
    var defaultPinScale: CGFloat = 1.0

    /// ✅ Nuevo: dibujo por plano (PencilKit). Se guarda como Data.
    var drawingData: Data? = nil
}
