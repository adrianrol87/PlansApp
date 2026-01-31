//
//  AppFileSystem.swift
//  PlansApp
//
//  Created by Adrian Rodriguez Llorens on 30/01/26.
//

import Foundation

enum AppFileSystem {
    static let rootFolder = "PlansApp"
    static let projectsFolder = "Projects"
    static let pdfsFolder = "PDFs"
    static let editorFolder = "EditorState"
    static let projectJSON = "project.json"

    static var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    static var rootURL: URL {
        documentsURL.appendingPathComponent(rootFolder, isDirectory: true)
    }

    static var projectsRootURL: URL {
        rootURL.appendingPathComponent(projectsFolder, isDirectory: true)
    }

    static func ensureBase() throws {
        try ensureFolder(rootURL)
        try ensureFolder(projectsRootURL)
    }

    static func projectURL(_ id: UUID) -> URL {
        projectsRootURL.appendingPathComponent(id.uuidString, isDirectory: true)
    }

    static func projectPDFsURL(_ id: UUID) -> URL {
        projectURL(id).appendingPathComponent(pdfsFolder, isDirectory: true)
    }

    static func projectEditorURL(_ id: UUID) -> URL {
        projectURL(id).appendingPathComponent(editorFolder, isDirectory: true)
    }

    static func projectJSONURL(_ id: UUID) -> URL {
        projectURL(id).appendingPathComponent(projectJSON, isDirectory: false)
    }

    static func sheetEditorJSONURL(projectID: UUID, sheetID: UUID) -> URL {
        projectEditorURL(projectID).appendingPathComponent("sheet_\(sheetID.uuidString).json", isDirectory: false)
    }

    static func ensureProjectFolders(_ id: UUID) throws {
        try ensureBase()
        try ensureFolder(projectURL(id))
        try ensureFolder(projectPDFsURL(id))
        try ensureFolder(projectEditorURL(id))
    }

    static func ensureFolder(_ url: URL) throws {
        let fm = FileManager.default
        if !fm.fileExists(atPath: url.path) {
            try fm.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
}
