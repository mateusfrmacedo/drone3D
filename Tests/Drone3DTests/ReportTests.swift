import XCTest
import RealityKit
@testable import Drone3DApp

final class ReportTests: XCTestCase {
    func testWarningsPersistAndDeduplicateWithoutClaimingUsedCount() throws {
        var configuration = PhotogrammetrySession.Configuration()
        ReconstructionQuality.full.configure(&configuration)
        var report = ReconstructionReport(quality: .full, configuration: configuration, inputCount: 720)
        XCTAssertNil(report.warningSummary)
        report.skippedSampleIDs = [651, 652]
        report.invalidSamples[651] = "invalid"
        report.automaticDownsampling = true
        report.outcome = "completed"
        report.textures = [.init(name: "0/baked_mesh_tex0.png", width: 4096, height: 4096)]
        XCTAssertTrue(report.warningSummary!.contains("2 input images"))
        XCTAssertTrue(report.warningSummary!.contains("reduced input resolution"))
        XCTAssertTrue(report.warningSummary!.contains("below the antenna"))
        let json = try JSONSerialization.jsonObject(with: report.encoded()) as! [String: Any]
        XCTAssertEqual(json["requestedPolygonLimit"] as? Int, 2_000_000)
        XCTAssertEqual(json["requestedDetail"] as? String, "custom")
    }

    func testOnlyColorMapsCountTowardReference() {
        var report = ReconstructionReport(quality: .raw, configuration: .init(), inputCount: 100)
        report.outcome = "completed"
        report.textures = [
            .init(name: "0/baked_mesh_tex0.png", width: 8192, height: 8192),
            .init(name: "0/baked_mesh_norm0.png", width: 8192, height: 8192)
        ]
        XCTAssertNotNil(report.warningSummary)
        report.textures.append(.init(name: "0/baked_mesh_tex1.png", width: 8192, height: 8192))
        XCTAssertNil(report.warningSummary)
    }

    func testStoredZipPNGHeadersAndTruncation() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("fixture.usdz")
        let name = Data("0/baked_mesh_tex0.png".utf8)
        var header = Data(repeating: 0, count: 30)
        header.replaceSubrange(0..<4, with: [0x50, 0x4b, 0x03, 0x04])
        header[18] = 24; header[22] = 24; header[26] = UInt8(name.count)
        let png = Data([137,80,78,71,13,10,26,10, 0,0,0,13, 73,72,68,82, 0,0,32,0, 0,0,32,0])
        let archive = header + name + png + Data([0x50,0x4b,0x01,0x02])
        try archive.write(to: url)
        XCTAssertEqual(try USDZTextureInspector.inspect(url), [.init(name: "0/baked_mesh_tex0.png", width: 8192, height: 8192)])
        try archive.prefix(archive.count - 8).write(to: url)
        XCTAssertThrowsError(try USDZTextureInspector.inspect(url))
    }

    func testLocalReferenceFilesWhenProvided() throws {
        guard let root = ProcessInfo.processInfo.environment["DRONE3D_REFERENCE_ROOT"] else {
            throw XCTSkip("Optional private reference assets are not committed")
        }
        let antenna = try USDZTextureInspector.inspect(URL(fileURLWithPath: root).appendingPathComponent("Antena/antenna2.usdz"))
        XCTAssertEqual(antenna.count, 2)
        XCTAssertTrue(antenna.allSatisfy { $0.width == 8192 && $0.height == 8192 && $0.isObjectCaptureColorMap })
        let church = try USDZTextureInspector.inspect(URL(fileURLWithPath: root).appendingPathComponent("Igreja 3d/Igreja_3D.usdz"))
        XCTAssertEqual(church.count, 4)
        XCTAssertEqual(church.filter(\.isObjectCaptureColorMap).count, 1)
        XCTAssertTrue(church.allSatisfy { $0.width == 4096 && $0.height == 4096 })
    }
}
