//
//  ProjectsHomeView.swift
//  PlansApp
//
//  Created by Adrian Rodriguez Llorens on 30/01/26.
//

import SwiftUI

struct ProjectsHomeView: View {
    @ObservedObject private var mgr = ProjectsManager.shared

    @State private var showNew = false
    @State private var err: String?

    var body: some View {
        NavigationStack {
            List {
                if mgr.projects.isEmpty {
                    ContentUnavailableView(
                        "Sin proyectos",
                        systemImage: "folder",
                        description: Text("Crea un proyecto y agrega tus PDFs.")
                    )
                } else {
                    ForEach(mgr.projects) { p in
                        NavigationLink {
                            ProjectDetailView(projectID: p.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(p.name).font(.headline)
                                Text("\(p.sheets.count) plano(s)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { idx in
                        for i in idx {
                            do { try mgr.deleteProject(mgr.projects[i]) }
                            catch { err = error.localizedDescription }
                        }
                    }
                }
            }
            .navigationTitle("Projects")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showNew = true
                    } label: {
                        Label("Nuevo", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showNew) {
                NewProjectView { name in
                    do { _ = try mgr.createProject(name: name) }
                    catch { err = error.localizedDescription }
                    showNew = false
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
            .onAppear { mgr.refresh() }
        }
    }
}

