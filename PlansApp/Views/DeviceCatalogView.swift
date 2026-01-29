//
//  DeviceCatalogView.swift
//  PlansApp
//
//  Created by Adrian Rodriguez Llorens on 28/01/26.
//

import SwiftUI

struct DeviceCatalogView: View {
    @Binding var selected: DeviceType
    @Environment(\.dismiss) private var dismiss

    @State private var discipline: Discipline = .alarm
    @State private var query: String = ""

    private var items: [DeviceType] {
        let base = DeviceType.items(for: discipline)
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return base }
        let q = query.lowercased()
        return base.filter { $0.title.lowercased().contains(q) || $0.assetName.lowercased().contains(q) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Picker("Disciplina", selection: $discipline) {
                    ForEach(Discipline.allCases) { d in
                        Text(d.rawValue).tag(d)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                TextField("Buscar…", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)

                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 12)], spacing: 12) {
                        ForEach(items) { item in
                            Button {
                                selected = item
                                dismiss()
                            } label: {
                                VStack(spacing: 8) {
                                    Image(item.assetName)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 56, height: 56)
                                        .padding(10)
                                        .background(.thinMaterial)
                                        .clipShape(RoundedRectangle(cornerRadius: 14))

                                    Text(item.title)
                                        .font(.caption)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.center)
                                }
                                .padding(6)
                                .frame(maxWidth: .infinity)
                                .background(selected == item ? Color.yellow.opacity(0.25) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 6)
                }
            }
            .navigationTitle("Catálogo")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }
}
