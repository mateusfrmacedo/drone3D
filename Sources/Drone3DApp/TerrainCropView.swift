import AppKit
import SceneKit
import SwiftUI
import UniformTypeIdentifiers

struct CropSource: Identifiable {
    let id = UUID()
    let url: URL
}

@MainActor
final class TerrainCropModel: ObservableObject {
    @Published var original: CropSceneResult?
    @Published var preview: CropSceneResult?
    @Published var low = SIMD3<Double>(repeating: 0)
    @Published var high = SIMD3<Double>(repeating: 1)
    @Published var busy = false
    @Published var message = "Loading model…"
    @Published var error: String?
    @Published var savedURL: URL?
    let source: URL

    init(source: URL) { self.source = source }

    var box: CropBox? {
        guard let bounds = original?.bounds else { return nil }
        let size = bounds.maximum - bounds.minimum
        return CropBox(minimum: bounds.minimum + SIMD3<Float>(low) * size,
                       maximum: bounds.minimum + SIMD3<Float>(high) * size)
    }

    func load() async {
        busy = true
        let url = source
        do {
            let result = try await Task.detached(priority: .userInitiated) { try TerrainClipper.load(url) }.value
            original = result
            message = "Adjust the box, then preview the crop. Original: \(result.triangles) triangles."
        } catch { self.error = error.localizedDescription }
        busy = false
    }

    func changed() {
        preview = nil
        savedURL = nil
        error = nil
        message = "Box updated. Preview Crop shows exactly which surfaces will remain."
    }

    func reset() {
        low = SIMD3(repeating: 0)
        high = SIMD3(repeating: 1)
        changed()
    }

    func applyPreview() {
        guard let box, !busy else { return }
        busy = true
        error = nil
        message = "Clipping triangles and preserving texture coordinates…"
        let url = source
        Task {
            do {
                preview = try await Task.detached(priority: .userInitiated) { try TerrainClipper.croppedScene(from: url, box: box) }.value
                message = "Crop preview: \(preview!.triangles) triangles. Cut surfaces are open; no artificial base is added."
            } catch { self.error = error.localizedDescription }
            busy = false
        }
    }

    func save() {
        guard let box, !busy, preview != nil else { return }
        let panel = NSSavePanel()
        panel.title = "Save a new cropped USDZ"
        panel.allowedContentTypes = [UTType(filenameExtension: "usdz")!]
        panel.nameFieldStringValue = source.deletingPathExtension().lastPathComponent + "-cropped.usdz"
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        busy = true
        error = nil
        message = "Exporting cropped USDZ…"
        let url = source
        Task {
            do {
                try await Task.detached(priority: .userInitiated) { try TerrainClipper.export(source: url, destination: destination, box: box) }.value
                savedURL = destination
                message = "Saved \(destination.lastPathComponent). Original preserved."
            } catch { self.error = error.localizedDescription }
            busy = false
        }
    }
}

struct TerrainCropView: View {
    @StateObject private var model: TerrainCropModel
    @Environment(\.dismiss) private var dismiss

