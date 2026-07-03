import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import XCTest

enum TestSupport {
    /// A real HEIC with no auxiliary depth image, generated on the fly.
    static func makeDepthlessHEIC() throws -> URL {
        let ctx = CGContext(data: nil, width: 64, height: 64, bitsPerComponent: 8,
                            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        ctx.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 0.8, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
        let image = ctx.makeImage()!
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("depthless-\(UUID().uuidString).heic")
        let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.heic.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else {
            throw NSError(domain: "TestSupport", code: 1)
        }
        return url
    }

    /// First .heic in the repo's samples/ dir, or nil (callers XCTSkip).
    static func samplePortraitHEIC() -> URL? {
        // Tests run from extract/; samples/ is a sibling of extract/.
        let samples = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // DepthExtractKitTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // extract
            .appendingPathComponent("samples")
        let files = (try? FileManager.default.contentsOfDirectory(at: samples, includingPropertiesForKeys: nil)) ?? []
        return files.first { $0.pathExtension.lowercased() == "heic" }
    }

    static func tempOutputDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("bundle-out-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
