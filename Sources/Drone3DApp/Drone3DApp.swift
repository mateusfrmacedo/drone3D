import AppKit
import Foundation
import ModelIO
import RealityKit
import SwiftUI
import UniformTypeIdentifiers

@main
struct Drone3DApp: App {
    var body: some SwiftUI.Scene {
        WindowGroup("Drone 3D") {
            ContentView()
                .frame(width: 640, height: 570)
        }
        .defaultSize(width: 640, height: 570)
        .windowResizability(.contentSize)
    }
}

struct ContentView: View {
    @StateObject private var model = ReconstructionModel()

    var body: some View {
        Group {
            if #available(macOS 26.0, *) {
                GlassEffectContainer(spacing: 14) {
                    dashboard
                }
            } else {
                dashboard
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(18)
        .alert("Drone 3D", isPresented: $model.showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(model.alertMessage)
        }
    }

    private var dashboard: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            folderCard
            saveCard
            qualityCard
            processingCard
            actions
        }
    }

    private var header: some View {
        HStack {
            Text("Drone 3D")
                .font(.system(size: 38, weight: .bold, design: .rounded))
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    private var folderCard: some View {
        LiquidGlassCard(title: "1  PHOTO FOLDER", symbol: "photo.stack") {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(model.inputFolder?.lastPathComponent ?? "No photo folder selected")
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(model.inputFolder?.path ?? "Choose a folder to begin.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if model.inputFolder != nil {
                        Label("\(model.photoCount) compatible photos", systemImage: "checkmark.circle")
                            .font(.caption)
                            .foregroundStyle(model.photoCount == 0 ? .orange : .secondary)
                    }
                }
                Spacer(minLength: 8)
                LiquidGlassButton("Choose Folder…", action: model.chooseInputFolder)
                    .disabled(model.isRunning)
            }
        }
    }

    private var saveCard: some View {
        LiquidGlassCard(title: "2  SAVE LOCATION", symbol: "folder.badge.gearshape") {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(model.outputURL?.lastPathComponent ?? "USDZ file")
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(model.outputURL?.deletingLastPathComponent().path ?? "Choose a source folder first.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer(minLength: 8)
                LiquidGlassButton("Save As…", action: model.chooseOutputFile)
                    .disabled(model.isRunning || model.inputFolder == nil)
            }
        }
    }

    private var qualityCard: some View {
        LiquidGlassCard(title: "3  QUALITY", symbol: "slider.horizontal.3") {
            Picker("Quality", selection: $model.quality) {
                ForEach(ReconstructionQuality.allCases) { quality in
                    Text(quality.title).tag(quality)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .disabled(model.isRunning)
        }
    }

    private var processingCard: some View {
        LiquidGlassCard(title: "4  PROCESSING", symbol: "waveform.path.ecg") {
            VStack(alignment: .leading, spacing: 10) {
                ProgressView(value: model.progress) {
                    Text(model.status)
                        .font(.subheadline.weight(.medium))
                } currentValueLabel: {
                    Text(model.progress.formatted(.percent.precision(.fractionLength(0))))
                        .font(.caption.monospacedDigit())
                }
                .tint(.indigo)
                HStack(spacing: 14) {
                    Label("Stage: \(model.stage)", systemImage: "gearshape.2")
                    Label("Elapsed: \(model.elapsedText)", systemImage: "clock")
                    if let remaining = model.remainingText {
                        Label("Estimated: \(remaining)", systemImage: "timer")
                    } else {
                        Label("Estimated time will appear here", systemImage: "timer")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                if let error = model.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
            }
        }
    }

    private var actions: some View {
        ZStack {
            HStack {
                if model.completedOutput != nil {
                    LiquidGlassButton("Show in Finder", action: model.revealOutput)
                }
                Spacer()
            }
            if model.isRunning {
                LiquidGlassButton("Cancel", role: .destructive, action: model.cancel)
            } else {
                LiquidGlassButton("Start", prominent: true, large: true, action: model.start)
                    .disabled(!model.canStart)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
    }
}

private struct LiquidGlassCard<Content: View>: View {
    let title: String
    let symbol: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .liquidGlass(in: .rect(cornerRadius: 20))
    }
}

private struct LiquidGlassButton: View {
    @Environment(\.isEnabled) private var isEnabled
    let title: String
    var prominent = false
    var large = false
    var role: ButtonRole?
    let action: () -> Void

    init(_ title: String, prominent: Bool = false, large: Bool = false, role: ButtonRole? = nil, action: @escaping () -> Void) {
        self.title = title
        self.prominent = prominent
        self.large = large
        self.role = role
        self.action = action
    }

    var body: some View {
        if large {
            Button(title, role: role, action: action)
                .buttonStyle(.plain)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 118, height: 35)
                .background(Color.green, in: Capsule())
                .opacity(isEnabled ? 1 : 0.35)
        } else {
            Group {
                if prominent {
                    Button(title, role: role, action: action)
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                } else {
                    Button(title, role: role, action: action)
                        .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal, 2)
            .liquidGlass(in: .capsule)
            .controlSize(.small)
        }
    }
}

private extension View {
    @ViewBuilder
    func liquidGlass(in shape: some InsettableShape) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self.background(.thinMaterial, in: shape)
        }
    }
}

enum ReconstructionQuality: String, CaseIterable, Identifiable {
    case preview, reduced, medium, full

    var id: String { rawValue }

    var title: String {
        switch self {
        case .preview: "Preview"
        case .reduced: "Reduced"
        case .medium: "Medium"
        case .full: "Full"
        }
    }

    var detail: PhotogrammetrySession.Request.Detail {
        switch self {
        case .preview: .preview
        case .reduced: .reduced
        case .medium: .medium
        case .full: .full
        }
    }

    var intelImageSize: Int {
        switch self {
        case .preview: 1024
        case .reduced: 1600
        case .medium: 2400
        case .full: 3600
        }
    }
}

@MainActor
final class ReconstructionModel: ObservableObject {
    @Published var inputFolder: URL?
    @Published var outputURL: URL?
    @Published var quality: ReconstructionQuality = .full
    @Published var photoCount = 0
    @Published var progress = 0.0
    @Published var status = "Waiting for a photo folder"
    @Published var stage = "—"
    @Published var elapsedText = "00:00:00"
    @Published var remainingText: String?
    @Published var errorMessage: String?
    @Published var isRunning = false
    @Published var completedOutput: URL?
    @Published var showingAlert = false
    @Published var alertMessage = ""

    private var session: PhotogrammetrySession?
    private var intelProcessor: IntelPhotogrammetryProcessor?
    private var processingTask: Task<Void, Never>?
    private var timer: Timer?
    private var startedAt: Date?
    private var temporaryOutputURL: URL?
    private let supportedExtensions: Set<String> = ["jpg", "jpeg", "png", "heic", "heif", "tif", "tiff"]

    var canStart: Bool {
        inputFolder != nil && photoCount > 0 && !isRunning
    }

    func chooseInputFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose Photo Folder"
        panel.message = "Select the folder containing the scene photos."
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let folder = panel.url else { return }
        inputFolder = folder
        outputURL = defaultOutputURL(for: folder)
        photoCount = countCompatiblePhotos(in: folder)
        completedOutput = nil
        errorMessage = nil
        status = photoCount > 0 ? "Ready to start" : "No compatible photos found"
        stage = "—"
    }

    func chooseOutputFile() {
        guard let folder = inputFolder else { return }
        let panel = NSSavePanel()
        panel.title = "Save USDZ Model"
        panel.message = "Choose the USDZ file to generate."
        panel.allowedContentTypes = [UTType(filenameExtension: "usdz")!]
        panel.nameFieldStringValue = outputURL?.lastPathComponent ?? defaultOutputURL(for: folder).lastPathComponent
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }
        outputURL = url.pathExtension.lowercased() == "usdz" ? url : url.appendingPathExtension("usdz")
        completedOutput = nil
    }

    func start() {
        guard let inputFolder else { return }
        guard photoCount > 0 else {
            showAlert("No compatible photos were found in the selected folder.")
            return
        }
        let destination = outputURL ?? defaultOutputURL(for: inputFolder)
        outputURL = destination
        guard confirmReplacementIfNeeded(at: destination) else { return }
        let temporaryDestination = temporaryURL(near: destination)

        progress = 0
        status = "Preparing reconstruction"
        stage = "Preparing"
        remainingText = nil
        errorMessage = nil
        completedOutput = nil
        isRunning = true
        startedAt = .now
        temporaryOutputURL = temporaryDestination
        startTimer()

        if PhotogrammetrySession.isSupported {
            startRealityKitReconstruction(
                inputFolder: inputFolder,
                destination: destination,
                temporaryDestination: temporaryDestination
            )
        } else {
            startIntelReconstruction(
                inputFolder: inputFolder,
                destination: destination,
                temporaryDestination: temporaryDestination
            )
        }
    }

    private func startRealityKitReconstruction(inputFolder: URL, destination: URL, temporaryDestination: URL) {
        status = "Starting RealityKit session"
        stage = "Preparing"
        processingTask = Task { [weak self] in
            guard let self else { return }
            do {
                let session = try PhotogrammetrySession(input: inputFolder)
                self.session = session
                let request = PhotogrammetrySession.Request.modelFile(url: temporaryDestination, detail: self.quality.detail)
                try session.process(requests: [request])

                for try await output in session.outputs {
                    self.handle(output, destination: destination)
                    if case .processingComplete = output {
                        self.finishSuccessfully(at: destination, temporaryURL: temporaryDestination)
                        return
                    }
                    if case .processingCancelled = output {
                        self.finishCancelled()
                        return
                    }
                }
            } catch {
                self.finishWithError(error)
            }
        }
    }

    private func startIntelReconstruction(inputFolder: URL, destination: URL, temporaryDestination: URL) {
        status = "Starting Intel reconstruction engine"
        stage = "Preparing"
        let processor = IntelPhotogrammetryProcessor()
        intelProcessor = processor

        processingTask = Task { [weak self, processor] in
            let quality = self?.quality ?? .full
            do {
                try await Task.detached(priority: .userInitiated) {
                    try processor.reconstruct(
                        inputFolder: inputFolder,
                        outputURL: temporaryDestination,
                        quality: quality
                    ) { [weak self] update in
                        Task { @MainActor in
                            self?.applyIntelUpdate(update)
                        }
                    }
                }.value

                guard let self else { return }
                if processor.wasCancelled {
                    self.finishCancelled()
                } else {
                    self.finishSuccessfully(at: destination, temporaryURL: temporaryDestination)
                }
            } catch {
                guard let self else { return }
                if processor.wasCancelled || error is CancellationError {
                    self.finishCancelled()
                } else {
                    self.finishWithError(error)
                }
            }
        }
    }

    func cancel() {
        status = "Cancelling…"
        stage = "Cancelling"
        session?.cancel()
        intelProcessor?.cancel()
        processingTask?.cancel()
    }

    func revealOutput() {
        guard let completedOutput else { return }
        NSWorkspace.shared.activateFileViewerSelecting([completedOutput])
    }

    private func handle(_ output: PhotogrammetrySession.Output, destination: URL) {
        switch output {
        case .requestProgress(_, let fraction):
            progress = fraction
            status = "Generating \(destination.lastPathComponent)"
        case .requestProgressInfo(_, let info):
            if let processingStage = info.processingStage {
                stage = localizedStage(String(describing: processingStage))
            }
            if let estimate = info.estimatedRemainingTime, estimate.isFinite, estimate >= 0 {
                remainingText = format(seconds: estimate)
            }
        case .requestError(_, let error):
            errorMessage = error.localizedDescription
            status = "The request encountered an error"
        case .invalidSample(let id, let reason):
            errorMessage = "Invalid photo skipped (\(id)): \(reason)"
        case .skippedSample(let id):
            errorMessage = "A photo was skipped by RealityKit (id \(id))."
        case .automaticDownsampling:
            status = "Automatically reducing resolution"
        default:
            break
        }
    }

    private func applyIntelUpdate(_ update: IntelPhotogrammetryProcessor.Update) {
        progress = update.progress
        status = update.status
        stage = update.stage
        remainingText = update.estimatedRemainingTime
    }

    private func finishSuccessfully(at url: URL, temporaryURL: URL) {
        guard FileManager.default.fileExists(atPath: temporaryURL.path) else {
            finishWithError(NSError(domain: "Drone3D", code: 2, userInfo: [NSLocalizedDescriptionKey: "RealityKit finished without creating the USDZ file."]))
            return
        }
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                _ = try FileManager.default.replaceItemAt(url, withItemAt: temporaryURL)
            } else {
                try FileManager.default.moveItem(at: temporaryURL, to: url)
            }
        } catch {
            finishWithError(error)
            return
        }
        progress = 1
        status = "USDZ generated successfully"
        stage = "Completed"
        remainingText = nil
        completedOutput = url
        endProcessing()
    }

    private func finishCancelled() {
        status = "Processing cancelled"
        stage = "Cancelled"
        remainingText = nil
        endProcessing()
    }

    private func finishWithError(_ error: Error) {
        status = "Processing stopped"
        stage = "Error"
        errorMessage = error.localizedDescription
        remainingText = nil
        endProcessing()
    }

    private func endProcessing() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        session = nil
        intelProcessor = nil
        processingTask = nil
        if let temporaryOutputURL, FileManager.default.fileExists(atPath: temporaryOutputURL.path) {
            try? FileManager.default.removeItem(at: temporaryOutputURL)
        }
        temporaryOutputURL = nil
    }

    private func startTimer() {
        updateElapsed()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateElapsed() }
        }
    }

    private func updateElapsed() {
        guard let startedAt else { return }
        elapsedText = format(seconds: Date().timeIntervalSince(startedAt))
    }

    private func countCompatiblePhotos(in folder: URL) -> Int {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }
        return files.reduce(into: 0) { count, url in
            guard supportedExtensions.contains(url.pathExtension.lowercased()),
                  (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { return }
            count += 1
        }
    }

    private func defaultOutputURL(for folder: URL) -> URL {
        let safeName = folder.lastPathComponent
            .replacingOccurrences(of: " ", with: "_")
        return folder.appendingPathComponent("\(safeName)_3D").appendingPathExtension("usdz")
    }

    private func temporaryURL(near destination: URL) -> URL {
        let filename = ".drone3d-\(UUID().uuidString).usdz"
        return destination.deletingLastPathComponent().appendingPathComponent(filename)
    }

    private func confirmReplacementIfNeeded(at url: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else { return true }
        let alert = NSAlert()
        alert.messageText = "Replace existing file?"
        alert.informativeText = "\(url.lastPathComponent) already exists and will be replaced after processing finishes."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Replace")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func showAlert(_ message: String) {
        alertMessage = message
        showingAlert = true
    }

    private func localizedStage(_ value: String) -> String {
        switch value.lowercased() {
        case let text where text.contains("preprocessing"): "Pre-processing"
        case let text where text.contains("feature"): "Analyzing features"
        case let text where text.contains("reconstruct"): "Reconstructing scene"
        case let text where text.contains("mesh"): "Generating mesh"
        case let text where text.contains("texture"): "Generating textures"
        case let text where text.contains("post"): "Finalizing"
        default: value
        }
    }

    private func format(seconds: TimeInterval) -> String {
        let wholeSeconds = max(0, Int(seconds.rounded()))
        return String(format: "%02d:%02d:%02d", wholeSeconds / 3600, (wholeSeconds % 3600) / 60, wholeSeconds % 60)
    }
}

