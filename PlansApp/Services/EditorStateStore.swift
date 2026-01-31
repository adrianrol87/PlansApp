//
//  EditorStateStore.swift
//  PlansApp
//
//  Created by Adrian Rodriguez Llorens on 30/01/26.
//

import Foundation

struct EditorStateStore {
    let url: URL

    func save(_ state: PlanProject) throws {
        let data = try JSONEncoder().encode(state)
        try data.write(to: url, options: [.atomic])
    }

    func load() -> PlanProject? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(PlanProject.self, from: data)
    }
}

