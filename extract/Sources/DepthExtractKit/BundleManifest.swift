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
