# Depth Viewer MVP (M0–M2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** End-to-end path from an iPhone Portrait photo to a gyro-driven parallax "wiggle" in iPhone Safari — Swift extractor produces a depth bundle, React/three.js viewer renders it with mouse (desktop) and gyro (phone) parallax.

**Architecture:** Three-layer toolkit per `docs/superpowers/specs/2026-07-03-depth-viewer-toolkit-design.md`. This plan covers milestones M0–M2 only: repo scaffold, `extract/` (Swift CLI on ImageIO/AVFoundation writing versioned "depth bundles"), and `viewer/` (Vite + React + three.js, single displaced-quad shader). The ComfyUI pipeline (M3) and lighting (M4) are separate future plans.

**Tech Stack:** Swift 5.9+ / SPM / swift-argument-parser / ImageIO / AVFoundation (macOS 14+); Node 20+ / Vite / React 18 / TypeScript / three / vitest; `@vitejs/plugin-basic-ssl` for LAN HTTPS.

## Global Constraints

- Proof-of-concept quality bar ("as janky as it needs to be") — no hosting, auth, or multi-user concerns.
- Bundle format v1 exactly as specified in the spec: directory containing `manifest.json`, `color.png`, `depth.png` (16-bit grayscale normalized disparity), optional `matte.png`.
- `manifest.json` shape (single source of truth, mirrored by Swift `BundleManifest` and TS `BundleManifest`):

```json
{
  "formatVersion": 1,
  "color": { "file": "color.png", "width": 4032, "height": 3024 },
  "depth": { "file": "depth.png", "width": 768, "height": 576, "disparityMin": 0.012, "disparityMax": 2.25 },
  "matte": { "file": "matte.png", "width": 2016, "height": 1512 },
  "source": { "originalFilename": "IMG_1234.heic", "deviceModel": "iPhone 15 Pro" }
}
```
`matte` is omitted when the photo has no portrait effects matte; `deviceModel` may be null.
- Real Portrait HEIC samples cannot be generated in CI — extractor tests that need one use `XCTSkip` when `samples/` lacks files. The depthless negative case is generated programmatically.
- Commit after every green test cycle; messages in `type: summary` form.

## Phases

| Phase | Name | Summary |
|---|---|---|
| 1 | Foundation | Repo scaffold + compiling Swift package with green tests |
| 2 | Extractor | Error paths, depth bundle extraction, batch CLI |
| 3 | Viewer | Vite scaffold, displaced-quad parallax renderer, mouse input (UF-1) |
| 4 | Phone experience | Gyro input, HTTPS LAN serving, on-device walkthrough (UF-2) |
| 5 | E2E tests | Playwright coverage of UF-1; manual UF-2 checklist |

User flows are defined in the spec (`docs/superpowers/specs/2026-07-03-depth-viewer-toolkit-design.md`, "User Flows").

## File Structure

```
CLAUDE.md                          # project guide for agents
samples/README.md                  # how to export unmodified originals; user drops HEICs here (gitignored)
extract/                           # Swift package
  Package.swift
  Sources/DepthExtractKit/
    ExtractError.swift             # error enum
    BundleManifest.swift           # Codable manifest
    ImageWriting.swift             # PNG writers (16-bit gray, 8-bit gray, color)
    Extractor.swift                # extractBundle(from:to:)
  Sources/depth-extract/main.swift # CLI (ArgumentParser)
  Tests/DepthExtractKitTests/
    TestSupport.swift              # depthless-HEIC generator, sample lookup
    ExtractorErrorTests.swift
    ExtractorBundleTests.swift
viewer/                            # Vite + React + TS
  package.json, vite.config.ts, index.html, tsconfig.json (scaffolded)
  src/lib/bundle.ts                # manifest types, parseManifest, loadBundle
  src/lib/parallax.ts              # three.js scene: quad + displacement shader
  src/lib/inputs.ts                # mouse + gyro input sources
  src/components/ParallaxViewer.tsx
  src/App.tsx
  src/lib/bundle.test.ts
  playwright.config.ts             # Phase 5
  e2e/parallax.spec.ts             # Phase 5
docs/superpowers/plans/…           # this plan
```

---

## Phase 1: Foundation

**Objective:** Repo layout, documentation, and a compiling Swift package with green tests exist.

**Can run in parallel:** Sequential — Task 1.B assumes the directories Task 1.A creates.

### Task 1.A: M0 repo scaffold

**Files:**
- Create: `CLAUDE.md`, `samples/README.md`, `extract/.gitkeep`, `pipeline/.gitkeep`, `viewer/.gitkeep`
- Modify: `README.md`, `.gitignore`

**Interfaces:**
- Produces: directory layout and project documentation all later tasks assume.

- [x] **Step 1: Write CLAUDE.md**

```markdown
# iphone-depth-viewer

Toolkit: extract iPhone Portrait-photo depth maps → process → view with parallax in the browser.
Spec: docs/superpowers/specs/2026-07-03-depth-viewer-toolkit-design.md
Plans: docs/superpowers/plans/

## Layout
- `extract/` — Swift package (macOS). `depth-extract` CLI: Portrait HEIC → depth bundle.
- `pipeline/` — Python + ComfyUI workflows enriching bundles (M3, not built yet).
- `viewer/` — Vite + React + three.js parallax viewer.
- `samples/` — local Portrait HEICs for testing (gitignored; see samples/README.md).

## The depth bundle (contract between layers)
Directory: `manifest.json` + `color.png` + `depth.png` (16-bit gray, normalized disparity)
+ optional `matte.png`. Manifest schema lives in extract/Sources/DepthExtractKit/BundleManifest.swift
and viewer/src/lib/bundle.ts — keep them in sync.

## Commands
- Extractor build/test: `cd extract && swift build && swift test`
- Extract: `cd extract && swift run depth-extract ~/photo.heic -o ../viewer/public/bundles`
- Viewer dev: `cd viewer && npm run dev` (HTTPS on LAN for iPhone: same command, accept cert on phone)
- Viewer tests: `cd viewer && npx vitest run`

## Conventions
- Proof-of-concept bar; prefer simple over robust, but extractor errors must be clear.
- TDD where tests are cheap (pure logic); manual verification for GPU/browser behavior.
```

