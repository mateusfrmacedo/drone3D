# Drone 3D

Native macOS photogrammetry app for Apple Silicon (M1 and later). Turns original photos or drone video into a textured USDZ using RealityKit Object Capture.

## Quality

Maximum is the default profile. It requests custom reconstruction with:
- PNG textures without additional lossy compression.
- Texture dimensions up to 16384 × 16384 on macOS 15+, or 8192 × 8192 on macOS 14.
- Up to 1,000,000 polygons.
- Diffuse color, normal, roughness, displacement and ambient occlusion maps.
- High feature sensitivity.

These are requested limits, not guaranteed output sizes. RealityKit chooses the actual output according to the input and available resources. Larger maps cannot recover missing image detail. Maximum may take considerably longer and use substantial memory and disk space, especially on an 8 GB M1. Preview, Reduced and Medium remain available.

Original photographs are passed directly to RealityKit without resizing or recompression. Before importing a video, choose a limit of 240, 480 (default), or 720 frames. Reimport the video after changing this limit. Higher limits use more memory, disk space and processing time; short videos may provide fewer frames. Selection uses sharpness and exposure across the entire capture, saves full-size decoded frames as lossless PNG, and preserves capture order. PNG avoids another compression generation; it does not undo the original video's compression. Empty sampling windows are skipped.

Photo Check reports readability, resolution, low detail and exposure issues. It does not validate overlap or complete scene coverage and never removes source photographs automatically.

Keep Architectural mode enabled for photos in capture order. Disable it for mixed or unordered photo sets. High feature sensitivity applies in either case. For the best textures use original, sharp still photographs with consistent lighting and substantial overlap, including oblique views of walls, corners and roofs.

## Requirements and use

Apple Silicon Mac with Object Capture support and macOS 14 or later. Choose the input folder or import a video, choose the USDZ destination and quality, then start reconstruction. Intel/CUDA/OpenMVS are no longer part of the app's reconstruction path.

```sh
swift build
swift test
swift run Drone3D
./Scripts/package-app.sh arm64 /absolute/path/to/new-output-folder
```

The packaging script refuses to overwrite an existing app. Historical Intel build scripts and third-party notices remain for reference only. Source photos and generated USDZ files are excluded from version control.

Licensed under [AGPL-3.0-or-later](LICENSE).
