import UIKit

/// Live Activity data is capped at 4 KB, so photos get shrunk to a tiny icon.
enum ImageCompressor {
    static func tinyJPEG(from data: Data, maxBytes: Int = 1200) -> Data? {
        guard let img = UIImage(data: data), img.size.width > 0, img.size.height > 0 else { return nil }
        for side in [48, 40, 32, 24] {
            let size = CGSize(width: side, height: side)
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            let rendered = UIGraphicsImageRenderer(size: size, format: format).image { _ in
                let scale = max(size.width / img.size.width, size.height / img.size.height)
                let w = img.size.width * scale
                let h = img.size.height * scale
                img.draw(in: CGRect(x: (size.width - w) / 2, y: (size.height - h) / 2, width: w, height: h))
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
