# Native Assets Workflow

Rust-based code assets are compiled through the `packages/delta_ffi/hook/build.dart` hook using `native_toolchain_rust`. Follow the steps below after setting up a new machine or updating toolchains:

1. Enable Flutter's native-assets experiment once per checkout:
   ```
   flutter config --enable-native-assets
   ```
2. Allow the tooling to install the expected Android NDK and Rust targets:
   ```
   dart pub global activate native_doctor
   dart pub global run native_doctor
   ```
   The manifest at `packages/delta_ffi/native_manifest.yaml` pins NDK `28.2.13676358` and Rust stable `>=1.77.2`, so running `native_doctor` keeps them in sync.
3. After pulling updates, rebuild assets with your normal Flutter command (for example `flutter run --flavor dev`). The hook invokes `RustBuilder`, so no extra environment configuration is required.
