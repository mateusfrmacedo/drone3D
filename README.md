# Drone 3D

Native macOS app that turns a folder of photographs into a textured USDZ 3D model using `RealityKit.PhotogrammetrySession`.

## Features

- Choose the source photo folder and USDZ save location.
- Supports compatible JPEG, PNG, HEIC/HEIF, and TIFF images.
- Select Preview, Reduced, Medium, or Full reconstruction quality.
- Shows processing progress, the current stage, elapsed time, estimated remaining time, and errors.
- Keeps generated textures from the input photographs.

## Requirements

- macOS 14 Sonoma or later.
- An Apple silicon Mac with support for RealityKit Object Capture.
- Sufficient free storage and memory for the selected image set. Full quality can require substantial processing time and resources.

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

## Screenshot

<img width="752" height="714" alt="Drone 3D app window" src="https://github.com/user-attachments/assets/531b62fe-0a4b-4036-85f0-e56005f40976" />
