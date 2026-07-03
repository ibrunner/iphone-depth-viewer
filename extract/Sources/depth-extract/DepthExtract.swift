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
