import Foundation
import RealityKit

/// Records requested settings separately from measured output. Limits are not targets.
struct ReconstructionReport: Encodable {
    let schemaVersion = 1
    let appVersion: String
    let operatingSystem: String
    let physicalMemoryBytes: UInt64
    let profile: String
    let requestedDetail: String
    let requestedPolygonLimit: UInt?
    let requestedTextureDimension: Int?
    let requestedMaps: String
    let featureSensitivity: String
    let sampleOrdering: String
    let objectMaskingEnabled: Bool
    let ignoreInputBoundingBox: Bool?
    let inputCount: Int
    var skippedSampleIDs: Set<Int> = []
    var invalidSamples: [Int: String] = [:]
    var automaticDownsampling = false
    var outcome = "processing"
    var failure: String?
    var elapsedSeconds: Double?
    var textures: [USDZTextureInspector.Texture] = []
    var inspectionNote: String?
    let referenceTriangles = 1_105_234
    let referenceColorPixels = 134_217_728 // Two 8192² color atlases, not normal/AO maps.

    init(quality: ReconstructionQuality, configuration: PhotogrammetrySession.Configuration, inputCount: Int) {
        appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development"
        operatingSystem = ProcessInfo.processInfo.operatingSystemVersionString
        physicalMemoryBytes = ProcessInfo.processInfo.physicalMemory
        profile = quality.title
        requestedDetail = String(describing: quality.detail)
        requestedPolygonLimit = quality == .full ? configuration.customDetailSpecification.maximumPolygonCount : nil
        if quality == .full {
            if #available(macOS 15, *) { requestedTextureDimension = 16384 }
            else { requestedTextureDimension = 8192 }
        } else { requestedTextureDimension = nil }
        requestedMaps = quality == .full ? "PNG diffuse color only" : "RealityKit native preset"
        featureSensitivity = String(describing: configuration.featureSensitivity)
        sampleOrdering = String(describing: configuration.sampleOrdering)
        objectMaskingEnabled = configuration.isObjectMaskingEnabled
        if #available(macOS 15, *) { ignoreInputBoundingBox = configuration.ignoreBoundingBox }
        else { ignoreInputBoundingBox = nil }
        self.inputCount = inputCount
    }

    var outputSummary: String? {
        guard outcome == "completed" else { return nil }
        let color = textures.filter(\.isObjectCaptureColorMap)
        guard !color.isEmpty else { return "Color texture dimensions unavailable; see Run Report." }
        return "Actual color textures: " + color.map { "\($0.width) × \($0.height)" }.joined(separator: ", ")
    }

    var warningSummary: String? {
        var messages: [String] = []
        let discarded = skippedSampleIDs.union(invalidSamples.keys).count
        if discarded > 0 { messages.append("\(discarded) input images skipped/invalid (IDs in Run Report).") }
        if automaticDownsampling { messages.append("RealityKit reduced input resolution due to resource constraints.") }
        // This filename convention is produced by Object Capture. Do not count normal maps as color detail.
        let color = textures.filter(\.isObjectCaptureColorMap)
        if outcome == "completed", !color.isEmpty,
           color.reduce(Int64(0), { $0 + Int64($1.width) * Int64($1.height) }) < Int64(referenceColorPixels),
           profile == "Reference" || profile == "Raw" {
            messages.append("Output color texture pixel count is below the antenna reference; see Run Report.")
        }
        if inspectionNote != nil { messages.append("Output texture inspection unavailable; see Run Report.") }
        return messages.isEmpty ? nil : messages.joined(separator: " ")
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }
}

/// Reads stored ZIP local headers and PNG IHDRs without decoding textures or loading the mesh.
/// USDZ uses uncompressed ZIP entries. Unsupported variants are reported, never treated as zero detail.
enum USDZTextureInspector {
    struct Texture: Codable, Equatable {
        let name: String
        let width: Int
        let height: Int
        var isObjectCaptureColorMap: Bool {
            name.range(of: #"_tex\d+\.png$"#, options: .regularExpression) != nil
        }
    }

    enum InspectionError: LocalizedError {
        case unsupportedArchive
        var errorDescription: String? { "USDZ uses an unsupported or invalid ZIP/PNG structure. No texture sizes were inferred." }
    }

    static func inspect(_ url: URL) throws -> [Texture] {
        let file = try FileHandle(forReadingFrom: url)
        defer { try? file.close() }
        let size = try file.seekToEnd()
        var offset: UInt64 = 0
        var result: [Texture] = []
        func read(_ count: Int) throws -> Data {
            let data = try file.read(upToCount: count) ?? Data()
            guard data.count == count else { throw InspectionError.unsupportedArchive }
            return data
        }
        while offset < size {
            try file.seek(toOffset: offset)
            let signature = try read(4)
            if signature == Data([0x50, 0x4b, 0x01, 0x02]) { return result }
            guard signature == Data([0x50, 0x4b, 0x03, 0x04]) else { throw InspectionError.unsupportedArchive }
            let header = signature + (try read(26))
            func le(_ start: Int, _ count: Int) -> UInt64 {
                (0..<count).reduce(0) { $0 | (UInt64(header[start + $1]) << (8 * $1)) }
            }
            let flags = le(6, 2)
            let length = le(18, 4)
            let nameLength = le(26, 2)
            let extraLength = le(28, 2)
            guard flags & 9 == 0, le(8, 2) == 0, length != UInt64(UInt32.max),
                  length == le(22, 4) else { throw InspectionError.unsupportedArchive }
            let nameData = try read(Int(nameLength))
            let name = String(decoding: nameData, as: UTF8.self)
            let payload = offset + 30 + nameLength + extraLength
            guard payload <= size, length <= size - payload else { throw InspectionError.unsupportedArchive }
            if name.lowercased().hasSuffix(".png") {
                guard length >= 24 else { throw InspectionError.unsupportedArchive }
                try file.seek(toOffset: payload)
                let png = try read(24)
                guard png.prefix(8) == Data([137, 80, 78, 71, 13, 10, 26, 10]),
                      png[12..<16] == Data("IHDR".utf8) else { throw InspectionError.unsupportedArchive }
                func be(_ start: Int) -> Int { (0..<4).reduce(0) { ($0 << 8) | Int(png[start + $1]) } }
                let width = be(16), height = be(20)
                guard width > 0, height > 0, width <= Int(Int32.max), height <= Int(Int32.max) else { throw InspectionError.unsupportedArchive }
                result.append(Texture(name: name, width: width, height: height))
            }
            offset = payload + length
        }
        throw InspectionError.unsupportedArchive
    }
}
