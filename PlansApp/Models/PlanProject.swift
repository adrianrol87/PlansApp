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

    /// Opcional: si luego guardas el PDF con bookmark para reabrir desde Files
    var pdfBookmarkData: Data? = nil

    var pageIndex: Int = 0
    var pins: [Pin] = []
}
