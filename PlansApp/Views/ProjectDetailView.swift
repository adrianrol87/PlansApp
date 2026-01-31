//
//  ProjectDetailView.swift
//  PlansApp
//
//  Created by Adrian Rodriguez Llorens on 30/01/26.
//

import SwiftUI
import UniformTypeIdentifiers

struct ProjectDetailView: View {
    let projectID: UUID
    @ObservedObject private var mgr = ProjectsManager.shared

    @State private var project: AppProject?
    @State private var isImporter = false
    @State private var err: String?

    var body: some View {
        Group {
            if let project {
                List {
                    Section("Planos") {
                        if project.sheets.isEmpty {
                            Text("Importa un PDF para empezar.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(project.sheets) { sheet in
                                NavigationLink {
                                    // editor por sheet
                                    SheetEditorHostView(projectID: project.id, sheet: sheet)
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(sheet.name).font(.headline)
                                        Text(sheet.pdfFilename)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            } else {
                ProgressView("Cargando…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(project?.name ?? "Proyecto")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isImporter = true
                } label: {
                    Label("Importar PDF", systemImage: "square.and.arrow.down")
                }
            }
        }
        .fileImporter(isPresented: $isImporter,
                      allowedContentTypes: [.pdf],
                      allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                do {
                    _ = try mgr.importPDF(into: projectID, sourceURL: url,
                                          displayName: url.deletingPathExtension().lastPathComponent)
                    load()
                } catch {
                    err = error.localizedDescription
                }
            case .failure(let e):
                err = e.localizedDescription
            }
        }
        .alert("Error", isPresented: Binding(
            get: { err != nil },
            set: { if !$0 { err = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(err ?? "")
        }
        .onAppear { load() }
    }

    private func load() {
        do { project = try mgr.load(projectID: projectID) }
        catch { err = error.localizedDescription }
    }
}

