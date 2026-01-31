//
//  ProjectsManager.swift
//  PlansApp
//
//  Created by Adrian Rodriguez Llorens on 30/01/26.
//

import Foundation
import UniformTypeIdentifiers
import Combine

final class ProjectsManager: ObservableObject {
    static let shared = ProjectsManager()
    private init() { refresh() }

    @Published private(set) var projects: [AppProject] = []

    // MARK: - Public

    func refresh() {
        do {
            try AppFileSystem.ensureBase()
            projects = try loadAll().sorted { $0.updatedAt > $1.updatedAt }
        } catch {
            print("ProjectsManager.refresh error:", error)
            projects = []
        }
    }

    func createProject(name: String) throws -> AppProject {
        var p = AppProject(name: name)
        try AppFileSystem.ensureProjectFolders(p.id)
        try save(p)
        refresh()
        return p
    }

    func deleteProject(_ p: AppProject) throws {
        try AppFileSystem.ensureBase()
        let fm = FileManager.default
        let folder = AppFileSystem.projectURL(p.id)
        if fm.fileExists(atPath: folder.path) {
            try fm.removeItem(at: folder)
        }
        refresh()
    }

    func load(projectID: UUID) throws -> AppProject {
        let url = AppFileSystem.projectJSONURL(projectID)
        let data = try Data(contentsOf: url)

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601   // ✅ CLAVE
        return try dec.decode(AppProject.self, from: data)
    }

    func save(_ project: AppProject) throws {
        var p = project
        p.updatedAt = Date()

        let url = AppFileSystem.projectJSONURL(p.id)

        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601   // ✅ guardamos ISO8601

        let data = try enc.encode(p)
        try data.write(to: url, options: [.atomic])

        if let i = projects.firstIndex(where: { $0.id == p.id }) {
            projects[i] = p
        } else {
            projects.append(p)
        }
        projects.sort { $0.updatedAt > $1.updatedAt }
    }

    func importPDF(into projectID: UUID, sourceURL: URL, displayName: String? = nil) throws -> AppSheet {
        try AppFileSystem.ensureProjectFolders(projectID)
        var p = try load(projectID: projectID)

        let fm = FileManager.default
        let folder = AppFileSystem.projectPDFsURL(projectID)

        let name = displayName ?? sourceURL.deletingPathExtension().lastPathComponent
        let safeName = sanitize(name)

        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let destFilename = "\(safeName)_\(stamp).pdf"
        let destURL = folder.appendingPathComponent(destFilename)

        let access = sourceURL.startAccessingSecurityScopedResource()
        defer { if access { sourceURL.stopAccessingSecurityScopedResource() } }

        if fm.fileExists(atPath: destURL.path) { try fm.removeItem(at: destURL) }
        try fm.copyItem(at: sourceURL, to: destURL)

        let sheet = AppSheet(name: name, pdfFilename: destFilename)
        p.sheets.append(sheet)

        try save(p)
        refresh()
        return sheet
    }

    func pdfURL(projectID: UUID, pdfFilename: String) -> URL {
        AppFileSystem.projectPDFsURL(projectID).appendingPathComponent(pdfFilename)
    }

    // MARK: - Private

    private func loadAll() throws -> [AppProject] {
        try AppFileSystem.ensureBase()

        let fm = FileManager.default
        let dirs = try fm.contentsOfDirectory(
            at: AppFileSystem.projectsRootURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601   // ✅ CLAVE

        var out: [AppProject] = []
        for dir in dirs {
            let json = dir.appendingPathComponent(AppFileSystem.projectJSON)
            if fm.fileExists(atPath: json.path) {
                do {
                    let data = try Data(contentsOf: json)
                    let p = try dec.decode(AppProject.self, from: data)
                    out.append(p)
                } catch {
                    print("Bad project json:", json.lastPathComponent, error)
                }
            }
        }
        return out
    }

    private func sanitize(_ raw: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(.init(charactersIn: " _-"))
        let filtered = raw.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }
        let str = String(filtered)
            .replacingOccurrences(of: "__", with: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return str.isEmpty ? "Plano" : str
    }
}
