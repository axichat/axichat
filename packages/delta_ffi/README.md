# delta_ffi

FFI bindings around the [Delta Chat Core](https://delta.chat) cdylib for Axichat.

## Build workflow

1. Install a Rust toolchain with every target you plan to build. For macOS desktop, Flutter may request both Apple targets, so install `aarch64-apple-darwin` and `x86_64-apple-darwin`. For Windows desktop use the MSVC toolchain and target, for example `rustup default stable-x86_64-pc-windows-msvc` and `rustup target add x86_64-pc-windows-msvc`.
2. From the repo root run `dart run hooks build delta_ffi` or `flutter pub run hooks build delta_ffi` so the hook compiles `rust/` for the active target and registers the `libdeltachat_wrap` code asset.
3. Flutter/Dart consumers import `package:delta_ffi/delta_safe.dart`; the `@DefaultAsset` annotation handles loading the native library.

## Regenerating bindings

```
cd packages/delta_ffi
flutter pub run ffigen --config ffigen.yaml
```

The command converts `headers/deltachat.h` into `lib/src/bindings.dart`. Keep the header in sync with the upstream `deltachat-ffi` version.

## Troubleshooting

- **Missing toolchains**: ensure the Rust stable toolchain plus the right target exist. On Windows, make sure `cargo.exe` is on `PATH` or in `%USERPROFILE%\.cargo\bin`.
- **macOS desktop builds on Apple Silicon**: Flutter may invoke the native asset hook for both `aarch64-apple-darwin` and `x86_64-apple-darwin`. Install both with `rustup target add aarch64-apple-darwin x86_64-apple-darwin`.
- **Code asset not found**: make sure `dart run hooks build` runs before invoking `flutter run`; the asset is emitted to `.dart_tool/native_assets/`.
- **ABI mismatch**: wipe `packages/delta_ffi/rust/target` when switching between macOS/Android builds so cargo rebuilds with the proper flags.
