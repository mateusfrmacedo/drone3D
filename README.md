# Drone 3D

Native macOS photogrammetry app for Apple Silicon (M1 and later). Turns original photos or drone video into a textured USDZ using RealityKit Object Capture.

## Quality

Reference (replacing Maximum) is the default profile. Its benchmark is a measured reference USDZ with 1,105,234 triangles and two 8192 × 8192 color textures. It requests custom reconstruction with:
- PNG textures without additional lossy compression.
- Texture dimensions up to 16384 × 16384 on macOS 15+, or 8192 × 8192 on macOS 14.
- Up to 2,000,000 polygons, leaving headroom above the reference mesh.
- Diffuse color only, like the reference; no additional normal, roughness, displacement or ambient occlusion maps.
- High feature sensitivity.

These are requested limits, not guaranteed output sizes. The API does not let us force exactly two 8K atlases. A 16K limit is not equivalent to two well-utilized 8K maps; on macOS 14 the custom cap remains 8K. RealityKit chooses the actual output according to the input and available resources. Larger maps cannot recover missing image detail. Reference uses substantial memory and disk space. Preview, Reduced and Medium remain available.

Raw is a separate, opt-in native RealityKit preset for comparison: it preserves high-detail geometry and can produce multiple diffuse color maps. It does not use the custom polygon/texture limits and is not evidence of which preset produced the reference. It can exceed practical memory budgets on a 16 GB Mac and produce models too heavy for AR. A confirmation is required before starting Raw.

After reconstruction the app reads actual PNG texture dimensions from the USDZ without decoding the textures. It displays the color dimensions and warns when the color pixel count is below the reference (not a visual-quality score). Skipped/invalid sample IDs and automatic input downsampling remain visible as warnings rather than fatal errors. Run Report exports requested settings, system memory/macOS, warnings and measured texture dimensions as JSON; it remains available after success, failure or cancellation. Geometry counts are not measured by this in-app report.

For a read-only geometry and texture comparison, with Python 3 and Apple's `usdcat` available:

```sh
python3 Scripts/inspect-usdz.py /path/to/result.usdz /path/to/antenna2.usdz
```

Validation includes unit tests and optional inspection of local reference files. A new end-to-end church reconstruction and visual comparison are still required before claiming improved output quality. The input photographs and reference models are never modified by these checks.

Original photographs are passed directly to RealityKit without resizing or recompression. Before importing a video, choose a limit of 240, 480 (default), or 720 frames. Reimport the video after changing this limit. Higher limits use more memory, disk space and processing time; short videos may provide fewer frames. Selection uses sharpness and exposure across the entire capture, saves full-size decoded frames as lossless PNG, and preserves capture order. PNG avoids another compression generation; it does not undo the original video's compression. Empty sampling windows are skipped.

Photo Check reports readability, resolution, low detail and exposure issues. It does not validate overlap or complete scene coverage and never removes source photographs automatically.

Preserve terrain disables object masking to attempt to preserve the real surroundings, ignores embedded capture bounding boxes on macOS 15+, and uses sequential ordering for ordered drone captures. Off selects object isolation and unordered matching. Neither setting guarantees ground reconstruction or clean isolation. High feature sensitivity applies in either case. For the best textures use original, sharp still photographs with consistent lighting and substantial overlap, including oblique views of walls, corners and roofs.

## Requirements and use

### Optional terrain crop

Use **Crop terrain…** to open an existing USDZ, including a newly generated one. Orbit/zoom the preview and adjust the six box boundaries (width X, height Y, depth Z). Keep Bottom below the ground to retain the real terrain. **Preview Crop** clips intersecting triangles and interpolates normals and UVs; **Save New USDZ…** exports a separate file. Existing files, including the source, are never overwritten. Reset restores the full box. For isolated objects, skip this tool; reconstruction remains unchanged.

The box follows the imported model axes (no automatic building detection or box rotation). Cuts remain open: this does not invent missing ground, cap walls or make a watertight platform. The tool supports static triangulated photogrammetry meshes with normals and UVs, retaining their materials. SceneKit re-exports the materials/textures; custom shaders, animation and unsupported geometry are outside its scope. Export may increase vertex/triangle counts because boundary faces are split and double-sided materials may be expanded. No texture sharpening or upscaling is performed. Preview/export run off the UI thread and may require substantial memory for Raw assets.

Apple Silicon Mac with Object Capture support and macOS 14 or later. Choose the input folder or import a video, choose the USDZ destination and quality, then start reconstruction. Intel/CUDA/OpenMVS are no longer part of the app's reconstruction path.

```sh
swift build
swift test
swift run Drone3D
./Scripts/package-app.sh arm64 /absolute/path/to/new-output-folder
```

The packaging script refuses to overwrite an existing app. Historical Intel build scripts and third-party notices remain for reference only. Source photos and generated USDZ files are excluded from version control.

Licensed under [AGPL-3.0-or-later](LICENSE).
