//
//  PinEditView.swift
//  PlansApp
//
//  Created by Adrian Rodriguez Llorens on 27/01/26.
//

import SwiftUI

struct PinEditView: View {
    @Binding var pin: Pin
    var onDelete: () -> Void
    var onDone: () -> Void

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

            Section {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Eliminar pin", systemImage: "trash")
                }
            }
        }
        .navigationTitle("Editar pin")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Listo") { onDone() }
            }
        }
    }
}

