//
//  ProjectStore.swift
//  PlansApp
//
//  Created by Adrian Rodriguez Llorens on 27/01/26.
//

import Foundation

final class ProjectStore {
    static let shared = ProjectStore()
    private init() {}

    private let filename = "plans_app_project.json"

    private var fileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent(filename)
    }

    func save(_ project: PlanProject) throws {
        let data = try JSONEncoder().encode(project)
        try data.write(to: fileURL, options: [.atomic])
    }

    func load() -> PlanProject? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(PlanProject.self, from: data)
    }
}
