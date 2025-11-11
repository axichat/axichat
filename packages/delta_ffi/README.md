# delta_ffi

FFI bindings around the [Delta Chat Core](https://delta.chat) cdylib for Axichat.

## Build workflow

1. Install a Rust toolchain with `rustup target add aarch64-linux-android x86_64-apple-darwin` etc.
2. From the repo root run `dart run hooks build delta_ffi` or `flutter pub run hooks build delta_ffi` so the hook compiles `rust/` for the active target and registers the `libdeltachat_wrap` code asset.
3. Flutter/Dart consumers import `package:delta_ffi/delta_safe.dart`; the `@DefaultAsset` annotation handles loading the native library.

## Regenerating bindings

```
cd packages/delta_ffi
flutter pub run ffigen --config ffigen.yaml
```

The command converts `headers/deltachat.h` into `lib/src/bindings.dart`. Keep the header in sync with the upstream `deltachat-ffi` version.

## Troubleshooting

- **Missing toolchains**: ensure `cargo` plus the right cross targets exist. The hook uses `native_toolchain_rust` to pick the matching triple.
- **Code asset not found**: make sure `dart run hooks build` runs before invoking `flutter run`; the asset is emitted to `.dart_tool/native_assets/`.
- **ABI mismatch**: wipe `packages/delta_ffi/rust/target` when switching between macOS/Android builds so cargo rebuilds with the proper flags.