/// CPU photogrammetry fallback bundled only with the Intel distribution.
/// It uses COLMAP for camera registration and OpenMVS for dense geometry and texture baking.
private final class IntelPhotogrammetryProcessor: @unchecked Sendable {
    struct Update: Sendable {
        let progress: Double
        let status: String
        let stage: String
        let estimatedRemainingTime: String?
    }

    private let lock = NSLock()
    private var activeProcess: Process?
    private var cancelled = false

    var wasCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    func cancel() {
        lock.lock()
        cancelled = true
        let process = activeProcess
        lock.unlock()
        process?.terminate()
    }

    func reconstruct(
        inputFolder: URL,
        outputURL: URL,
        quality: ReconstructionQuality,
        update: @escaping @Sendable (Update) -> Void
    ) throws {
        let engine = try engineDirectory()
        let workspace = FileManager.default.temporaryDirectory
            .appendingPathComponent("Drone3D-Intel-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: workspace) }

        let database = workspace.appendingPathComponent("database.db")
        let sparse = workspace.appendingPathComponent("sparse", isDirectory: true)
        let dense = workspace.appendingPathComponent("dense", isDirectory: true)
        let scene = workspace.appendingPathComponent("scene.mvs")
        let denseScene = workspace.appendingPathComponent("scene_dense.mvs")
        let meshScene = workspace.appendingPathComponent("scene_mesh.mvs")
        let refinedScene = workspace.appendingPathComponent("scene_mesh_refined.mvs")

        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: sparse, withIntermediateDirectories: true)

        try run(
            engine: engine,
            tool: "colmap",
            arguments: [
                "feature_extractor", "--database_path", database.path,
                "--image_path", inputFolder.path,
                "--SiftExtraction.use_gpu", "0"
            ],
            update: update,
            progress: 0.08,
            stage: "Image features",
            status: "Analyzing photo features"
        )
        try run(
            engine: engine,
            tool: "colmap",
            arguments: [
                "exhaustive_matcher", "--database_path", database.path,
                "--SiftMatching.use_gpu", "0"
            ],
            update: update,
            progress: 0.20,
            stage: "Photo matching",
            status: "Matching photographs"
        )
        try run(
            engine: engine,
            tool: "colmap",
            arguments: [
                "mapper", "--database_path", database.path,
                "--image_path", inputFolder.path,
                "--output_path", sparse.path
            ],
            update: update,
            progress: 0.34,
            stage: "Camera alignment",
            status: "Aligning camera positions"
        )

        let sparseModel = try firstDirectory(in: sparse)
        try run(
            engine: engine,
            tool: "colmap",
            arguments: [
                "image_undistorter", "--image_path", inputFolder.path,
                "--input_path", sparseModel.path,
                "--output_path", dense.path,
                "--output_type", "COLMAP",
                "--max_image_size", String(quality.intelImageSize)
            ],
            update: update,
            progress: 0.45,
            stage: "Image preparation",
            status: "Preparing undistorted images"
        )
        try run(
            engine: engine,
            tool: "InterfaceCOLMAP",
            arguments: ["-i", dense.path, "-o", scene.path],
            update: update,
            progress: 0.52,
            stage: "Scene import",
            status: "Preparing the Intel reconstruction"
        )
        try run(
            engine: engine,
            tool: "DensifyPointCloud",
            arguments: ["-i", scene.path, "-o", denseScene.path],
            update: update,
            progress: 0.68,
            stage: "Dense reconstruction",
            status: "Building dense geometry"
        )
        try run(
            engine: engine,
            tool: "ReconstructMesh",
            arguments: ["-i", denseScene.path, "-o", meshScene.path],
            update: update,
            progress: 0.80,
            stage: "Mesh generation",
            status: "Generating the 3D mesh"
        )
        try run(
            engine: engine,
            tool: "RefineMesh",
            arguments: ["-i", meshScene.path, "-o", refinedScene.path],
            update: update,
            progress: 0.88,
            stage: "Mesh refinement",
            status: "Refining the 3D mesh"
        )
        try run(
            engine: engine,
            tool: "TextureMesh",
            arguments: ["-i", refinedScene.path, "--export-type", "obj"],
            update: update,
            progress: 0.94,
            stage: "Texture generation",
            status: "Baking photo textures"
        )

        let texturedOBJ = try newestOBJ(in: workspace)
        update(Update(progress: 0.97, status: "Converting textured model to USDZ", stage: "USDZ export", estimatedRemainingTime: nil))
        let asset = MDLAsset(url: texturedOBJ)
        try asset.export(to: outputURL)
        guard FileManager.default.fileExists(atPath: outputURL.path) else {
            throw ProcessorError.outputNotCreated
        }
    }

