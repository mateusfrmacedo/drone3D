import Foundation
import SceneKit
import simd
import RealityKit

enum CaptureScope {
    static func configure(_ configuration: inout PhotogrammetrySession.Configuration, preserveTerrain: Bool) {
        configuration.isObjectMaskingEnabled = !preserveTerrain
        configuration.sampleOrdering = preserveTerrain ? .sequential : .unordered
        if #available(macOS 15, *) { configuration.ignoreBoundingBox = preserveTerrain }
    }
}

struct CropBox: Sendable {
    var minimum: SIMD3<Float>
    var maximum: SIMD3<Float>
    var isValid: Bool {
        (0..<3).allSatisfy { minimum[$0].isFinite && maximum[$0].isFinite && minimum[$0] < maximum[$0] }
    }
}

struct CropVertex {
    var position: SIMD3<Float>
    var normal: SIMD3<Float>
    var uv: SIMD2<Float>

    func interpolated(to other: CropVertex, t: Float) -> CropVertex {
        CropVertex(position: position + (other.position - position) * t,
                   normal: normal + (other.normal - normal) * t,
                   uv: uv + (other.uv - uv) * t)
    }
}

/// Owns a scene produced on a worker and handed to the main actor; never mutated concurrently.
struct CropSceneResult: @unchecked Sendable {
    let scene: SCNScene
    let bounds: CropBox
    let triangles: Int
}

enum TerrainClipper {
    enum Failure: LocalizedError {
        case invalidBox, unsupportedMesh, empty, exportFailed, originalDestination
        var errorDescription: String? {
            switch self {
            case .invalidBox: "The crop box must have positive width, depth and height."
            case .unsupportedMesh: "This model has unsupported geometry. Use a static, triangulated Object Capture USDZ."
            case .empty: "The box does not contain any surface. Enlarge or move it."
            case .exportFailed: "SceneKit could not export the cropped USDZ. The original was not changed."
            case .originalDestination: "Choose a new file. The original model cannot be overwritten."
            }
        }
    }

    static func clip(_ triangle: [CropVertex], to box: CropBox) -> [CropVertex] {
        var polygon = triangle
        for axis in 0..<3 {
            for lower in [true, false] {
                guard !polygon.isEmpty else { return [] }
                let limit = lower ? box.minimum[axis] : box.maximum[axis]
                func distance(_ v: CropVertex) -> Float {
                    lower ? v.position[axis] - limit : limit - v.position[axis]
                }
                var output: [CropVertex] = []
                var previous = polygon.last!
                var previousDistance = distance(previous)
                for current in polygon {
                    let currentDistance = distance(current)
                    if (currentDistance >= 0) != (previousDistance >= 0) {
                        let t = previousDistance / (previousDistance - currentDistance)
                        output.append(previous.interpolated(to: current, t: t))
                    }
                    if currentDistance >= 0 { output.append(current) }
                    previous = current
                    previousDistance = currentDistance
                }
                polygon = output
            }
        }
        return polygon
    }

    static func load(_ url: URL) throws -> CropSceneResult {
        let scene = try SCNScene(url: url, options: [.checkConsistency: true])
        var minimum = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
        var maximum = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
        var triangles = 0
        scene.rootNode.enumerateChildNodes { node, _ in
            guard let geometry = node.geometry else { return }
            let bounds = geometry.boundingBox
            for x in [bounds.min.x, bounds.max.x] {
                for y in [bounds.min.y, bounds.max.y] {
                    for z in [bounds.min.z, bounds.max.z] {
                        let p = node.simdWorldTransform * SIMD4<Float>(Float(x), Float(y), Float(z), 1)
                        minimum = simd_min(minimum, SIMD3(p.x, p.y, p.z))
                        maximum = simd_max(maximum, SIMD3(p.x, p.y, p.z))
                    }
                }
            }
            triangles += geometry.elements.filter { $0.primitiveType == .triangles }.reduce(0) { $0 + $1.primitiveCount }
        }
        guard minimum.x.isFinite, minimum.x <= maximum.x else { throw Failure.empty }
        // Thin surfaces still need a nonzero slider range.
        let padding = max(simd_length(maximum - minimum) * 0.00001, 0.00001)
        return CropSceneResult(scene: scene, bounds: CropBox(minimum: minimum - padding, maximum: maximum + padding), triangles: triangles)
    }

