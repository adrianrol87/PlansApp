//
//  AppSheet.swift
//  PlansApp
//
//  Created by Adrian Rodriguez Llorens on 30/01/26.
//

import Foundation

struct AppSheet: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var pdfFilename: String
    var createdAt: Date = Date()
}

