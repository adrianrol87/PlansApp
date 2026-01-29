//
//  PinEditView.swift
//  PlansApp
//
//  Created by Adrian Rodriguez Llorens on 27/01/26.
//

import SwiftUI
import UIKit
import AVFoundation
import PhotosUI

struct PinEditView: View {
    @Binding var pin: Pin

    let onDelete: () -> Void
    let onDone: () -> Void

    @Environment(\.dismiss) private var dismiss

    private let maxPhotosPerPin = 3

    // Catálogo
    @State private var showCatalog = false

    // Cámara / Biblioteca
    @State private var showCamera = false
    @State private var pickedItem: PhotosPickerItem?

    // Fullscreen photo
    @State private var fullscreenImage: IdentifiedImage?

    // Alertas
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    // ✅ Binding simple para tu note opcional
    private var noteText: Binding<String> {
        Binding<String>(
            get: { pin.note ?? "" },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                pin.note = trimmed.isEmpty ? nil : newValue
            }
        )
    }

    private var canAddPhoto: Bool {
        pin.photoFilenames.count < maxPhotosPerPin
    }

    var body: some View {
        Form {
            deviceSection
            notesSection
            scaleSection
            photosSection
            deleteSection
        }
        .navigationTitle("Editar pin")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { Button("Cerrar") { dismiss() } }
            ToolbarItem(placement: .topBarTrailing) { Button("Listo") { onDone() } }
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: $showCatalog) {
            DeviceCatalogView(selected: Binding(
                get: { pin.type },
                set: { pin.type = $0 }
            ))
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in
                addPhoto(image)
                showCamera = false
            }
        }
        .onChange(of: pickedItem) { _, newItem in
            guard let item = newItem else { return }
            Task {
                do {
                    if let data = try await item.loadTransferable(type: Data.self),
                       let img = UIImage(data: data) {
                        addPhoto(img)
                    }
                } catch {
                    print("Error cargando imagen de galería:", error)
                }
                await MainActor.run { pickedItem = nil }
            }
        }
        .fullScreenCover(item: $fullscreenImage) { item in
            FullscreenPhotoView(image: item.image) {
                fullscreenImage = nil
            }
        }
    }

    // MARK: - Sections

    private var deviceSection: some View {
        Section("Dispositivo") {
            HStack(spacing: 12) {
                Image(pin.type.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 34, height: 34)
                    .padding(6)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 3) {
                    Text(pin.type.title)
                        .font(.headline)
                    Text(pin.type.assetName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Cambiar") { showCatalog = true }
                    .buttonStyle(.borderless)
            }
        }
    }

    private var notesSection: some View {
        Section("Notas") {
            TextField("Escribe una nota…", text: noteText, axis: .vertical)
                .lineLimit(4...10)
        }
    }

    private var scaleSection: some View {
        Section("Escala") {
            LabeledContent("Tamaño del pin") {
                Text("\(pin.pinScale, specifier: "%.2f")")
            }
            Text("Tip: este valor es solo referencia para comparar entre pines.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var photosSection: some View {
        Section("Fotos") {
            if pin.photoFilenames.isEmpty {
                Text("Sin fotos (máximo \(maxPhotosPerPin) por pin)")
                    .foregroundStyle(.secondary)
            } else {
                Text("\(pin.photoFilenames.count) / \(maxPhotosPerPin) fotos")
                    .foregroundStyle(.secondary)
            }

            Button {
                guard canAddPhoto else { return }
                openCameraSafely()
            } label: {
                Label("Tomar foto", systemImage: "camera")
            }
            .disabled(!canAddPhoto)

            PhotosPicker(selection: $pickedItem, matching: .images, photoLibrary: .shared()) {
                Label("Elegir foto", systemImage: "photo.on.rectangle")
            }
            .disabled(!canAddPhoto)

            if !canAddPhoto {
                Text("Alcanzaste el máximo de \(maxPhotosPerPin) fotos por pin.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if !pin.photoFilenames.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(pin.photoFilenames, id: \.self) { filename in
                            PhotoThumbView(
                                filename: filename,
                                onOpen: { img in
                                    fullscreenImage = IdentifiedImage(image: img)
                                },
                                onDelete: {
                                    deletePhoto(filename: filename)
                                }
                            )
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
    }

    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Eliminar pin", systemImage: "trash")
            }
        }
    }

    // MARK: - Photo helpers

    private func openCameraSafely() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            alertTitle = "Cámara no disponible"
            alertMessage = "Este dispositivo no tiene cámara o no está disponible en este momento."
            showAlert = true
            return
        }

        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            showCamera = true

        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.showCamera = true
                    } else {
                        self.alertTitle = "Permiso de cámara"
                        self.alertMessage = "Activa el permiso en Ajustes > Privacidad y seguridad > Cámara."
                        self.showAlert = true
                    }
                }
            }

        case .denied, .restricted:
            alertTitle = "Cámara bloqueada"
            alertMessage = "La cámara está desactivada para esta app. Revisa Ajustes > Privacidad y seguridad > Cámara y Tiempo en pantalla."
            showAlert = true

        @unknown default:
            alertTitle = "Error"
            alertMessage = "No se pudo verificar el permiso de cámara."
            showAlert = true
        }
    }

    private func addPhoto(_ image: UIImage) {
        guard canAddPhoto else { return }
        do {
            let nextIndex = nextPhotoIndex(pinID: pin.id, existingFilenames: pin.photoFilenames)
            let filename = try PhotoStore.shared.saveJPEG(
                image: image,
                pinID: pin.id,
                index: nextIndex
            )
            pin.photoFilenames.append(filename)
        } catch {
            print("Error guardando foto:", error.localizedDescription)
        }
    }

    private func deletePhoto(filename: String) {
        PhotoStore.shared.delete(filename: filename)
        pin.photoFilenames.removeAll { $0 == filename }
    }

    private func nextPhotoIndex(pinID: UUID, existingFilenames: [String]) -> Int {
        let prefix = "pin_\(pinID.uuidString)_"
        var maxIndex = -1
        for fn in existingFilenames where fn.hasPrefix(prefix) {
            let tail = fn.replacingOccurrences(of: prefix, with: "")
            let numberPart = tail.replacingOccurrences(of: ".jpg", with: "")
            if let n = Int(numberPart) { maxIndex = max(maxIndex, n) }
        }
        return maxIndex + 1
    }
}

// MARK: - Miniatura
private struct PhotoThumbView: View {
    let filename: String
    let onOpen: (UIImage) -> Void
    let onDelete: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button {
                if let img = PhotoStore.shared.loadImage(filename: filename) {
                    onOpen(img)
                }
            } label: {
                Group {
                    if let img = PhotoStore.shared.loadImage(filename: filename) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                    } else {
                        ZStack {
                            Color.gray.opacity(0.15)
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(width: 86, height: 86)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)

            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18, weight: .bold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.65))
                    .padding(6)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Fullscreen wrapper
private struct IdentifiedImage: Identifiable {
    let id = UUID()
    let image: UIImage
}