    static func croppedScene(from url: URL, box: CropBox) throws -> CropSceneResult {
        guard box.isValid else { throw Failure.invalidBox }
        let input = try load(url)
        let output = SCNScene()
        var nodes: [SCNNode] = []
        input.scene.rootNode.enumerateChildNodes { node, _ in if node.geometry != nil { nodes.append(node) } }
        var total = 0
        for node in nodes {
            try Task.checkCancellation()
            guard let geometry = node.geometry,
                  let positions = geometry.sources(for: .vertex).first,
                  let normals = geometry.sources(for: .normal).first,
                  let uvs = geometry.sources(for: .texcoord).first,
                  node.skinner == nil, node.morpher == nil else { throw Failure.unsupportedMesh }
            let transform = node.simdWorldTransform
            let linear = simd_float3x3(SIMD3(transform.columns.0.x, transform.columns.0.y, transform.columns.0.z),
                                      SIMD3(transform.columns.1.x, transform.columns.1.y, transform.columns.1.z),
                                      SIMD3(transform.columns.2.x, transform.columns.2.y, transform.columns.2.z))
            guard abs(simd_determinant(linear)) > 1e-12 else { throw Failure.unsupportedMesh }
            let normalTransform = simd_transpose(simd_inverse(linear))
            for (materialIndex, element) in geometry.elements.enumerated() {
                guard element.primitiveType == .triangles else { throw Failure.unsupportedMesh }
                var points: [SCNVector3] = [], directions: [SCNVector3] = []
                var textureCoordinates: [CGPoint] = []
                for face in 0..<element.primitiveCount {
                    if face % 4096 == 0 { try Task.checkCancellation() }
                    var triangle: [CropVertex] = []
                    for corner in 0..<3 {
                        let index = try vertexIndex(element, offset: face * 3 + corner)
                        let p = try values(positions, index: index, count: 3)
                        let n = try values(normals, index: index, count: 3)
                        let uv = try values(uvs, index: index, count: 2)
                        let world = transform * SIMD4(p[0], p[1], p[2], 1)
                        triangle.append(CropVertex(position: SIMD3(world.x, world.y, world.z),
                                                   normal: normalTransform * SIMD3(n[0], n[1], n[2]), uv: SIMD2(uv[0], uv[1])))
                    }
                    let polygon = clip(triangle, to: box)
                    guard polygon.count >= 3 else { continue }
                    for k in 1..<(polygon.count - 1) {
                        var vertices = [polygon[0], polygon[k], polygon[k + 1]]
                        if simd_determinant(linear) < 0 { vertices.swapAt(1, 2) }
                        guard simd_length_squared(simd_cross(vertices[1].position - vertices[0].position,
                                                           vertices[2].position - vertices[0].position)) > 1e-20 else { continue }
                        for vertex in vertices {
                            points.append(SCNVector3(vertex.position))
                            let length = simd_length(vertex.normal)
                            directions.append(SCNVector3(length > 0 ? vertex.normal / length : SIMD3(0, 1, 0)))
                            textureCoordinates.append(CGPoint(x: CGFloat(vertex.uv.x), y: CGFloat(vertex.uv.y)))
                        }
                    }
                }
                guard !points.isEmpty else { continue }
                guard points.count <= Int(UInt32.max) else { throw Failure.unsupportedMesh }
                let indices = (0..<points.count).map(UInt32.init)
                let mesh = SCNGeometry(sources: [SCNGeometrySource(vertices: points), SCNGeometrySource(normals: directions),
                                                SCNGeometrySource(textureCoordinates: textureCoordinates)],
                                       elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)])
                guard !geometry.materials.isEmpty else { throw Failure.unsupportedMesh }
                mesh.materials = [geometry.materials[materialIndex % geometry.materials.count]]
                output.rootNode.addChildNode(SCNNode(geometry: mesh))
                total += points.count / 3
            }
        }
        guard total > 0 else { throw Failure.empty }
        return CropSceneResult(scene: output, bounds: box, triangles: total)
    }

    static func export(source: URL, destination: URL, box: CropBox) throws {
        guard source.resolvingSymlinksInPath().standardizedFileURL != destination.resolvingSymlinksInPath().standardizedFileURL,
              !FileManager.default.fileExists(atPath: destination.path) else { throw Failure.originalDestination }
        let result = try croppedScene(from: source, box: box)
        let temporary = destination.deletingLastPathComponent().appendingPathComponent(".crop-\(UUID().uuidString).usdz")
        defer { try? FileManager.default.removeItem(at: temporary) }
        guard result.scene.write(to: temporary, options: nil, delegate: nil, progressHandler: nil) else { throw Failure.exportFailed }
        try Task.checkCancellation()
        let check = try load(temporary)
        guard check.triangles > 0 else { throw Failure.exportFailed }
        try FileManager.default.moveItem(at: temporary, to: destination)
    }

    private static func values(_ source: SCNGeometrySource, index: Int, count: Int) throws -> [Float] {
        guard source.usesFloatComponents, [4, 8].contains(source.bytesPerComponent), source.componentsPerVector >= count,
              index >= 0, index < source.vectorCount else { throw Failure.unsupportedMesh }
        let offset = source.dataOffset + index * source.dataStride
        guard offset >= 0, offset + count * source.bytesPerComponent <= source.data.count else { throw Failure.unsupportedMesh }
        return source.data.withUnsafeBytes { bytes in
            (0..<count).map {
                source.bytesPerComponent == 4
                    ? bytes.loadUnaligned(fromByteOffset: offset + $0 * 4, as: Float.self)
                    : Float(bytes.loadUnaligned(fromByteOffset: offset + $0 * 8, as: Double.self))
            }
        }
    }

    private static func vertexIndex(_ element: SCNGeometryElement, offset: Int) throws -> Int {
        let byte = offset * element.bytesPerIndex
        guard byte >= 0, byte + element.bytesPerIndex <= element.data.count else { throw Failure.unsupportedMesh }
        return try element.data.withUnsafeBytes { data in
            switch element.bytesPerIndex {
            case 1: return Int(data.loadUnaligned(fromByteOffset: byte, as: UInt8.self))
            case 2: return Int(data.loadUnaligned(fromByteOffset: byte, as: UInt16.self))
            case 4: return Int(data.loadUnaligned(fromByteOffset: byte, as: UInt32.self))
            default: throw Failure.unsupportedMesh
            }
        }
    }
}
