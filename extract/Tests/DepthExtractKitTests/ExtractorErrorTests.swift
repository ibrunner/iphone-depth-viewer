import XCTest
@testable import DepthExtractKit

final class ExtractorErrorTests: XCTestCase {
    func testErrorDescriptionsMentionFile() {
        let url = URL(fileURLWithPath: "/tmp/IMG_0001.heic")
        XCTAssertTrue(ExtractError.noDepthData(url).description.contains("IMG_0001.heic"))
        XCTAssertTrue(ExtractError.unreadableFile(url).description.contains("/tmp/IMG_0001.heic"))
    }

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
}
