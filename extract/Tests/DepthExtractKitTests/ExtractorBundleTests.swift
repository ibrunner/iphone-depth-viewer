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
