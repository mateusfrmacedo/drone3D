import XCTest
import RealityKit
@testable import Drone3DApp

final class QualityTests: XCTestCase {
    func testMaximumUsesCustomLosslessTextures() {
        var configuration = PhotogrammetrySession.Configuration()
        ReconstructionQuality.full.configure(&configuration)
        XCTAssertEqual(ReconstructionQuality.full.detail, .custom)
        let specification = configuration.customDetailSpecification
        XCTAssertEqual(specification.textureFormat, .png)
        XCTAssertEqual(specification.outputTextureMaps, .diffuseColor)
        XCTAssertEqual(specification.maximumPolygonCount, 2_000_000)
        if #available(macOS 15.0, *) {
            XCTAssertEqual(specification.maximumTextureDimension, .sixteenK)
        } else {
            XCTAssertEqual(specification.maximumTextureDimension, .eightK)
        }
    }

    func testRawUsesNativePresetWithoutCustomBudget() {
        var configuration = PhotogrammetrySession.Configuration()
        let original = configuration.customDetailSpecification
        ReconstructionQuality.raw.configure(&configuration)
        XCTAssertEqual(ReconstructionQuality.raw.detail, .raw)
        XCTAssertEqual(configuration.customDetailSpecification, original)
        XCTAssertEqual(configuration.featureSensitivity, .high)
    }

    func testQualityDoesNotForceSequentialOrdering() {
        var configuration = PhotogrammetrySession.Configuration()
        configuration.sampleOrdering = .unordered
        ReconstructionQuality.full.configure(&configuration)
        XCTAssertEqual(configuration.sampleOrdering, .unordered)
        XCTAssertEqual(configuration.featureSensitivity, .high)
        XCTAssertEqual(ReconstructionQuality.preview.detail, .preview)
        XCTAssertEqual(ReconstructionQuality.medium.detail, .medium)
    }
}
