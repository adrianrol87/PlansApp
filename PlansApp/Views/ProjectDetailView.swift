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

    // Renombrar
    @State private var sheetToRename: AppSheet?
    @State private var newSheetName = ""

    // Eliminar
    @State private var sheetToDelete: AppSheet?
    @State private var showDeleteConfirm = false

    var body: some View {
        Group {
            if let project {
                List {
                    Section("Planos") {
                        ForEach(project.sheets) { sheet in
                            HStack(spacing: 10) {
                                // ✅ Link al editor
                                NavigationLink {
                                    SheetEditorHostView(projectID: project.id, sheet: sheet)
                                        .id(sheet.id)
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(sheet.name)
                                            .font(.headline)

                                        Text(sheet.pdfFilename)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                // ✅ Botón ⋯ (acciones)
                                Menu {
                                    Button {
                                        sheetToRename = sheet
                                        newSheetName = sheet.name
                                    } label: {
                                        Label("Renombrar", systemImage: "pencil")
                                    }

                                    Divider()

                                    Button(role: .destructive) {
                                        sheetToDelete = sheet
                                        showDeleteConfirm = true
                                    } label: {
                                        Label("Eliminar", systemImage: "trash")
                                    }

                                } label: {
                                    Image(systemName: "ellipsis.circle")
                                        .font(.title3)
                                        .foregroundStyle(.secondary)
                                        .padding(.leading, 4)
                                }
                                .buttonStyle(.plain)
                                .contentShape(Rectangle())
                            }
                        }
                        .onMove(perform: moveSheet)
                        .onDelete(perform: requestDelete) // swipe delete sigue funcionando
                    }
                }
            } else {
                ProgressView("Cargando…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(project?.name ?? "Proyecto")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                EditButton() // ordenar
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { isImporter = true } label: {
                    Label("Importar PDF", systemImage: "square.and.arrow.down")
                }
            }
        }
        .fileImporter(
            isPresented: $isImporter,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                do {
                    _ = try mgr.importPDF(
                        into: projectID,
                        sourceURL: url,
                        displayName: url.deletingPathExtension().lastPathComponent
                    )
                    load()
                } catch {
                    err = error.localizedDescription
                }
            case .failure(let e):
                err = e.localizedDescription
            }
        }
        // ✅ Renombrar (alert con TextField)
        .alert("Renombrar plano", isPresented: Binding(
            get: { sheetToRename != nil },
            set: { if !$0 { sheetToRename = nil } }
        )) {
            TextField("Nombre", text: $newSheetName)
            Button("Guardar") { renameSheet() }
            Button("Cancelar", role: .cancel) { sheetToRename = nil }
        } message: {
            Text("Cambia solo el nombre visible. El PDF no se renombra.")
        }
        // ✅ Eliminar
        .confirmationDialog(
            "¿Eliminar plano?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Eliminar", role: .destructive) { confirmDelete() }
            Button("Cancelar", role: .cancel) { sheetToDelete = nil }
        } message: {
            Text("Se borrará el PDF, los pines y las fotos asociadas.")
        }
        // Error
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

    // MARK: - Actions

    private func load() {
        do { project = try mgr.load(projectID: projectID) }
        catch { err = error.localizedDescription }
    }

    private func moveSheet(from source: IndexSet, to destination: Int) {
        guard var project else { return }
        project.sheets.move(fromOffsets: source, toOffset: destination)

        do {
            try mgr.save(project)
            self.project = project
        } catch {
            err = error.localizedDescription
        }
    }

    private func requestDelete(at offsets: IndexSet) {
        guard let project, let idx = offsets.first else { return }
        sheetToDelete = project.sheets[idx]
        showDeleteConfirm = true
    }

    private func confirmDelete() {
        guard let sheet = sheetToDelete else { return }
        do {
            try mgr.deleteSheet(projectID: projectID, sheet: sheet)
            sheetToDelete = nil
            load()
        } catch {
            err = error.localizedDescription
        }
    }

    private func renameSheet() {
        guard var project,
              let sheet = sheetToRename,
              let idx = project.sheets.firstIndex(of: sheet)
        else { return }

        let trimmed = newSheetName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            err = "El nombre no puede estar vacío."
            return
        }

        project.sheets[idx].name = trimmed

        do {
            try mgr.save(project)
            self.project = project
            sheetToRename = nil
        } catch {
            err = error.localizedDescription
        }
    }
}