    private func engineDirectory() throws -> URL {
        guard let engine = Bundle.main.resourceURL?.appendingPathComponent("IntelEngine/bin", isDirectory: true),
              FileManager.default.isExecutableFile(atPath: engine.appendingPathComponent("colmap").path),
              FileManager.default.isExecutableFile(atPath: engine.appendingPathComponent("InterfaceCOLMAP").path),
              FileManager.default.isExecutableFile(atPath: engine.appendingPathComponent("DensifyPointCloud").path),
              FileManager.default.isExecutableFile(atPath: engine.appendingPathComponent("ReconstructMesh").path),
              FileManager.default.isExecutableFile(atPath: engine.appendingPathComponent("RefineMesh").path),
              FileManager.default.isExecutableFile(atPath: engine.appendingPathComponent("TextureMesh").path)
        else {
            throw ProcessorError.engineMissing
        }
        return engine
    }

    private func run(
        engine: URL,
        tool: String,
        arguments: [String],
        update: @escaping @Sendable (Update) -> Void,
        progress: Double,
        stage: String,
        status: String
    ) throws {
        try checkCancellation()
        update(Update(progress: progress, status: status, stage: stage, estimatedRemainingTime: nil))

        let executable = engine.appendingPathComponent(tool)
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.currentDirectoryURL = engine
        var environment = ProcessInfo.processInfo.environment
        let libraryDirectory = engine.deletingLastPathComponent().appendingPathComponent("lib").path
        environment["DYLD_LIBRARY_PATH"] = [libraryDirectory, environment["DYLD_LIBRARY_PATH"]].compactMap { $0 }.joined(separator: ":")
        process.environment = environment

        let logURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Drone3D-Intel-\(UUID().uuidString).log")
        FileManager.default.createFile(atPath: logURL.path, contents: nil)
        let logFile = try FileHandle(forWritingTo: logURL)
        process.standardOutput = logFile
        process.standardError = logFile
        lock.lock()
        activeProcess = process
        lock.unlock()
        defer {
            lock.lock()
            activeProcess = nil
            lock.unlock()
            try? logFile.close()
        }

        do {
            try process.run()
        } catch {
            throw ProcessorError.couldNotLaunch(tool)
        }
        process.waitUntilExit()
        if wasCancelled { throw CancellationError() }
        guard process.terminationStatus == 0 else {
            try? logFile.close()
            let data = (try? Data(contentsOf: logURL)) ?? Data()
            try? FileManager.default.removeItem(at: logURL)
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ProcessorError.commandFailed(tool, message.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        try? FileManager.default.removeItem(at: logURL)
    }

    private func checkCancellation() throws {
        if wasCancelled { throw CancellationError() }
    }

    private func firstDirectory(in url: URL) throws -> URL {
        let entries = try FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        if let directory = entries.first(where: { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }) {
            return directory
        }
        throw ProcessorError.noSparseModel
    }

    private func newestOBJ(in directory: URL) throws -> URL {
        let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        let models = (enumerator?.allObjects as? [URL] ?? []).filter { $0.pathExtension.lowercased() == "obj" }
        guard let model = models.max(by: {
            (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast <
            (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
        }) else {
            throw ProcessorError.noTexturedModel
        }
        return model
    }

    private enum ProcessorError: LocalizedError {
        case engineMissing
        case couldNotLaunch(String)
        case commandFailed(String, String)
        case noSparseModel
        case noTexturedModel
        case outputNotCreated

        var errorDescription: String? {
            switch self {
            case .engineMissing:
                "The Intel reconstruction engine is missing from this app build. Install the Intel distribution, not the Apple Silicon edition."
            case .couldNotLaunch(let tool):
                "Could not launch the Intel tool: \(tool)."
            case .commandFailed(let tool, let message):
                "\(tool) failed. \(message)"
            case .noSparseModel:
                "The Intel engine could not align enough photographs to create a scene."
            case .noTexturedModel:
                "The Intel engine completed without creating a textured mesh."
            case .outputNotCreated:
                "The USDZ export did not create an output file."
            }
        }
    }
}
