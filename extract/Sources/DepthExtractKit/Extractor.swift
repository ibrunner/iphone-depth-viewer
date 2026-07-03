import Foundation
import ImageIO
import AVFoundation
import CoreVideo

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

    let name = input.deletingPathExtension().lastPathComponent
    let bundleDir = outputDir.appendingPathComponent(name, isDirectory: true)
    try FileManager.default.createDirectory(at: bundleDir, withIntermediateDirectories: true)

    // --- depth: AVDepthData -> Float32 disparity -> normalized 16-bit PNG ---
    var depthData = try AVDepthData(fromDictionaryRepresentation: auxDict)
    if depthData.depthDataType != kCVPixelFormatType_DisparityFloat32 {
        depthData = depthData.converting(toDepthDataType: kCVPixelFormatType_DisparityFloat32)
    }
    let map = depthData.depthDataMap
    CVPixelBufferLockBaseAddress(map, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(map, .readOnly) }
    let dw = CVPixelBufferGetWidth(map), dh = CVPixelBufferGetHeight(map)
    let rowBytes = CVPixelBufferGetBytesPerRow(map)
    let base = CVPixelBufferGetBaseAddress(map)!

    var floats = [Float](repeating: 0, count: dw * dh)
    for y in 0..<dh {
        let row = base.advanced(by: y * rowBytes).assumingMemoryBound(to: Float.self)
        for x in 0..<dw { floats[y * dw + x] = row[x] }
    }
    let finite = floats.filter { $0.isFinite }
    guard let minD = finite.min(), let maxD = finite.max(), maxD > minD else {
        throw ExtractError.noDepthData(input)
    }
    let scale = Float(UInt16.max) / (maxD - minD)
    let pixels = floats.map { f -> UInt16 in
        let v = f.isFinite ? f : minD
        return UInt16((v - minD) * scale)
    }
    try ImageWriting.writePNG(
        ImageWriting.grayscale16Image(width: dw, height: dh, pixels: pixels),
        to: bundleDir.appendingPathComponent("depth.png"))

    // --- color: primary image as PNG ---
    guard let colorImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        throw ExtractError.unreadableFile(input)
    }
    try ImageWriting.writePNG(colorImage, to: bundleDir.appendingPathComponent("color.png"))

    // --- matte: optional portrait effects matte ---
    var matteRef: BundleManifest.ImageRef?
    if let matteDict = CGImageSourceCopyAuxiliaryDataInfoAtIndex(
        source, 0, kCGImageAuxiliaryDataTypePortraitEffectsMatte) as? [AnyHashable: Any],
       let matte = try? AVPortraitEffectsMatte(fromDictionaryRepresentation: matteDict) {
        let mBuf = matte.mattingImage
        CVPixelBufferLockBaseAddress(mBuf, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(mBuf, .readOnly) }
        let mw = CVPixelBufferGetWidth(mBuf), mh = CVPixelBufferGetHeight(mBuf)
        let mRow = CVPixelBufferGetBytesPerRow(mBuf)
        let mBase = CVPixelBufferGetBaseAddress(mBuf)!
        var mPixels = [UInt8](repeating: 0, count: mw * mh)
        for y in 0..<mh {
            let row = mBase.advanced(by: y * mRow).assumingMemoryBound(to: UInt8.self)
            for x in 0..<mw { mPixels[y * mw + x] = row[x] }
        }
        try ImageWriting.writePNG(
            ImageWriting.grayscale8Image(width: mw, height: mh, pixels: mPixels),
            to: bundleDir.appendingPathComponent("matte.png"))
        matteRef = .init(file: "matte.png", width: mw, height: mh)
    }

    // --- source metadata ---
    let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [AnyHashable: Any]
    let tiff = props?[kCGImagePropertyTIFFDictionary] as? [AnyHashable: Any]
    let deviceModel = tiff?[kCGImagePropertyTIFFModel] as? String

    let manifest = BundleManifest(
        formatVersion: 1,
        color: .init(file: "color.png", width: colorImage.width, height: colorImage.height),
        depth: .init(file: "depth.png", width: dw, height: dh,
                     disparityMin: Double(minD), disparityMax: Double(maxD)),
        matte: matteRef,
        source: .init(originalFilename: input.lastPathComponent, deviceModel: deviceModel))

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(manifest).write(to: bundleDir.appendingPathComponent("manifest.json"))
    return manifest
}
