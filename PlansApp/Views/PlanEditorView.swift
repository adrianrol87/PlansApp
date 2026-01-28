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

    @State private var renderedImage: UIImage?

    @State private var isImporterPresented = false
    @State private var showPinsList = false

    // Status
    @State private var statusText: String?
    @State private var statusTask: Task<Void, Never>?

    // Selección / edición
    @State private var selectedPinID: UUID?
    @State private var showEditPin = false

    // Fuerza recreación del visor al cambiar PDF
    @State private var viewerID = UUID()

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
                            addPin(at: p, imageSize: img.size)
                        },
                        onSelectPin: { id in
                            selectedPinID = id
                            showEditPin = true
                        }
                    )
                    .id(viewerID)
                } else {
                    ContentUnavailableView(
                        "Plans App",
                        systemImage: "doc.richtext",
                        description: Text("Importa un plano PDF para empezar.")
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
                    setStatus("Error importando: \(err.localizedDescription)")
                }
            }
            .sheet(isPresented: $showPinsList) {
                NavigationStack {
                    PinListView(
                        pins: $project.pins,
                        pageIndex: project.pageIndex
                    )
                    .navigationTitle("Dispositivos")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Cerrar") { showPinsList = false }
                        }
                    }
                }
            }
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
                }
            }
        }
    }

    // MARK: - Header
    private var headerBar: some View {
        VStack(spacing: 6) {
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
            .padding(.horizontal)
            .padding(.top, 10)

            if let t = statusText {
                HStack {
                    Image(systemName: "info.circle")
                    Text(t)
                        .font(.caption)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom, 6)
            }

            Divider()
        }
        .background(.ultraThinMaterial)
    }

    // MARK: - PDF
    private func openPDF(_ url: URL) {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }

        // Limpia fotos del proyecto actual
        for pin in project.pins {
            PhotoStore.shared.deleteAll(for: pin)
        }

        project.pins = []
        project.pageIndex = 0
        selectedPinID = nil
        showEditPin = false

        renderedImage = PDFRenderService.shared.renderPage(url: url, pageIndex: 0)
        viewerID = UUID()

        setStatus("PDF cargado")
    }

    // MARK: - Pins
    private func addPin(at p: CGPoint, imageSize: CGSize) {
        let x = min(max(p.x / imageSize.width, 0), 1)
        let y = min(max(p.y / imageSize.height, 0), 1)

        let pin = Pin(
            pageIndex: project.pageIndex,
            x: x,
            y: y,
            type: selectedType
        )

        project.pins.append(pin)
        selectedPinID = pin.id

        setStatus("\(selectedType.title) agregado")
    }

    private func bindingForSelectedPin() -> Binding<Pin>? {
        guard let id = selectedPinID,
              let idx = project.pins.firstIndex(where: { $0.id == id }) else { return nil }
        return $project.pins[idx]
    }

    private func deleteSelectedPin() {
        guard let id = selectedPinID,
              let pin = project.pins.first(where: { $0.id == id }) else { return }

        PhotoStore.shared.deleteAll(for: pin)
        project.pins.removeAll { $0.id == id }
        selectedPinID = nil

        setStatus("Pin eliminado")
        saveProject()
    }

    // MARK: - Save / Status
    private func saveProject() {
        do {
            try ProjectStore.shared.save(project)
            setStatus("Guardado")
        } catch {
            setStatus("Error al guardar")
        }
    }

    private func setStatus(_ text: String) {
        statusTask?.cancel()
        statusText = text

        statusTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            statusText = nil
        }
    }
}
