import Foundation
import ImageIO
import AVFoundation

/// Placeholder — replaced with the full Codable manifest in the bundle-writing task.
public struct BundleManifest {}

public func extractBundle(from input: URL, to outputDir: URL) throws -> BundleManifest {
    guard let source = CGImageSourceCreateWithURL(input as CFURL, nil),
          CGImageSourceGetCount(source) > 0 else {
        throw ExtractError.unreadableFile(input)
    }
    let auxInfo =
        CGImageSourceCopyAuxiliaryDataInfoAtIndex(source, 0, kCGImageAuxiliaryDataTypeDisparity)
        ?? CGImageSourceCopyAuxiliaryDataInfoAtIndex(source, 0, kCGImageAuxiliaryDataTypeDepth)
    guard let auxDict = auxInfo as? [AnyHashable: Any] else {
        throw ExtractError.noDepthData(input)
    }
    _ = auxDict // used by the success path (next task)
    return BundleManifest()
}
