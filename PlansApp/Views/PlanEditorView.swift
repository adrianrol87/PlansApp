//
//  PlanEditorView.swift
//  PlansApp
//
//  Created by Adrian Rodriguez Llorens on 27/01/26.
//

import SwiftUI
import UniformTypeIdentifiers

struct PlanEditorView: View {
    @State private var project: PlanProject = ProjectStore.shared.load() ?? PlanProject()
    @State private var selectedType: DeviceType = .manualStation

    @State private var pdfURL: URL?
    @State private var renderedImage: UIImage?

    @State private var isImporterPresented = false
    @State private var showPinsList = false
    @State private var statusText: String?

    // Selección / edición
    @State private var selectedPinID: UUID?
    @State private var showEditPin = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerBar

                if let img = renderedImage {
                    ZoomablePDFImageView(
                        image: img,
                        pins: project.pins.filter { $0.pageIndex == project.pageIndex },
                        selectedPinID: selectedPinID,
                        onTapInImageSpace: { p in
                            // Tap en plano: agrega pin nuevo
                            addPin(at: p, imageSize: img.size)
                        },
                        onSelectPin: { id in
                            // Tap en pin: selecciona + abre editor
                            selectedPinID = id
                            showEditPin = true
                        }
                    )
                } else {
                    ContentUnavailableView(
                        "Plans App",
                        systemImage: "doc.richtext",
                        description: Text("Importa un plano PDF para empezar a colocar dispositivos.")
                    )
                }
            }
            .navigationTitle("Plans App")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isImporterPresented = true
                    } label: {
                        Label("Importar", systemImage: "square.and.arrow.down")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showPinsList.toggle()
                    } label: {
                        Label("Pins", systemImage: "list.bullet")
                    }
                    .disabled(renderedImage == nil)
                }
            }
            .fileImporter(
                isPresented: $isImporterPresented,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    openPDF(url)
                case .failure(let err):
                    statusText = "Error importando: \(err.localizedDescription)"
                }
            }
            .sheet(isPresented: $showPinsList) {
                NavigationStack {
                    PinListView(pins: $project.pins, pageIndex: project.pageIndex)
                        .navigationTitle("Dispositivos")
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Cerrar") { showPinsList = false }
                            }
                        }
                }
            }
            // Editor pin
            .sheet(isPresented: $showEditPin) {
                if let binding = bindingForSelectedPin() {
                    NavigationStack {
                        PinEditView(
                            pin: binding,
                            onDelete: {
                                deleteSelectedPin()
                                showEditPin = false
                            },
                            onDone: {
                                saveProject()
                                showEditPin = false
                            }
                        )
                    }
                } else {
                    Text("Pin no encontrado")
                        .padding()
                }
            }
        }
    }

    private var headerBar: some View {
        HStack {
            DevicePickerView(selected: $selectedType)

            Spacer()

            Button {
                saveProject()
            } label: {
                Label("Guardar", systemImage: "square.and.arrow.down.on.square")
            }
            .disabled(renderedImage == nil)
        }
        .padding()
        .overlay(alignment: .bottomLeading) {
            if let t = statusText {
                Text(t)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding([.leading, .bottom])
            }
        }
    }

    private func openPDF(_ url: URL) {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }

        pdfURL = url
        project.pageIndex = 0
        project.pins = []

        selectedPinID = nil
        showEditPin = false

        renderedImage = PDFRenderService.shared.renderPage(url: url, pageIndex: 0)
        statusText = renderedImage == nil ? "No se pudo renderizar el PDF" : "PDF cargado"
    }

    private func addPin(at p: CGPoint, imageSize: CGSize) {
        guard imageSize.width > 0, imageSize.height > 0 else { return }

        let x = min(max(p.x / imageSize.width, 0), 1)
        let y = min(max(p.y / imageSize.height, 0), 1)

        let pin = Pin(pageIndex: project.pageIndex, x: x, y: y, type: selectedType)
        project.pins.append(pin)

        // Selecciona el último para que se vea highlight si quieres
        selectedPinID = pin.id

        statusText = "\(selectedType.title) agregado"
    }

    private func saveProject() {
        do {
            try ProjectStore.shared.save(project)
            statusText = "Guardado"
        } catch {
            statusText = "Error guardando: \(error.localizedDescription)"
        }
    }

    // MARK: - Edición de pin
    private func bindingForSelectedPin() -> Binding<Pin>? {
        guard let id = selectedPinID,
              let idx = project.pins.firstIndex(where: { $0.id == id }) else { return nil }
        return $project.pins[idx]
    }

    private func deleteSelectedPin() {
        guard let id = selectedPinID else { return }
        project.pins.removeAll { $0.id == id }
        selectedPinID = nil
        statusText = "Pin eliminado"
        saveProject()
    }
}
