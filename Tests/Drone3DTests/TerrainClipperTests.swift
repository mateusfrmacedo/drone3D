import XCTest
import SceneKit
import RealityKit
@testable import Drone3DApp

final class TerrainClipperTests: XCTestCase {
    let box = CropBox(minimum: SIMD3(0, 0, 0), maximum: SIMD3(1, 1, 1))

    func testTerrainScopeDoesNotMaskGroundAndObjectScopeRestoresMasking() {
        var configuration = PhotogrammetrySession.Configuration()
        CaptureScope.configure(&configuration, preserveTerrain: true)
        XCTAssertFalse(configuration.isObjectMaskingEnabled)
        XCTAssertEqual(configuration.sampleOrdering, .sequential)
        if #available(macOS 15, *) { XCTAssertTrue(configuration.ignoreBoundingBox) }
        CaptureScope.configure(&configuration, preserveTerrain: false)
        XCTAssertTrue(configuration.isObjectMaskingEnabled)
        XCTAssertEqual(configuration.sampleOrdering, .unordered)
        if #available(macOS 15, *) { XCTAssertFalse(configuration.ignoreBoundingBox) }
    }

    func vertex(_ x: Float, _ y: Float, _ z: Float) -> CropVertex {
        CropVertex(position: SIMD3(x, y, z), normal: SIMD3(0, 0, 1), uv: SIMD2(x, y))
    }

    func testClipInterpolatesUVsAtBoundary() {
        let result = TerrainClipper.clip([vertex(-1, 0, 0.5), vertex(1, 0, 0.5), vertex(1, 1, 0.5)], to: box)
        XCTAssertEqual(result.count, 4)
        for v in result {
            XCTAssertGreaterThanOrEqual(v.position.x, 0)
            XCTAssertLessThanOrEqual(v.position.x, 1)
            XCTAssertEqual(v.uv.x, v.position.x, accuracy: 0.00001)
            XCTAssertEqual(v.uv.y, v.position.y, accuracy: 0.00001)
        }
    }

    func testAllSixPlanesAndOutsideTriangle() {
        for axis in 0..<3 {
            var triangle = [vertex(-2, -2, 0.5), vertex(3, -2, 0.5), vertex(0.5, 3, 0.5)]
            if axis != 2 {
                for i in triangle.indices { let old = triangle[i].position[axis]; triangle[i].position[axis] = triangle[i].position[2]; triangle[i].position[2] = old }
            }
            let polygon = TerrainClipper.clip(triangle, to: box)
            XCTAssertGreaterThanOrEqual(polygon.count, 3)
            for v in polygon {
                for a in 0..<3 { XCTAssertGreaterThanOrEqual(v.position[a], -0.00001); XCTAssertLessThanOrEqual(v.position[a], 1.00001) }
            }
        }
        XCTAssertTrue(TerrainClipper.clip([vertex(2, 0, 0), vertex(3, 0, 0), vertex(2, 1, 0)], to: box).isEmpty)
        XCTAssertFalse(CropBox(minimum: .zero, maximum: .zero).isValid)
    }

    func testSceneRoundTripAndOriginalProtection() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("source.usdz")
        let scene = SCNScene()
        let mesh = SCNGeometry(sources: [
            SCNGeometrySource(vertices: [SCNVector3(-1, 0, 0), SCNVector3(1, 0, 0), SCNVector3(1, 1, 0)]),
            SCNGeometrySource(normals: Array(repeating: SCNVector3(0, 0, 1), count: 3)),
            SCNGeometrySource(textureCoordinates: [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0), CGPoint(x: 1, y: 1)])
        ], elements: [SCNGeometryElement(indices: [UInt32(0), 1, 2], primitiveType: .triangles)])
        mesh.materials = [SCNMaterial()]
        let node = SCNNode(geometry: mesh)
        node.position = SCNVector3(10, 0, 0)
        scene.rootNode.addChildNode(node)
        XCTAssertTrue(scene.write(to: source, options: nil, delegate: nil, progressHandler: nil))
        let originalData = try Data(contentsOf: source)
        let region = CropBox(minimum: SIMD3(10, -1, -1), maximum: SIMD3(12, 2, 1))
        let cropped = try TerrainClipper.croppedScene(from: source, box: region)
        XCTAssertEqual(cropped.triangles, 2)
        let destination = directory.appendingPathComponent("cropped.usdz")
        try TerrainClipper.export(source: source, destination: destination, box: region)
        XCTAssertEqual(try TerrainClipper.load(destination).triangles, 2)
        XCTAssertEqual(try Data(contentsOf: source), originalData)
        XCTAssertThrowsError(try TerrainClipper.export(source: source, destination: source, box: region))
        XCTAssertThrowsError(try TerrainClipper.export(source: source, destination: destination, box: region))
        XCTAssertThrowsError(try TerrainClipper.croppedScene(from: source, box: box))
    }

    func testRealChurchWhenProvided() throws {
        guard let root = ProcessInfo.processInfo.environment["DRONE3D_REFERENCE_ROOT"],
              let output = ProcessInfo.processInfo.environment["DRONE3D_CROP_OUTPUT"] else {
            throw XCTSkip("Optional private model integration test")
        }
        let source = URL(fileURLWithPath: root).appendingPathComponent("Igreja 3d/Igreja_3D.usdz")
        let loaded = try TerrainClipper.load(source)
        var region = loaded.bounds
        let size = region.maximum - region.minimum
        region.minimum.x += size.x * 0.15
        region.maximum.x -= size.x * 0.15
        region.minimum.z += size.z * 0.15
        region.maximum.z -= size.z * 0.15
        let destination = URL(fileURLWithPath: output)
        try TerrainClipper.export(source: source, destination: destination, box: region)
        let result = try TerrainClipper.load(destination)
        XCTAssertGreaterThan(result.triangles, 0)
        // Boundary triangles are split; the exporter can also duplicate double-sided surfaces.
        // A smaller spatial region does not imply a lower exported triangle count.
        XCTAssertGreaterThanOrEqual(result.bounds.minimum.x, region.minimum.x - 0.01)
        XCTAssertLessThanOrEqual(result.bounds.maximum.z, region.maximum.z + 0.01)
        let textures = try USDZTextureInspector.inspect(destination)
        XCTAssertFalse(textures.isEmpty, "Export must preserve texture assets")
        XCTAssertTrue(textures.contains { $0.width == 4096 && $0.height == 4096 }, "Do not downscale the original textures")
    }
}
