import XCTest
@testable import DepthExtractKit

final class ExtractorErrorTests: XCTestCase {
    func testErrorDescriptionsMentionFile() {
        let url = URL(fileURLWithPath: "/tmp/IMG_0001.heic")
        XCTAssertTrue(ExtractError.noDepthData(url).description.contains("IMG_0001.heic"))
        XCTAssertTrue(ExtractError.unreadableFile(url).description.contains("/tmp/IMG_0001.heic"))
    }
}
