# Distribution builds

`package-app.sh` produces separate application bundles:

- `Drone3D-AppleSilicon.app` for Apple silicon. It uses Apple's RealityKit Object Capture engine.
- `Drone3D-Intel.app` for Intel Macs. It uses the bundled CPU engine: COLMAP for camera registration and OpenMVS for dense reconstruction and texture baking.

## Build the Apple silicon app

```sh
./Scripts/package-app.sh arm64
```

## Build the Intel app

On an Intel Mac, build the engine first. The script installs the required Homebrew build tools (`pkgconf`, Autoconf, Automake, and Libtool) and then builds the engine:

```sh
./Scripts/build-intel-engine.sh /absolute/path/to/IntelEngine
```

The script uses vcpkg to build COLMAP and OpenMVS for `x86_64`, copies their executable tools, runtime libraries, and license materials, and creates this layout:

```text
IntelEngine/
  bin/
    colmap
    InterfaceCOLMAP
    DensifyPointCloud
    ReconstructMesh
    RefineMesh
    TextureMesh
  lib/
    …runtime libraries required by those tools…
```

Run the packager with that directory:

```sh
export DRONE3D_INTEL_ENGINE=/absolute/path/to/IntelEngine
./Scripts/package-app.sh x86_64
```

The Intel engine must be tested on an Intel Mac before release. Its executables and dependent libraries need to be signed together with the app using a Developer ID certificate, then notarized by Apple before public distribution.

## License

Drone 3D is AGPL-3.0-or-later. The Intel edition bundles OpenMVS, which is also AGPL-3.0. Keep the bundled license materials and source availability when distributing the Intel app.
