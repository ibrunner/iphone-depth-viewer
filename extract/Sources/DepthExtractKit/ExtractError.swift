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
