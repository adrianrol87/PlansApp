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

    // ✅ Cambia el default a uno que EXISTE en tus PDFs
    @State private var selectedType: DeviceType = .alarm_estacion_manual

    @State private var renderedImage: UIImage?

    @State private var isImporterPresented = false
    @State private var showPinsList = false

    // ✅ Catálogo visual (Opción B)
    @State private var showCatalog = false

    @State private var toastText: String?
    @State private var toastTask: Task<Void, Never>?

    @State private var selectedPinID: UUID?
    @State private var showEditPin = false
    @State private var viewerID = UUID()

    private var selectedPinNormalizedPoint: CGPoint? {
        guard let id = selectedPinID,
              let pin = project.pins.first(where: { $0.id == id }) else { return nil }
        return CGPoint(x: pin.x, y: pin.y)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    headerBar

                    if let img = renderedImage {
                        ZoomablePDFImageView(
                            image: img,
                            pins: project.pins.filter { $0.pageIndex == project.pageIndex },
                            selectedPinID: selectedPinID,
                            selectedPinNormalizedPoint: selectedPinNormalizedPoint,
                            onTapInImageSpace: { p in
                                if selectedPinID != nil {
                                    selectedPinID = nil
                                    showToast("Selección cancelada (ya puedes mover/zoom)")
                                    return
                                }
                                addPin(at: p, imageSize: img.size)
                            },
                            onSelectPin: { id in
                                selectedPinID = id
                                showToast("Pin seleccionado (pinch para tamaño, doble tap para editar)")
                            },
                            onEditPin: { id in
                                selectedPinID = id
                                showEditPin = true
                            },
                            onPinScaleCommit: { id, scale in
                                updatePinScale(id: id, scale: scale)
                                project.defaultPinScale = scale
                                try? ProjectStore.shared.save(project)
                                showToast("Tamaño predeterminado actualizado")
                            },
                            onMovePinCommit: { id, nx, ny in
                                updatePinPosition(id: id, x: nx, y: ny)
                                showToast("Pin movido")
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

                if let t = toastText {
                    VStack {
                        Spacer()
                        HStack(spacing: 10) {
                            Image(systemName: "info.circle.fill")
                                .foregroundStyle(.white)
                            Text(t)
                                .foregroundStyle(.white)
                                .font(.footnote)
                                .lineLimit(2)
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color.black.opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal, 14)
                        .padding(.bottom, 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    .allowsHitTesting(false)
                }
            }
            .navigationTitle("Plans App")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { isImporterPresented = true } label: {
                        Label("Importar", systemImage: "square.and.arrow.down")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showPinsList.toggle() } label: {
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
                    showToast("Error importando: \(err.localizedDescription)")
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
            // ✅ Sheet del catálogo visual
            .sheet(isPresented: $showCatalog) {
                DeviceCatalogView(selected: $selectedType)
            }
        }
    }
    
    private func updatePinPosition(id: UUID, x: CGFloat, y: CGFloat) {
        guard let idx = project.pins.firstIndex(where: { $0.id == id }) else { return }
        project.pins[idx].x = x
        project.pins[idx].y = y
        try? ProjectStore.shared.save(project)
    }


    private var headerBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {

                // ✅ Botón que abre el catálogo visual (Opción B)
                Button {
                    showCatalog = true
                } label: {
                    HStack(spacing: 10) {
                        Image(selectedType.assetName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 22, height: 22)

                        Text(selectedType.title)
                            .lineLimit(1)

                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .opacity(0.8)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                Spacer()

                Button { saveProject() } label: {
                    Label("Guardar", systemImage: "square.and.arrow.down.on.square")
                }
                .disabled(renderedImage == nil)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)

            Divider()
        }
        .background(.ultraThinMaterial)
    }

    private func openPDF(_ url: URL) {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }

        for pin in project.pins {
            PhotoStore.shared.deleteAll(for: pin)
        }

        project.pins = []
        project.pageIndex = 0
        selectedPinID = nil
        showEditPin = false

        renderedImage = PDFRenderService.shared.renderPage(url: url, pageIndex: 0)
        viewerID = UUID()

        showToast("PDF cargado")
    }

    private func addPin(at p: CGPoint, imageSize: CGSize) {
        let x = min(max(p.x / imageSize.width, 0), 1)
        let y = min(max(p.y / imageSize.height, 0), 1)

        let pin = Pin(
            pageIndex: project.pageIndex,
            x: x,
            y: y,
            type: selectedType,
            pinScale: project.defaultPinScale
        )

        project.pins.append(pin)
        selectedPinID = pin.id

        showToast("\(selectedType.title) agregado")
    }

    private func updatePinScale(id: UUID, scale: CGFloat) {
        guard let idx = project.pins.firstIndex(where: { $0.id == id }) else { return }
        project.pins[idx].pinScale = scale
        try? ProjectStore.shared.save(project)
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

        showToast("Pin eliminado")
        saveProject()
    }

    private func saveProject() {
        do {
            try ProjectStore.shared.save(project)
            showToast("Guardado")
        } catch {
            showToast("Error al guardar")
        }
    }

    private func showToast(_ text: String) {
        toastTask?.cancel()
        withAnimation(.easeInOut(duration: 0.18)) { toastText = text }
        toastTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            withAnimation(.easeInOut(duration: 0.18)) { toastText = nil }
        }
    }
}
