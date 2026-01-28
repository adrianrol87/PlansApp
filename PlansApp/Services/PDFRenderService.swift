//
//  PDFRenderService.swift
//  PlansApp
//
//  Created by Adrian Rodriguez Llorens on 27/01/26.
//

import UIKit
import PDFKit

final class PDFRenderService {
    static let shared = PDFRenderService()
    private init() {}

    /// Renderiza una página a UIImage (MVP: una sola página).
    func renderPage(url: URL, pageIndex: Int, targetWidth: CGFloat = 2400) -> UIImage? {
        guard let doc = PDFDocument(url: url),
              let page = doc.page(at: pageIndex) else { return nil }

        let pageRect = page.bounds(for: .mediaBox)
        guard pageRect.width > 0 else { return nil }

        let scale = targetWidth / pageRect.width
        let targetSize = CGSize(width: pageRect.width * scale, height: pageRect.height * scale)

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: targetSize))

            ctx.cgContext.saveGState()
            // Fix coordenadas
            ctx.cgContext.translateBy(x: 0, y: targetSize.height)
            ctx.cgContext.scaleBy(x: scale, y: -scale)

            page.draw(with: .mediaBox, to: ctx.cgContext)
            ctx.cgContext.restoreGState()
        }
    }
}

