//
//  PinListView.swift
//  PlansApp
//
//  Created by Adrian Rodriguez Llorens on 27/01/26.
//

import SwiftUI

struct PinListView: View {
    @Binding var pins: [Pin]
    let pageIndex: Int

    // Pins visibles en esta página
    private var visiblePins: [Pin] {
        pins.filter { $0.pageIndex == pageIndex }
    }

    var body: some View {
        List {
            ForEach(visiblePins, id: \.id) { pin in
                HStack(spacing: 12) {

                    // ✅ Ahora usamos tu PDF como asset (no SF Symbol)
                    Image(pin.type.assetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                        .padding(6)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(pin.type.title)
                            .font(.headline)

                        Text("x: \(pin.x, specifier: "%.3f")  y: \(pin.y, specifier: "%.3f")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if !pin.photoFilenames.isEmpty {
                        Image(systemName: "camera.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete(perform: deletePins)
        }
    }

    private func deletePins(at offsets: IndexSet) {
        // offsets corresponde a visiblePins, no al array principal pins
        let idsToDelete: [UUID] = offsets.map { visiblePins[$0].id }

        // borrar fotos y pins reales del array principal
        for id in idsToDelete {
            if let pin = pins.first(where: { $0.id == id }) {
                PhotoStore.shared.deleteAll(for: pin)
            }
        }

        pins.removeAll { idsToDelete.contains($0.id) }
    }
}
