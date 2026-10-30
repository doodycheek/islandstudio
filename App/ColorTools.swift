import SwiftUI
import UIKit

/// A one-tap color scheme: accent, primary, secondary, extra.
struct ColorPalette: Identifiable {
    let id: String
    let name: String
    let colors: [String]

    func color(_ index: Int) -> String {
        guard !colors.isEmpty else { return "FFFFFFFF" }
        return colors[min(index, colors.count - 1)]
    }

    static let all: [ColorPalette] = [
        ColorPalette(id: "neon", name: "Neon", colors: ["00E5FFFF", "00E5FFFF", "FF2D92FF", "5E5CE6FF"]),
        ColorPalette(id: "sunset", name: "Sunset", colors: ["FF9500FF", "FF9500FF", "FF2D55FF", "FFD60AFF"]),
        ColorPalette(id: "ocean", name: "Ocean", colors: ["0A84FFFF", "00C6FFFF", "0072FFFF", "64D2FFFF"]),
        ColorPalette(id: "forest", name: "Forest", colors: ["30D158FF", "8FD694FF", "2E7D32FF", "C5E1A5FF"]),
        ColorPalette(id: "candy", name: "Candy", colors: ["FF6FD8FF", "FF9ACBFF", "B967FFFF", "05FFA1FF"]),
        ColorPalette(id: "lava", name: "Lava", colors: ["FF3B30FF", "FF7518FF", "FFD60AFF", "B00020FF"]),
        ColorPalette(id: "pastel", name: "Pastel", colors: ["B39DDBFF", "FFCCBCFF", "B2EBF2FF", "F8BBD0FF"]),
        ColorPalette(id: "gold", name: "Gold", colors: ["FFD700FF", "FFD700FF", "FFA500FF", "FFF3B0FF"]),
        ColorPalette(id: "vapor", name: "Vapor", colors: ["FF71CEFF", "01CDFEFF", "B967FFFF", "05FFA1FF"]),
        ColorPalette(id: "mono", name: "Mono", colors: ["FFFFFFFF", "FFFFFFFF", "8E8E93FF", "D1D1D6FF"])
    ]
}

struct PaletteChip: View {
    let palette: ColorPalette
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                HStack(spacing: -6) {
                    ForEach(Array(palette.colors.prefix(4).enumerated()), id: \.offset) { item in
                        Circle()
                            .fill(Color(hex: item.element))
                            .frame(width: 20, height: 20)
                            .overlay(Circle().strokeBorder(Color.black.opacity(0.25), lineWidth: 1))
                    }
                }
                Text(palette.name).font(.caption2.weight(.medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(.tertiarySystemFill)))
        }
        .buttonStyle(.plain)
    }
}

/// Pulls a few bold colors out of a photo.
enum PaletteExtractor {
    static func palette(from image: UIImage, count: Int = 4) -> [String] {
        guard let cg = image.cgImage else { return [] }
        let side = 4
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let drawn: Bool = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let base = buffer.baseAddress,
                  let context = CGContext(data: base, width: side, height: side, bitsPerComponent: 8,
                                          bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.interpolationQuality = .medium
            context.draw(cg, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard drawn else { return [] }

        var candidates: [(hex: String, saturation: CGFloat, hue: CGFloat)] = []
        for i in 0..<(side * side) {
            let r = CGFloat(pixels[i * 4]) / 255
            let g = CGFloat(pixels[i * 4 + 1]) / 255
            let b = CGFloat(pixels[i * 4 + 2]) / 255
            var h: CGFloat = 0, s: CGFloat = 0, v: CGFloat = 0, a: CGFloat = 0
            UIColor(red: r, green: g, blue: b, alpha: 1).getHue(&h, saturation: &s, brightness: &v, alpha: &a)
            let boosted = UIColor(hue: h, saturation: min(1, s * 1.35 + 0.05), brightness: max(0.6, min(1, v * 1.15)), alpha: 1)
            candidates.append((Color(uiColor: boosted).hexString, s, h))
        }
        candidates.sort { $0.saturation > $1.saturation }

        var picked: [(hex: String, hue: CGFloat)] = []
        for candidate in candidates where picked.count < count {
            if picked.allSatisfy({ abs($0.hue - candidate.hue) > 0.06 }) {
                picked.append((candidate.hex, candidate.hue))
            }
        }
        for candidate in candidates where picked.count < count && !picked.contains(where: { $0.hex == candidate.hex }) {
            picked.append((candidate.hex, candidate.hue))
        }
        return picked.map { $0.hex }
    }
}