- [x] **Step 2: Write samples/README.md**

```markdown
# Samples

Drop Portrait-mode HEICs here for extractor tests and manual runs. Gitignored (personal photos).

Getting a usable file (depth data survives ONLY the "unmodified original" path):
1. Shoot in Portrait mode (rear camera, or front camera selfie).
2. AirDrop to this Mac (keeps original), or in macOS Photos: File → Export → Export Unmodified Original.
3. Name suggestions: `portrait-rear.heic`, `portrait-selfie.heic`.

Tests skip (not fail) when this directory has no HEICs.
```

- [x] **Step 3: Update README.md and .gitignore**

Replace `README.md` body with the project one-liner plus links to CLAUDE.md and the spec. Append to `.gitignore`:

```gitignore
# local photo samples and extracted bundles
samples/*.heic
samples/*.HEIC
viewer/public/bundles/
```

- [x] **Step 4: Create layer directories**

Run: `mkdir -p extract pipeline viewer && touch extract/.gitkeep pipeline/.gitkeep viewer/.gitkeep`

- [x] **Step 5: Commit**

```bash
git add -A && git commit -m "chore: M0 scaffold — layout, CLAUDE.md, samples guide"
```

- [x] Task 1.A complete

---

### Task 1.B: Swift package scaffold

**Files:**
- Create: `extract/Package.swift`, `extract/Sources/DepthExtractKit/ExtractError.swift`, `extract/Sources/depth-extract/main.swift` (stub), `extract/Tests/DepthExtractKitTests/ExtractorErrorTests.swift` (placeholder test)
- Delete: `extract/.gitkeep`

**Interfaces:**
- Produces: `DepthExtractKit` library target importable by tests and CLI; `ExtractError` enum with cases `.unreadableFile(URL)`, `.noDepthData(URL)`.

