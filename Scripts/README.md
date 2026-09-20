# Distribution builds

Drone3D now targets Apple Silicon (M1 and later), using RealityKit Object Capture.

```sh
./Scripts/package-app.sh arm64 /absolute/path/to/new-output-folder
```

The output is Drone3D-AppleSilicon.app. The script resolves the binary location using SwiftPM, compiles the icon, and applies an ad-hoc signature for local testing. Developer ID signing and notarization are still required for public distribution.

The legacy build-intel-engine.sh is retained as historical source only; the current app and packaging script do not use or bundle that engine.
