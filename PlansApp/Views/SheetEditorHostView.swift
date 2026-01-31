//
//  SheetEditorHostView.swift
//  PlansApp
//
//  Created by Adrian Rodriguez Llorens on 30/01/26.
//

import SwiftUI

struct SheetEditorHostView: View {
    let projectID: UUID
    let sheet: AppSheet

    var body: some View {
        let pdfURL = ProjectsManager.shared.pdfURL(projectID: projectID, pdfFilename: sheet.pdfFilename)
        let stateURL = AppFileSystem.sheetEditorJSONURL(projectID: projectID, sheetID: sheet.id)

        // 👇 aquí NO tocamos tu PlanProject modelo.
        PlanEditorView_ProjectMode(pdfURL: pdfURL, stateURL: stateURL)
            .navigationTitle(sheet.name)
            .navigationBarTitleDisplayMode(.inline)
    }
}

