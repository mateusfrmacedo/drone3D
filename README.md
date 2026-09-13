# Drone 3D

Native macOS app that turns a folder of photographs into a textured USDZ 3D model using `RealityKit.PhotogrammetrySession`.

Licensed under [AGPL-3.0-or-later](LICENSE).

## Features

- Choose the source photo folder and USDZ save location.
- Supports compatible JPEG, PNG, HEIC/HEIF, and TIFF images.
- Select Preview, Reduced, Medium, or Full reconstruction quality.
- Shows processing progress, the current stage, elapsed time, estimated remaining time, and errors.
- Keeps generated textures from the input photographs.

## Requirements

- macOS 14 Sonoma or later.
- Sufficient free storage and memory for the selected image set. Full quality can require substantial processing time and resources.

## Supported Macs

- **Apple silicon edition:** uses RealityKit Object Capture on Macs that report support for `PhotogrammetrySession`.
- **Intel edition:** uses the bundled CPU photogrammetry engine (COLMAP and OpenMVS). This edition is slower, but creates a textured mesh and exports it as USDZ without relying on RealityKit Object Capture.

Both editions use the same interface and support the same input photo formats.

## Run from Xcode

1. Open `Package.swift` in Xcode.
2. Choose the **Drone3D** scheme.
3. Click Run.

## Build from Terminal

```sh
swift build
swift run Drone3D
```

## Using the App

1. Select the folder containing the photographs.
2. Select where the resulting `.usdz` file should be saved.
3. Choose a reconstruction quality.
4. Click **Start** and wait for processing to finish.

For the best results, use sharp, evenly lit photographs with clear overlap between consecutive images.

## Notes

The source photographs and generated USDZ files are intentionally excluded from this repository.

## Distribution builds

The packaging script creates separate Apple silicon and Intel app bundles. See [Scripts/README.md](Scripts/README.md) for the exact commands and Intel engine layout.

## Third-party software

The Intel edition uses COLMAP and OpenMVS. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for licenses and attribution.

## Screenshot

<img width="752" height="714" alt="Drone 3D app window" src="https://github.com/user-attachments/assets/531b62fe-0a4b-4036-85f0-e56005f40976" />

<img width="1350" height="870" alt="Captura de Tela 2026-09-13 às 17 42 56" src="https://github.com/user-attachments/assets/76167e9a-74d7-4040-a1f8-fa5ca91686f6" />



