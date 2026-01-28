//
//  DevicePickerView.swift
//  PlansApp
//
//  Created by Adrian Rodriguez Llorens on 27/01/26.
//

import SwiftUI

struct DevicePickerView: View {
    @Binding var selected: DeviceType

    var body: some View {
        Menu {
            ForEach(DeviceType.allCases) { t in
                Button {
                    selected = t
                } label: {
                    Label(t.title, systemImage: t.systemImageName)
                }
            }
        } label: {
            Label("Tipo: \(selected.title)", systemImage: selected.systemImageName)
        }
    }
}