- [x] **Step 1: Write Package.swift**

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "depth-extract",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    ],
    targets: [
        .target(name: "DepthExtractKit"),
        .executableTarget(
            name: "depth-extract",
            dependencies: [
                "DepthExtractKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]),
        .testTarget(name: "DepthExtractKitTests", dependencies: ["DepthExtractKit"]),
    ]
)
```

- [x] **Step 2: Write ExtractError.swift**

```swift
import Foundation

public enum ExtractError: Error, CustomStringConvertible, Equatable {
    case unreadableFile(URL)
    case noDepthData(URL)

    public var description: String {
        switch self {
        case .unreadableFile(let url):
            return "Cannot read image file: \(url.path)"
        case .noDepthData(let url):
            return "No depth data in \(url.lastPathComponent). Is it a Portrait photo exported as an unmodified original? (Edited/shared copies lose depth.)"
        }
    }
}
```

- [x] **Step 3: Write stub main.swift and placeholder test**

`extract/Sources/depth-extract/main.swift`:
```swift
print("depth-extract: not implemented yet")
```

`extract/Tests/DepthExtractKitTests/ExtractorErrorTests.swift`:
```swift
import XCTest
@testable import DepthExtractKit

final class ExtractorErrorTests: XCTestCase {
    func testErrorDescriptionsMentionFile() {
        let url = URL(fileURLWithPath: "/tmp/IMG_0001.heic")
        XCTAssertTrue(ExtractError.noDepthData(url).description.contains("IMG_0001.heic"))
        XCTAssertTrue(ExtractError.unreadableFile(url).description.contains("/tmp/IMG_0001.heic"))
    }
}
```

- [x] **Step 4: Verify build and test**

Run: `cd extract && rm -f .gitkeep && swift build && swift test`
Expected: build succeeds; 1 test passes.

- [x] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: Swift package scaffold for depth-extract"
```

- [x] Task 1.B complete

### Phase 1 Exit Criteria

Before moving to Phase 2, ALL of the following must be true:

- [x] `cd extract && swift build && swift test` passes (error-description test green)
- [x] `extract/`, `pipeline/`, `viewer/`, `samples/` directories exist with CLAUDE.md and samples/README.md committed
- [x] `.gitignore` covers `samples/*.heic` and `viewer/public/bundles/`
- [x] All task and step checkboxes in Phase 1 are marked `[x]` in this plan file

---

## Phase 2: Extractor

**Objective:** `depth-extract` CLI turns a Portrait HEIC into a valid v1 depth bundle, with clear errors for depthless/unreadable files and batch mode over a directory.

**Can run in parallel:** Sequential — 2.A (errors) → 2.B (success path) → 2.C (CLI).

### Task 2.A: Extractor error paths (TDD, no sample photos needed)

**Files:**
- Create: `extract/Tests/DepthExtractKitTests/TestSupport.swift`, `extract/Sources/DepthExtractKit/Extractor.swift`
- Test: `extract/Tests/DepthExtractKitTests/ExtractorErrorTests.swift`

**Interfaces:**
- Produces: `public func extractBundle(from input: URL, to outputDir: URL) throws -> BundleManifest` — for this task it only needs to reach the error throws; the success path is Task 2.B. To keep this task compiling before Task 2.B defines the real manifest, declare a minimal placeholder here that Task 2.B replaces: `public struct BundleManifest {}` at the bottom of `Extractor.swift`.
- Produces (tests): `TestSupport.makeDepthlessHEIC() throws -> URL`, `TestSupport.samplePortraitHEIC() -> URL?`.

- [x] **Step 1: Write TestSupport.swift**

```swift
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
```

- [x] **Step 2: Write the failing tests**

Append to `ExtractorErrorTests.swift`:

```swift
    func testMissingFileThrowsUnreadable() {
        let missing = URL(fileURLWithPath: "/nonexistent/nope.heic")
        XCTAssertThrowsError(try extractBundle(from: missing, to: TestSupport.tempOutputDir())) { error in
            XCTAssertEqual(error as? ExtractError, .unreadableFile(missing))
        }
    }

    func testDepthlessHEICThrowsNoDepthData() throws {
        let depthless = try TestSupport.makeDepthlessHEIC()
        XCTAssertThrowsError(try extractBundle(from: depthless, to: TestSupport.tempOutputDir())) { error in
            XCTAssertEqual(error as? ExtractError, .noDepthData(depthless))
        }
    }
```

- [x] **Step 3: Run tests to verify they fail**

Run: `cd extract && swift test`
Expected: compile error — `extractBundle` not defined.

- [x] **Step 4: Implement the error-path skeleton in Extractor.swift**

```swift
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
```

- [x] **Step 5: Run tests to verify they pass**

Run: `cd extract && swift test`
Expected: all 3 tests PASS.

- [x] **Step 6: Commit**

```bash
git add -A && git commit -m "feat: extractor error paths — unreadable file, no depth data"
```

- [x] Task 2.A complete

---

### Task 2.B: Depth bundle extraction (manifest, PNG writers, depth/color/matte)

**Files:**
- Create: `extract/Sources/DepthExtractKit/BundleManifest.swift`, `extract/Sources/DepthExtractKit/ImageWriting.swift`
- Modify: `extract/Sources/DepthExtractKit/Extractor.swift` (replace placeholder manifest + implement success path)
- Test: `extract/Tests/DepthExtractKitTests/ExtractorBundleTests.swift`

**Interfaces:**
- Consumes: `extractBundle(from:to:)` signature and `ExtractError` from Task 2.A.
- Produces: `BundleManifest: Codable` matching the Global Constraints JSON exactly (`formatVersion`, `color: ImageRef`, `depth: DepthRef`, `matte: ImageRef?`, `source: SourceInfo`); `extractBundle` writes `<outputDir>/<basename>/{manifest.json,color.png,depth.png[,matte.png]}` and returns the manifest. Task 2.C's CLI and Task 3.B's TS types rely on this exact schema.

- [x] **Step 1: Write the failing test (skips without a real sample)**

`ExtractorBundleTests.swift`:
```swift
import XCTest
@testable import DepthExtractKit

final class ExtractorBundleTests: XCTestCase {
    func testExtractsBundleFromPortraitHEIC() throws {
        guard let sample = TestSupport.samplePortraitHEIC() else {
            throw XCTSkip("No sample HEIC in samples/ — see samples/README.md")
        }
        let out = TestSupport.tempOutputDir()
        let manifest = try extractBundle(from: sample, to: out)

        let bundleDir = out.appendingPathComponent(sample.deletingPathExtension().lastPathComponent)
        let fm = FileManager.default
        XCTAssertTrue(fm.fileExists(atPath: bundleDir.appendingPathComponent("manifest.json").path))
        XCTAssertTrue(fm.fileExists(atPath: bundleDir.appendingPathComponent("color.png").path))
        XCTAssertTrue(fm.fileExists(atPath: bundleDir.appendingPathComponent("depth.png").path))

        XCTAssertEqual(manifest.formatVersion, 1)
        XCTAssertGreaterThan(manifest.color.width, 0)
        XCTAssertGreaterThan(manifest.depth.width, 0)
        XCTAssertLessThan(manifest.depth.disparityMin, manifest.depth.disparityMax)

        // manifest.json round-trips
        let data = try Data(contentsOf: bundleDir.appendingPathComponent("manifest.json"))
        let decoded = try JSONDecoder().decode(BundleManifest.self, from: data)
        XCTAssertEqual(decoded.color.file, "color.png")
        if manifest.matte != nil {
            XCTAssertTrue(fm.fileExists(atPath: bundleDir.appendingPathComponent("matte.png").path))
        }
    }
}
```

- [x] **Step 2: Run tests — new test should skip (no sample yet) or fail to compile**

Run: `cd extract && swift test`
Expected: compile error (`manifest.color` etc. don't exist on the placeholder struct).

- [x] **Step 3: Write BundleManifest.swift (and delete the placeholder in Extractor.swift)**

```swift
import Foundation

public struct BundleManifest: Codable {
    public struct ImageRef: Codable {
        public let file: String
        public let width: Int
        public let height: Int
    }
    public struct DepthRef: Codable {
        public let file: String
        public let width: Int
        public let height: Int
        public let disparityMin: Double
        public let disparityMax: Double
    }
    public struct SourceInfo: Codable {
        public let originalFilename: String
        public let deviceModel: String?
    }
    public let formatVersion: Int
    public let color: ImageRef
    public let depth: DepthRef
    public let matte: ImageRef?
    public let source: SourceInfo
}
```

- [x] **Step 4: Write ImageWriting.swift**

```swift
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
```

- [x] **Step 5: Implement the success path in Extractor.swift**

Replace the whole file:

```swift
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
```

- [x] **Step 6: Run tests**

Run: `cd extract && swift test`
Expected: error tests PASS; bundle test SKIPS if `samples/` is empty, PASSES if the user has dropped a sample in.

- [x] **Step 7: Ask the user for a real sample (checkpoint)**

If `samples/` is empty, ask the user to AirDrop/export a Portrait HEIC into `samples/` per `samples/README.md`, then rerun `swift test` and confirm the bundle test passes (not skips) before continuing. This is the first moment real depth data flows end to end — worth the pause.

- [x] **Step 8: Commit**

```bash
git add -A && git commit -m "feat: depth bundle extraction — depth, color, matte, manifest"
```

- [x] Task 2.B complete

---

### Task 2.C: CLI with batch mode

**Files:**
- Modify: `extract/Sources/depth-extract/main.swift` (replace stub)

**Interfaces:**
- Consumes: `extractBundle(from:to:)`, `ExtractError`.
- Produces: `depth-extract <inputs...> [-o outputDir]` — inputs are HEIC files or directories (expanded non-recursively); continues past per-file errors; exit 1 if nothing succeeded.

- [x] **Step 1: Replace main.swift**

```swift
import Foundation
import ArgumentParser
import DepthExtractKit

@main
struct DepthExtract: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "depth-extract",
        abstract: "Extract depth bundles from iPhone Portrait HEIC photos.")

    @Argument(help: "HEIC files or directories containing them.")
    var inputs: [String]

    @Option(name: .shortAndLong, help: "Output directory for bundles.")
    var output: String = "."

    func run() throws {
        let fm = FileManager.default
        let outputDir = URL(fileURLWithPath: output, isDirectory: true)
        try fm.createDirectory(at: outputDir, withIntermediateDirectories: true)

        var heics: [URL] = []
        for input in inputs {
            let url = URL(fileURLWithPath: input)
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                let entries = (try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)) ?? []
                heics += entries.filter { $0.pathExtension.lowercased() == "heic" }.sorted { $0.path < $1.path }
            } else {
                heics.append(url)
            }
        }
        guard !heics.isEmpty else { throw ValidationError("No input HEIC files found.") }

        var succeeded = 0
        for heic in heics {
            do {
                let manifest = try extractBundle(from: heic, to: outputDir)
                let matte = manifest.matte != nil ? ", matte" : ""
                print("ok: \(heic.lastPathComponent) -> depth \(manifest.depth.width)x\(manifest.depth.height)\(matte)")
                succeeded += 1
            } catch {
                FileHandle.standardError.write("skip: \(error)\n".data(using: .utf8)!)
            }
        }
        print("\(succeeded)/\(heics.count) extracted to \(outputDir.path)")
        if succeeded == 0 { throw ExitCode(1) }
    }
}
```

Note: because `main.swift` in an executable target conflicts with `@main`, rename the file to `DepthExtract.swift` in the same directory (`git mv extract/Sources/depth-extract/main.swift extract/Sources/depth-extract/DepthExtract.swift`).

- [x] **Step 2: Build and verify error behavior without a sample**

Run: `cd extract && swift run depth-extract /nonexistent.heic -o /tmp/bundles-test; echo "exit: $?"`
Expected: `skip: Cannot read image file: /nonexistent.heic`, `0/1 extracted…`, `exit: 1`.

- [x] **Step 3: Verify against a real sample (checkpoint)**

Run: `cd extract && swift run depth-extract ../samples -o /tmp/bundles-test && ls /tmp/bundles-test/*/`
Expected: `ok: … -> depth WxH…` per sample; each bundle dir contains `manifest.json color.png depth.png` (+ `matte.png` for people). Open `depth.png` with `open` and eyeball that it looks like a plausible depth silhouette.

- [x] **Step 4: Commit**

```bash
git add -A && git commit -m "feat: depth-extract CLI with batch mode"
```

- [x] Task 2.C complete

### Phase 2 Exit Criteria

Before moving to Phase 3, ALL of the following must be true:

- [x] `cd extract && swift test` — all tests pass with a real sample present (`testExtractsBundleFromPortraitHEIC` PASSES, does not skip)
- [x] `swift run depth-extract ../samples -o /tmp/bundles-test` produces a bundle dir with `manifest.json`, `color.png`, `depth.png` (+ `matte.png` for a person photo)
- [x] `depth.png` eyeballed: plausible depth silhouette of the photo (near = bright)
- [x] Depthless/unreadable inputs print a clear `skip:` message and the CLI exits 1 when nothing succeeds
- [x] All task and step checkboxes in Phase 2 are marked `[x]` in this plan file

---

## Phase 3: Viewer

**Objective:** The web viewer renders a depth bundle (or synthetic fallback) with mouse-driven parallax — UF-1 becomes visible.

**Can run in parallel:** Sequential — 3.A (scaffold) → 3.B (renderer).

### Task 3.A: Viewer scaffold (Vite + React + TS + three + vitest)

**Files:**
- Create (scaffolded): `viewer/` Vite react-ts app
- Modify: `viewer/src/App.tsx` (placeholder), delete boilerplate CSS/assets not needed
- Delete: `viewer/.gitkeep`

**Interfaces:**
- Produces: running dev server (`npm run dev`), test runner (`npx vitest run`), deps `three`, `@types/three`, `@vitejs/plugin-basic-ssl` installed. Later tasks add files under `viewer/src/lib/`.

- [ ] **Step 1: Scaffold**

Run from repo root:
```bash
rm viewer/.gitkeep
npm create vite@latest viewer -- --template react-ts
cd viewer && npm install && npm install three && npm install -D @types/three vitest @vitejs/plugin-basic-ssl
```
(If `npm create` balks at the non-empty dir, scaffold to `viewer-tmp` and move the contents.)

- [ ] **Step 2: Strip boilerplate**

Replace `viewer/src/App.tsx`:
```tsx
export default function App() {
  return <div style={{ padding: 16, fontFamily: "system-ui" }}>depth viewer — renderer coming next</div>;
}
```
Delete `viewer/src/App.css`, `viewer/src/assets/react.svg`, `viewer/public/vite.svg`; remove their imports/references from `src/main.tsx`, `src/index.css` (keep a minimal `index.css`: `html,body,#root{margin:0;height:100%}`), and `index.html`. Set `<title>depth viewer</title>`.

- [ ] **Step 3: Add test script and verify everything runs**

In `viewer/package.json` scripts add: `"test": "vitest run"`.
Run: `cd viewer && npm run build && npm run dev -- --port 5173 &` then `curl -s http://localhost:5173 | grep -o "<title>depth viewer</title>"` and kill the dev server.
Expected: build succeeds; curl prints the title tag.

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "feat: viewer scaffold — Vite + React + TS + three"
```

- [ ] Task 3.A complete

---

### Task 3.B: Bundle loader + displaced-quad parallax renderer + mouse input

**Files:**
- Create: `viewer/src/lib/bundle.ts`, `viewer/src/lib/parallax.ts`, `viewer/src/lib/inputs.ts`, `viewer/src/components/ParallaxViewer.tsx`
- Modify: `viewer/src/App.tsx`
- Test: `viewer/src/lib/bundle.test.ts`

**Interfaces:**
- Consumes: bundle directories served from `viewer/public/bundles/<name>/` (gitignored output of the extractor); manifest schema from Global Constraints.
- Produces:
  - `bundle.ts`: `interface BundleManifest` (mirrors the JSON), `parseManifest(json: unknown): BundleManifest` (throws `Error` with a field name on invalid input), `loadBundle(baseUrl: string): Promise<LoadedBundle>` where `LoadedBundle = { manifest: BundleManifest; color: THREE.Texture; depth: THREE.Texture }`, and `syntheticBundle(): LoadedBundle` (canvas-generated fallback).
  - `parallax.ts`: `createParallaxScene(canvas: HTMLCanvasElement, bundle: LoadedBundle): { setOffset(x: number, y: number): void; dispose(): void }` — offsets in [-1, 1].
  - `inputs.ts`: `attachMouseInput(el: HTMLElement, onOffset: (x: number, y: number) => void): () => void` (returns detach).

- [ ] **Step 1: Write the failing manifest test**

`viewer/src/lib/bundle.test.ts`:
```ts
import { describe, it, expect } from "vitest";
import { parseManifest } from "./bundle";

const valid = {
  formatVersion: 1,
  color: { file: "color.png", width: 4032, height: 3024 },
  depth: { file: "depth.png", width: 768, height: 576, disparityMin: 0.01, disparityMax: 2.2 },
  source: { originalFilename: "IMG_1.heic", deviceModel: "iPhone 15 Pro" },
};

describe("parseManifest", () => {
  it("accepts a valid v1 manifest without matte", () => {
    expect(parseManifest(valid).depth.width).toBe(768);
    expect(parseManifest(valid).matte).toBeUndefined();
  });
  it("accepts an optional matte", () => {
    const m = parseManifest({ ...valid, matte: { file: "matte.png", width: 10, height: 10 } });
    expect(m.matte?.file).toBe("matte.png");
  });
  it("rejects unknown formatVersion", () => {
    expect(() => parseManifest({ ...valid, formatVersion: 2 })).toThrow(/formatVersion/);
  });
  it("rejects missing depth", () => {
    const { depth: _d, ...noDepth } = valid;
    expect(() => parseManifest(noDepth)).toThrow(/depth/);
  });
});
```

- [ ] **Step 2: Run to verify failure**

Run: `cd viewer && npx vitest run`
Expected: FAIL — `./bundle` has no `parseManifest`.

- [ ] **Step 3: Write bundle.ts**

```ts
import * as THREE from "three";

export interface ImageRef { file: string; width: number; height: number }
export interface DepthRef extends ImageRef { disparityMin: number; disparityMax: number }
export interface BundleManifest {
  formatVersion: 1;
  color: ImageRef;
  depth: DepthRef;
  matte?: ImageRef;
  source: { originalFilename: string; deviceModel: string | null };
}
export interface LoadedBundle {
  manifest: BundleManifest;
  color: THREE.Texture;
  depth: THREE.Texture;
}

function isImageRef(v: unknown): v is ImageRef {
  const r = v as ImageRef;
  return !!r && typeof r.file === "string" && typeof r.width === "number" && typeof r.height === "number";
}

export function parseManifest(json: unknown): BundleManifest {
  const m = json as BundleManifest;
  if (!m || m.formatVersion !== 1) throw new Error("manifest: unsupported formatVersion (expected 1)");
  if (!isImageRef(m.color)) throw new Error("manifest: missing/invalid color");
  if (!isImageRef(m.depth) || typeof m.depth.disparityMin !== "number" || typeof m.depth.disparityMax !== "number")
    throw new Error("manifest: missing/invalid depth");
  if (m.matte !== undefined && !isImageRef(m.matte)) throw new Error("manifest: invalid matte");
  if (!m.source || typeof m.source.originalFilename !== "string") throw new Error("manifest: missing source");
  return m;
}

async function loadTexture(url: string): Promise<THREE.Texture> {
  const tex = await new THREE.TextureLoader().loadAsync(url);
  tex.colorSpace = THREE.NoColorSpace;
  tex.wrapS = tex.wrapT = THREE.ClampToEdgeWrapping;
  return tex;
}

export async function loadBundle(baseUrl: string): Promise<LoadedBundle> {
  const res = await fetch(`${baseUrl}/manifest.json`);
  if (!res.ok) throw new Error(`bundle: cannot fetch ${baseUrl}/manifest.json (${res.status})`);
  const manifest = parseManifest(await res.json());
  const [color, depth] = await Promise.all([
    loadTexture(`${baseUrl}/${manifest.color.file}`),
    loadTexture(`${baseUrl}/${manifest.depth.file}`),
  ]);
  color.colorSpace = THREE.SRGBColorSpace;
  return { manifest, color, depth };
}

/** Canvas-generated demo so the viewer runs with zero assets: colored blocks + radial depth. */
export function syntheticBundle(): LoadedBundle {
  const size = 512;
  const colorCanvas = document.createElement("canvas");
  colorCanvas.width = colorCanvas.height = size;
  const c = colorCanvas.getContext("2d")!;
  c.fillStyle = "#2a4d69"; c.fillRect(0, 0, size, size);
  c.fillStyle = "#e8a33d"; c.fillRect(96, 96, 140, 140);
  c.fillStyle = "#d1495b"; c.beginPath(); c.arc(340, 330, 90, 0, Math.PI * 2); c.fill();
  c.fillStyle = "#fff"; c.font = "24px system-ui"; c.fillText("synthetic demo", 160, 480);

  const depthCanvas = document.createElement("canvas");
  depthCanvas.width = depthCanvas.height = size;
  const d = depthCanvas.getContext("2d")!;
  const g = d.createRadialGradient(340, 330, 20, 340, 330, 400);
  g.addColorStop(0, "#fff"); g.addColorStop(1, "#000");
  d.fillStyle = g; d.fillRect(0, 0, size, size);
  d.fillStyle = "#888"; d.fillRect(96, 96, 140, 140);

  const color = new THREE.CanvasTexture(colorCanvas);
  color.colorSpace = THREE.SRGBColorSpace;
  const depth = new THREE.CanvasTexture(depthCanvas);
  return {
    manifest: {
      formatVersion: 1,
      color: { file: "canvas", width: size, height: size },
      depth: { file: "canvas", width: size, height: size, disparityMin: 0, disparityMax: 1 },
      source: { originalFilename: "synthetic", deviceModel: null },
    },
    color, depth,
  };
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd viewer && npx vitest run`
Expected: 4 tests PASS.

- [ ] **Step 5: Write parallax.ts (the Depthy-style shader)**

```ts
import * as THREE from "three";
import type { LoadedBundle } from "./bundle";

const vertexShader = /* glsl */ `
  varying vec2 vUv;
  void main() {
    vUv = uv;
    gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
  }
`;

const fragmentShader = /* glsl */ `
  uniform sampler2D uColor;
  uniform sampler2D uDepth;
  uniform vec2 uOffset;     // eye offset, [-1,1]
  uniform float uStrength;  // parallax strength in UV units
  varying vec2 vUv;
  void main() {
    // Two-tap: sample depth at the shifted location too, reduces edge halos a bit.
    float d0 = texture2D(uDepth, vUv).r;
    vec2 shift = uOffset * uStrength * (d0 - 0.5);
    float d1 = texture2D(uDepth, vUv + shift).r;
    vec2 uv = vUv + uOffset * uStrength * (d1 - 0.5);
    gl_FragColor = texture2D(uColor, clamp(uv, 0.0, 1.0));
  }
`;

export interface ParallaxScene {
  setOffset(x: number, y: number): void;
  dispose(): void;
}

export function createParallaxScene(canvas: HTMLCanvasElement, bundle: LoadedBundle): ParallaxScene {
  const renderer = new THREE.WebGLRenderer({ canvas, antialias: true });
  const scene = new THREE.Scene();
  const camera = new THREE.OrthographicCamera(-1, 1, 1, -1, 0, 1);

  const uniforms = {
    uColor: { value: bundle.color },
    uDepth: { value: bundle.depth },
    uOffset: { value: new THREE.Vector2(0, 0) },
    uStrength: { value: 0.04 },
  };
  const target = new THREE.Vector2(0, 0);
  const quad = new THREE.Mesh(
    new THREE.PlaneGeometry(2, 2),
    new THREE.ShaderMaterial({ uniforms, vertexShader, fragmentShader })
  );
  scene.add(quad);

  const aspect = bundle.manifest.color.width / bundle.manifest.color.height;
  function resize() {
    const w = canvas.clientWidth, h = Math.round(canvas.clientWidth / aspect);
    renderer.setSize(w, h, false);
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
  }
  resize();
  window.addEventListener("resize", resize);

  let raf = 0;
  function frame() {
    // Ease toward the target so gyro jitter doesn't shake the image.
    uniforms.uOffset.value.lerp(target, 0.15);
    renderer.render(scene, camera);
    raf = requestAnimationFrame(frame);
  }
  frame();

  return {
    setOffset(x, y) { target.set(x, y); },
    dispose() {
      cancelAnimationFrame(raf);
      window.removeEventListener("resize", resize);
      quad.geometry.dispose();
      (quad.material as THREE.Material).dispose();
      renderer.dispose();
    },
  };
}
```

- [ ] **Step 6: Write inputs.ts (mouse only for now — gyro is Task 4.A)**

```ts
export type OffsetCallback = (x: number, y: number) => void;

/** Pointer position relative to element center → offset in [-1, 1]. Returns detach fn. */
export function attachMouseInput(el: HTMLElement, onOffset: OffsetCallback): () => void {
  const onMove = (e: PointerEvent) => {
    const r = el.getBoundingClientRect();
    const x = ((e.clientX - r.left) / r.width) * 2 - 1;
    const y = ((e.clientY - r.top) / r.height) * 2 - 1;
    onOffset(Math.max(-1, Math.min(1, x)), Math.max(-1, Math.min(1, -y)));
  };
  el.addEventListener("pointermove", onMove);
  return () => el.removeEventListener("pointermove", onMove);
}
```

- [ ] **Step 7: Write ParallaxViewer.tsx and wire App.tsx**

`viewer/src/components/ParallaxViewer.tsx`:
```tsx
import { useEffect, useRef, useState } from "react";
import { loadBundle, syntheticBundle, type LoadedBundle } from "../lib/bundle";
import { createParallaxScene, type ParallaxScene } from "../lib/parallax";
import { attachMouseInput } from "../lib/inputs";

export default function ParallaxViewer({ bundleUrl }: { bundleUrl: string | null }) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const sceneRef = useRef<ParallaxScene | null>(null);
  const [status, setStatus] = useState("loading…");

  useEffect(() => {
    let disposed = false;
    let detach = () => {};
    (async () => {
      let bundle: LoadedBundle;
      try {
        bundle = bundleUrl ? await loadBundle(bundleUrl) : syntheticBundle();
        setStatus(bundleUrl ? bundle.manifest.source.originalFilename : "synthetic demo (add ?bundle=<name>)");
      } catch (e) {
        bundle = syntheticBundle();
        setStatus(`failed to load ${bundleUrl}: ${(e as Error).message} — showing synthetic demo`);
      }
      if (disposed || !canvasRef.current) return;
      const scene = createParallaxScene(canvasRef.current, bundle);
      sceneRef.current = scene;
      detach = attachMouseInput(canvasRef.current, (x, y) => scene.setOffset(x, y));
    })();
    return () => { disposed = true; detach(); sceneRef.current?.dispose(); sceneRef.current = null; };
  }, [bundleUrl]);

  return (
    <div>
      <canvas ref={canvasRef} style={{ width: "100%", display: "block", touchAction: "none" }} />
      <p style={{ fontFamily: "system-ui", padding: "0 8px" }}>{status}</p>
    </div>
  );
}
```

`viewer/src/App.tsx`:
```tsx
import ParallaxViewer from "./components/ParallaxViewer";

export default function App() {
  const name = new URLSearchParams(window.location.search).get("bundle");
  return <ParallaxViewer bundleUrl={name ? `/bundles/${name}` : null} />;
}
```

- [ ] **Step 8: Verify in the browser (checkpoint)**

Run: `cd viewer && npm run dev`
Open `http://localhost:5173` — synthetic demo wiggles with the mouse.
Then extract a real bundle into the viewer:
`cd extract && swift run depth-extract ../samples -o ../viewer/public/bundles`
Open `http://localhost:5173/?bundle=<bundle-dir-name>` — the real photo parallaxes with mouse movement. Screenshot/eyeball; janky edges are acceptable.

- [ ] **Step 9: Run all viewer tests and commit**

Run: `cd viewer && npx vitest run && npm run build`
Expected: tests pass, build clean.

```bash
git add -A && git commit -m "feat: parallax viewer — bundle loader, displaced-quad shader, mouse input"
```

- [ ] Task 3.B complete

### Phase 3 Exit Criteria

Before moving to Phase 4, ALL of the following must be true:

- [ ] `cd viewer && npx vitest run` — 4 `parseManifest` tests pass
- [ ] `npm run build` clean
- [ ] Synthetic demo at `http://localhost:5173` parallaxes with mouse movement
- [ ] A real extracted bundle at `?bundle=<name>` parallaxes with mouse movement (UF-1 visible)
- [ ] Invalid/missing bundle URL falls back to synthetic demo with an error message in the status line
- [ ] All task and step checkboxes in Phase 3 are marked `[x]` in this plan file

---

## Phase 4: Phone experience

**Objective:** The viewer runs over LAN HTTPS on iPhone Safari with gyro-driven parallax — UF-2, the project's payoff moment.

**Can run in parallel:** Sequential — 4.A (gyro) → 4.B (HTTPS + walkthrough).

### Task 4.A: Gyro input with iOS permission flow

**Files:**
- Modify: `viewer/src/lib/inputs.ts`, `viewer/src/components/ParallaxViewer.tsx`

**Interfaces:**
- Consumes: `ParallaxScene.setOffset`, `attachMouseInput`.
- Produces: `gyroAvailable(): boolean`, `attachGyroInput(onOffset: OffsetCallback): Promise<() => void>` — requests iOS permission (must be called from a user gesture), captures the first orientation reading as the neutral baseline, maps ±15° of tilt to offset [-1, 1]. Rejects with `Error` if permission denied/unsupported.

- [ ] **Step 1: Extend inputs.ts**

Append:
```ts
interface IOSOrientationEvent { requestPermission?: () => Promise<"granted" | "denied"> }

export function gyroAvailable(): boolean {
  return typeof window !== "undefined" && "DeviceOrientationEvent" in window;
}

/** Tilt relative to the pose when attached. ±RANGE degrees maps to [-1, 1]. */
export async function attachGyroInput(onOffset: OffsetCallback): Promise<() => void> {
  if (!gyroAvailable()) throw new Error("DeviceOrientation not supported");
  const ctor = DeviceOrientationEvent as unknown as IOSOrientationEvent;
  if (typeof ctor.requestPermission === "function") {
    const result = await ctor.requestPermission();
    if (result !== "granted") throw new Error("Motion permission denied");
  }
  const RANGE = 15; // degrees of tilt for full parallax
  let base: { beta: number; gamma: number } | null = null;
  const onOrient = (e: DeviceOrientationEvent) => {
    if (e.beta == null || e.gamma == null) return;
    if (!base) base = { beta: e.beta, gamma: e.gamma };
    const x = Math.max(-1, Math.min(1, (e.gamma - base.gamma) / RANGE));
    const y = Math.max(-1, Math.min(1, (e.beta - base.beta) / RANGE));
    onOffset(x, -y);
  };
  window.addEventListener("deviceorientation", onOrient);
  return () => window.removeEventListener("deviceorientation", onOrient);
}
```

- [ ] **Step 2: Add the enable-gyro button to ParallaxViewer.tsx**

Add state and handler inside the component (below the existing `useEffect`):
```tsx
  const [gyro, setGyro] = useState<"off" | "on" | "error">("off");
  const gyroDetach = useRef<() => void>(() => {});

  async function enableGyro() {
    try {
      gyroDetach.current = await attachGyroInput((x, y) => sceneRef.current?.setOffset(x, y));
      setGyro("on");
    } catch (e) {
      setStatus((e as Error).message);
      setGyro("error");
    }
  }
  useEffect(() => () => gyroDetach.current(), []);
```
And in the JSX, next to the status line:
```tsx
      {gyroAvailable() && gyro !== "on" && (
        <button onClick={enableGyro} style={{ margin: 8, padding: "12px 20px", fontSize: 16 }}>
          Enable gyro parallax
        </button>
      )}
```
Import `attachGyroInput, gyroAvailable` from `../lib/inputs` and `useRef` state as needed. Keep mouse input attached even when gyro is on (last writer wins — fine for a PoC).

- [ ] **Step 3: Verify on desktop (no regression)**

Run: `cd viewer && npx vitest run && npm run build && npm run dev`
Expected: tests/build pass; desktop still mouse-wiggles; no gyro button on desktop Chrome (or it errors gracefully).

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "feat: gyro parallax input with iOS permission flow"
```

- [ ] Task 4.A complete

---

### Task 4.B: HTTPS LAN serving + iPhone end-to-end walkthrough

**Files:**
- Modify: `viewer/vite.config.ts`, `README.md`

**Interfaces:**
- Consumes: everything prior.
- Produces: `npm run dev` serves HTTPS on the LAN (iOS requires a secure context for `DeviceOrientationEvent.requestPermission`); README documents the full photo→wiggle walkthrough.

- [ ] **Step 1: Enable HTTPS + LAN host in vite.config.ts**

```ts
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import basicSsl from "@vitejs/plugin-basic-ssl";

export default defineConfig({
  plugins: [react(), basicSsl()],
  server: { host: true },
});
```

- [ ] **Step 2: Write the walkthrough in README.md**

Append:
```markdown
## Photo → wiggle on your iPhone

1. Shoot a Portrait-mode photo. AirDrop it to this Mac (or Photos → File → Export → Export Unmodified Original).
2. Extract: `cd extract && swift run depth-extract ~/Downloads/IMG_1234.heic -o ../viewer/public/bundles`
3. Serve: `cd viewer && npm run dev` — note the `https://192.168.x.x:5173` Network URL.
4. On the iPhone (same Wi-Fi), open that URL in Safari. Accept the self-signed-certificate warning
   (Advanced → proceed). Then open `https://192.168.x.x:5173/?bundle=IMG_1234`.
5. Tap **Enable gyro parallax** and grant motion access. Wiggle the phone.

Notes: the neutral pose is captured the moment you tap the button — hold the phone how you
intend to view it, then tap. Reload to re-baseline.
```

- [ ] **Step 3: End-to-end verification on the phone (checkpoint — user in the loop)**

Run the walkthrough top to bottom with a real photo. Success criteria: gyro tilt visibly parallaxes the real portrait on the iPhone. Desktop mouse check: `https://localhost:5173/?bundle=<name>` still works (accept cert locally).

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "feat: HTTPS LAN serving + iPhone walkthrough — M2 complete"
```

- [ ] Task 4.B complete

### Phase 4 Exit Criteria

Before moving to Phase 5, ALL of the following must be true:

- [ ] Desktop regression: mouse parallax still works over `https://localhost:5173` (cert accepted)
- [ ] On a real iPhone over LAN HTTPS: page loads, "Enable gyro parallax" tap prompts for and receives motion permission
- [ ] Tilting the phone visibly parallaxes a real extracted portrait (UF-2 — manual, user-confirmed)
- [ ] README walkthrough followed verbatim reproduces the above from a fresh photo
- [ ] All task and step checkboxes in Phase 4 are marked `[x]` in this plan file

---

## Phase 5: E2E tests

**Objective:** UF-1 is covered by an automated Playwright test; UF-2 has a recorded manual verification.

**Can run in parallel:** Single task.

### Task 5.A: Playwright E2E for mouse parallax (UF-1)

**Files:**
- Create: `viewer/playwright.config.ts`, `viewer/e2e/parallax.spec.ts`
- Modify: `viewer/package.json` (devDependency `@playwright/test`, script `test:e2e`)

**Interfaces:**
- Consumes: the dev server from Task 4.B (HTTPS via basic-ssl), the synthetic fallback bundle from Task 3.B (so the test needs no real photo assets).
- Produces: `npm run test:e2e` — spec `"mouse parallax shifts rendered pixels"` (name must match the spec's User Flows table).

- [ ] **Step 1: Install Playwright**

Run: `cd viewer && npm install -D @playwright/test && npx playwright install chromium`

- [ ] **Step 2: Write playwright.config.ts**

```ts
import { defineConfig } from "@playwright/test";

export default defineConfig({
  testDir: "e2e",
  use: { baseURL: "https://localhost:5173", ignoreHTTPSErrors: true },
  webServer: {
    command: "npm run dev -- --port 5173",
    url: "https://localhost:5173",
    ignoreHTTPSErrors: true,
    reuseExistingServer: true,
  },
});
```

- [ ] **Step 3: Write the failing test**

`viewer/e2e/parallax.spec.ts`:
```ts
import { test, expect } from "@playwright/test";

test("mouse parallax shifts rendered pixels", async ({ page }) => {
  await page.goto("/"); // no ?bundle= — synthetic demo, zero assets needed
  const canvas = page.locator("canvas");
  await expect(canvas).toBeVisible();
  const box = (await canvas.boundingBox())!;

  await page.mouse.move(box.x + 10, box.y + 10);
  await page.waitForTimeout(600); // let the eased offset settle
  const before = await canvas.screenshot();

  await page.mouse.move(box.x + box.width - 10, box.y + box.height - 10);
  await page.waitForTimeout(600);
  const after = await canvas.screenshot();

  expect(before.equals(after)).toBe(false);
});
```

Add to `viewer/package.json` scripts: `"test:e2e": "playwright test"`.

- [ ] **Step 4: Run the e2e test**

Run: `cd viewer && npm run test:e2e`
Expected: 1 test PASSES (it fails only if the renderer or input wiring regressed — if it fails, debug the app, not the test).

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "test: Playwright e2e for mouse parallax (UF-1)"
```

- [ ] Task 5.A complete

### Phase 5 Exit Criteria (plan complete)

- [ ] UF-1: `npm run test:e2e` passes — `"mouse parallax shifts rendered pixels"`
- [ ] UF-2: manual on-device gyro wiggle confirmed by the user (from Phase 4) and noted in Notes below
- [ ] `swift test` (extract) and `vitest run` (viewer) both green
- [ ] All task and step checkboxes in all phases are marked `[x]` in this plan file

---

## Out of scope (future plans)

- M3: ComfyUI pipeline (depth refine/upscale, layer split, occlusion inpaint) + layered renderer.
- M4: lighting (normal maps, IC-Light bakes).
- Backlog: spatial-photo stereo extraction; custom capture app; video.

---

## Notes

> Add entries here during implementation. Include decisions made, deviations from the plan, and anything a future agent needs to know to continue correctly.

- **D-001** 2026-07-03 [Phase 1–5]: Plan refined into phases with exit criteria; tasks renumbered from flat 1–9 to Phase.Letter (1.A–5.A). Original task content unchanged.
- **D-002** 2026-07-03 [Task 2.B]: Review found Swift Codable omits nil `source.deviceModel` (key absent) rather than emitting `null`. Contract decision: optional manifest fields (`matte`, `source.deviceModel`) are omitted when absent. Task 3.B's TS type must use `deviceModel?: string | null`.
