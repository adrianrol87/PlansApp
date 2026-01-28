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

    var body: some View {
        List {
            let visible = pins.enumerated().filter { $0.element.pageIndex == pageIndex }

            ForEach(visible, id: \.element.id) { pair in
                let pin = pair.element
                HStack {
                    Image(systemName: pin.type.systemImageName)
                    VStack(alignment: .leading) {
                        Text(pin.type.title).font(.headline)
                        Text("x: \(pin.x, specifier: "%.3f")  y: \(pin.y, specifier: "%.3f")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete { idxSet in
                // idxSet corresponde a "visible", hay que mapear a índices reales
                let realIndexes = idxSet.map { visible[$0].offset }.sorted(by: >)
                for i in realIndexes { pins.remove(at: i) }
            }
        }
    }
}