    init(source: URL) { _model = StateObject(wrappedValue: TerrainCropModel(source: source)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Terrain crop").font(.title2.bold())
            Text("Keep real ground inside the box. For isolated objects, skip this optional tool. Drag to orbit; scroll to zoom.")
                .font(.caption).foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: 16) {
                if let result = model.preview ?? model.original, let box = model.box {
                    CropSceneView(scene: result.scene, box: box, framing: model.original!.bounds)
                        .frame(minWidth: 480, minHeight: 420)
                } else {
                    Group {
                        if model.error == nil { ProgressView() }
                        else { Text("Preview unavailable").foregroundStyle(.secondary) }
                    }.frame(width: 480, height: 420)
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("Box boundaries").font(.headline)
                    axis("Width · X", index: 0, labels: ("Left", "Right"))
                    axis("Height · Y", index: 1, labels: ("Bottom", "Top"))
                    axis("Depth · Z", index: 2, labels: ("Back", "Front"))
                    Text("Position and size follow the model axes. Keep Bottom below the terrain to retain the ground. This does not close holes or create a solid platform.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("Reset Box", action: model.reset)
                }
                .frame(width: 240)
                .disabled(model.busy || model.original == nil)
            }
            Text(model.message).font(.caption)
            if let error = model.error { Text(error).font(.caption).foregroundStyle(.red).textSelection(.enabled) }
            HStack {
                if model.busy { ProgressView().controlSize(.small) }
                Button("Close") { dismiss() }.disabled(model.busy)
                if let url = model.savedURL {
                    Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                }
                Spacer()
                Button("Preview Crop", action: model.applyPreview).disabled(model.original == nil || model.busy)
                Button("Save New USDZ…", action: model.save)
                    .buttonStyle(.borderedProminent).disabled(model.preview == nil || model.busy)
            }
        }
        .padding(20)
        .frame(width: 800)
        .task { await model.load() }
    }

    private func axis(_ title: String, index: Int, labels: (String, String)) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.subheadline.bold())
            Text("\(labels.0): \(Int(model.low[index] * 100))% · \(labels.1): \(Int(model.high[index] * 100))%")
                .font(.caption.monospacedDigit())
            Slider(value: Binding(get: { model.low[index] }, set: {
                model.low[index] = min($0, model.high[index] - 0.001); model.changed()
            }), in: 0...0.999).accessibilityLabel(labels.0)
            Slider(value: Binding(get: { model.high[index] }, set: {
                model.high[index] = max($0, model.low[index] + 0.001); model.changed()
            }), in: 0.001...1).accessibilityLabel(labels.1)
        }
    }
}

private struct CropSceneView: NSViewRepresentable {
    let scene: SCNScene
    let box: CropBox
    let framing: CropBox

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = true
        view.backgroundColor = .darkGray
        return view
    }

    func updateNSView(_ view: SCNView, context: Context) {
        if view.scene !== scene {
            let camera = SCNNode()
            camera.camera = SCNCamera()
            let center = (framing.minimum + framing.maximum) / 2
            let radius = max(simd_length(framing.maximum - framing.minimum), 0.01)
            camera.camera?.zNear = Double(radius / 10000)
            camera.camera?.zFar = Double(radius * 100)
            camera.simdPosition = center + SIMD3(radius * 0.8, radius * 0.6, radius * 0.8)
            camera.look(at: SCNVector3(center))
            view.scene = scene
            view.pointOfView = camera
            view.defaultCameraController.target = SCNVector3(center)
        }
        scene.rootNode.childNode(withName: "__crop_box", recursively: false)?.removeFromParentNode()
        let size = box.maximum - box.minimum
        var corners: [SCNVector3] = []
        for x: Float in [-0.5, 0.5] {
            for y: Float in [-0.5, 0.5] {
                for z: Float in [-0.5, 0.5] { corners.append(SCNVector3(SIMD3(x, y, z) * size)) }
            }
        }
        var edges: [UInt32] = []
        for index in 0..<8 {
            for bit in [1, 2, 4] where index & bit == 0 { edges += [UInt32(index), UInt32(index | bit)] }
        }
        let geometry = SCNGeometry(sources: [SCNGeometrySource(vertices: corners)],
                                   elements: [SCNGeometryElement(indices: edges, primitiveType: .line)])
        let material = SCNMaterial()
        material.diffuse.contents = NSColor.systemYellow
        material.emission.contents = NSColor.systemYellow
        material.lightingModel = .constant
        material.isDoubleSided = true
        material.readsFromDepthBuffer = false
        geometry.materials = [material]
        let overlay = SCNNode(geometry: geometry)
        overlay.name = "__crop_box"
        overlay.simdPosition = (box.minimum + box.maximum) / 2
        scene.rootNode.addChildNode(overlay)
    }
}
