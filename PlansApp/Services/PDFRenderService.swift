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

    /// Render determinístico: mismo PDF/página => mismo size final
    /// `maxLongSidePx` controla calidad, pero no cambia proporción ni "mueve" pines.
    func renderPage(url: URL, pageIndex: Int, maxLongSidePx: CGFloat = 3000) -> UIImage? {
        guard let doc = PDFDocument(url: url),
              let page = doc.page(at: pageIndex) else { return nil }

        // Tamaño real de la página en puntos PDF (determinístico)
        let pageRect = page.bounds(for: .mediaBox)

        // Escala determinística basada en un límite de pixeles (no en tamaño de pantalla)
        let longSide = max(pageRect.width, pageRect.height)
        let scale = min(maxLongSidePx / max(longSide, 1), 4.0) // cap por seguridad

        // Tamaño final en puntos del renderer (si scale>1 habrá más pixeles, pero size en puntos se mantiene)
        let targetSize = CGSize(width: pageRect.width, height: pageRect.height)

        let format = UIGraphicsImageRendererFormat()
        format.scale = scale           // ✅ calidad determinística
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)

        let img = renderer.image { ctx in
            // fondo blanco
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: targetSize))

            ctx.cgContext.saveGState()

            // PDF coordinates -> UIKit coordinates
            // 1) llevar origen abajo-izq a arriba-izq
            ctx.cgContext.translateBy(x: 0, y: targetSize.height)
            ctx.cgContext.scaleBy(x: 1, y: -1)

            // Dibujar página en el rect original
            page.draw(with: .mediaBox, to: ctx.cgContext)

            ctx.cgContext.restoreGState()
        }

        return img
    }
}


