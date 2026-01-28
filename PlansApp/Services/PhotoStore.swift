//
//  PhotoStore.swift
//  PlansApp
//
//  Created by Adrian Rodriguez Llorens on 27/01/26.
//

import UIKit

final class PhotoStore {
    static let shared = PhotoStore()
    private init() {}

    private let folderName = "PlansApp/Photos"

    private var baseFolderURL: URL {
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folder = appSupport.appendingPathComponent(folderName, isDirectory: true)
        if !fm.fileExists(atPath: folder.path) {
            try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folder
    }

    func fileURL(for filename: String) -> URL {
        baseFolderURL.appendingPathComponent(filename)
    }

    func saveJPEG(
        image: UIImage,
        pinID: UUID,
        index: Int,
        quality: CGFloat = 0.82,
        maxDimension: CGFloat = 2200
    ) throws -> String {
        let prepared = image.scaledDown(maxDimension: maxDimension)
        guard let data = prepared.jpegData(compressionQuality: quality) else {
            throw NSError(domain: "PhotoStore", code: 1)
        }

        let filename = "pin_\(pinID.uuidString)_\(index).jpg"
        let url = fileURL(for: filename)
        try data.write(to: url, options: [.atomic])
        return filename
    }

    func loadImage(filename: String) -> UIImage? {
        let url = fileURL(for: filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    func delete(filename: String) {
        let url = fileURL(for: filename)
        try? FileManager.default.removeItem(at: url)
    }

    func deleteAll(for pin: Pin) {
        for fn in pin.photoFilenames {
            delete(filename: fn)
        }
    }
}

// MARK: - UIImage helper
private extension UIImage {
    func scaledDown(maxDimension: CGFloat) -> UIImage {
        let maxSide = max(size.width, size.height)
        guard maxSide > maxDimension else { return self }

        let scale = maxDimension / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}


