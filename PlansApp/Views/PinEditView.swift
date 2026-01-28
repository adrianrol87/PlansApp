//
//  PinEditView.swift
//  PlansApp
//
//  Created by Adrian Rodriguez Llorens on 27/01/26.
//

import SwiftUI
import UIKit

struct PinEditView: View {
    @Binding var pin: Pin
    var onDelete: () -> Void
    var onDone: () -> Void

    @State private var previewImages: [UIImage] = []

    private enum ActiveSheet: Identifiable {
        case camera, library, fullscreen(UIImage)

        var id: String {
            switch self {
            case .camera: return "camera"
            case .library: return "library"
            case .fullscreen: return "fullscreen"
            }
        }
    }

    @State private var activeSheet: ActiveSheet?

    private let maxPhotos = 3

    var body: some View {
        Form {
            Section("Tipo") {
                Picker("Dispositivo", selection: $pin.type) {
                    ForEach(DeviceType.allCases) { t in
                        Label(t.title, systemImage: t.systemImageName)
                            .tag(t)
                    }
                }
            }

            Section("Nota") {
                TextField("Escribe una nota…", text: Binding(
                    get: { pin.note ?? "" },
                    set: { pin.note = $0.isEmpty ? nil : $0 }
                ))
            }

            Section("Fotos") {
                photosGrid

                if pin.photoFilenames.count < maxPhotos {
                    HStack {
                        Button {
                            activeSheet = .library
                        } label: {
                            Label("Elegir foto", systemImage: "photo")
                        }
                        .buttonStyle(.borderless)

                        Spacer()

                        Button {
                            activeSheet = .camera
                        } label: {
                            Label("Tomar foto", systemImage: "camera")
                        }
                        .buttonStyle(.borderless)
                        .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
                    }
                }
            }

            Section {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Eliminar pin", systemImage: "trash")
                }
                .buttonStyle(.borderless)
            }
        }
        .navigationTitle("Editar pin")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Listo") { onDone() }
            }
        }
        .onAppear {
            previewImages = pin.photoFilenames.compactMap {
                PhotoStore.shared.loadImage(filename: $0)
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .camera:
                CameraPicker { img in addPhoto(img) }

            case .library:
                PhotoLibraryPicker { img in addPhoto(img) }

            case .fullscreen(let image):
                PhotoFullscreenView(image: image)
            }
        }
    }

    // MARK: - UI

    @ViewBuilder
    private var photosGrid: some View {
        if previewImages.isEmpty {
            ContentUnavailableView(
                "Sin fotos",
                systemImage: "photo",
                description: Text("Puedes agregar hasta 3 fotos por pin.")
            )
            .frame(maxWidth: .infinity)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("\(previewImages.count) de \(maxPhotos) fotos")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 3)) {
                    ForEach(previewImages.indices, id: \.self) { i in
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: previewImages[i])
                                .resizable()
                                .scaledToFill()
                                .frame(height: 90)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .onTapGesture {
                                    activeSheet = .fullscreen(previewImages[i])
                                }

                            Button {
                                removePhoto(at: i)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.white)
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .offset(x: -4, y: 4)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Logic

    private func addPhoto(_ img: UIImage) {
        guard pin.photoFilenames.count < maxPhotos else { return }

        do {
            let index = pin.photoFilenames.count + 1
            let filename = try PhotoStore.shared.saveJPEG(
                image: img,
                pinID: pin.id,
                index: index
            )
            pin.photoFilenames.append(filename)
            previewImages.append(img)
        } catch {
            print("Error guardando foto: \(error)")
        }
    }

    private func removePhoto(at index: Int) {
        let filename = pin.photoFilenames[index]
        PhotoStore.shared.delete(filename: filename)
        pin.photoFilenames.remove(at: index)
        previewImages.remove(at: index)
    }
}
