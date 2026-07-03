import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

enum ImageWriting {
    static func writePNG(_ image: CGImage, to url: URL) throws {
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil),
              (CGImageDestinationAddImage(dest, image, nil), CGImageDestinationFinalize(dest)).1 else {
            throw NSError(domain: "ImageWriting", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "PNG write failed: \(url.path)"])
        }
    }

    /// 16-bit grayscale CGImage from normalized UInt16 pixels (big-endian per CG gray-16 layout).
    static func grayscale16Image(width: Int, height: Int, pixels: [UInt16]) -> CGImage {
        var bigEndian = pixels.map { $0.bigEndian }
        let data = Data(bytes: &bigEndian, count: bigEndian.count * 2)
        let provider = CGDataProvider(data: data as CFData)!
        return CGImage(width: width, height: height, bitsPerComponent: 16, bitsPerPixel: 16,
                       bytesPerRow: width * 2, space: CGColorSpaceCreateDeviceGray(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: false,
                       intent: .defaultIntent)!
    }

    /// 8-bit grayscale CGImage (for the portrait matte).
    static func grayscale8Image(width: Int, height: Int, pixels: [UInt8]) -> CGImage {
        let provider = CGDataProvider(data: Data(pixels) as CFData)!
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 8,
                       bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: false,
                       intent: .defaultIntent)!
    }
}
