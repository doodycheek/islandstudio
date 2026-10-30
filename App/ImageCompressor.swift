import UIKit

/// Live Activity data is capped at 4 KB, so images get shrunk to a tiny icon.
enum ImageCompressor {
    static func tinyJPEG(from data: Data, maxBytes: Int = 1000) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        return tinyJPEG(from: image, maxBytes: maxBytes)
    }

    static func tinyJPEG(from image: UIImage, maxBytes: Int = 1000) -> Data? {
        guard image.size.width > 0, image.size.height > 0 else { return nil }
        for side in [48, 40, 32, 24] {
            let size = CGSize(width: side, height: side)
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            let rendered = UIGraphicsImageRenderer(size: size, format: format).image { _ in
                let scale = max(size.width / image.size.width, size.height / image.size.height)
                let w = image.size.width * scale
                let h = image.size.height * scale
                image.draw(in: CGRect(x: (size.width - w) / 2, y: (size.height - h) / 2, width: w, height: h))
            }
            for q in stride(from: 0.8, through: 0.2, by: -0.15) {
                if let d = rendered.jpegData(compressionQuality: q), d.count <= maxBytes {
                    return d
                }
            }
        }
        return nil
    }
}
