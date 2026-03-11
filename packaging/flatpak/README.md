# Flatpak / Flathub

This directory contains Axichat's Flatpak metadata, the current local
bundle-based manifest, and a newer source-build manifest for Flathub work.

Files:

- `im.axi.axichat.desktop`: desktop file named the way Flathub expects.
- `im.axi.axichat.metainfo.xml`: AppStream metadata.
- `im.axi.axichat.yml`: Flatpak manifest that packages the locally built Linux
  bundle from `build/linux/x64/release/bundle`.
- `im.axi.axichat.source.yml`: source-build manifest that uses locally prepared,
  staged Dart/git/Rust inputs from `build/flatpak`, plus manifest-pinned
  Flutter/SQLCipher/PDFium sources.
- `build-source.sh`: build helper run by the source-build manifest.
- `run-axichat.sh`: wrapper that preserves the Linux bundle layout inside `/app`.
- `../../tool/archive_flatpak_inputs.sh`: packages the remaining local
  `build/flatpak` inputs into one archive and prints the manifest snippet needed
  to replace the local `flatpak-inputs` `dir` source.

Local maintainer flows:

1. Build the Linux release bundle with Shorebird by default:
   `./tool/release_linux.sh -- --dart-define=...`
2. Build the current bundle-based Flatpak:
   `flatpak-builder --force-clean build-dir packaging/flatpak/im.axi.axichat.yml`
3. Optionally run it:
   `flatpak-builder --run build-dir packaging/flatpak/im.axi.axichat.yml axichat`
4. To exercise the source-build path, run:
   `./tool/build_flatpak_source.sh`
5. To package the remaining local staged inputs for hosting, run:
   `./tool/archive_flatpak_inputs.sh`

What `tool/prepare_flatpak_inputs.sh` does:

- copies the hosted pub cache and pinned git dependencies from the local
  pub cache, scoped to the hosted packages in `pubspec.lock`
- vendors Rust crates for `packages/delta_ffi/rust`
- leaves Flutter, SQLCipher, and PDFium to the manifest itself, where their
  URLs and checksums are reviewer-visible
- lets the source-build helper rewrite the plugin builds to consume those
  manifest-fetched SQLCipher/PDFium artifacts locally instead of downloading
  them again

Current Flathub status:

1. `im.axi.axichat.source.yml` is much closer to a Flathub submission manifest,
   because Flutter, SQLCipher, and PDFium are now explicit pinned sources in
   the manifest. It still depends on the local Axichat source tree and locally
   staged pub/git/Rust inputs under `build/flatpak`, which Flathub cannot fetch
   by itself yet.
2. The source-build helper disables Shorebird with
   `--dart-define=ENABLE_SHOREBIRD=false`, because the Flathub build path uses
   `flutter build linux` rather than an authenticated `shorebird release linux`.
3. The manifest now pins the external Flutter/SQLCipher/PDFium sources, and
   the source-build helper rewrites the plugin CMake files to consume the
   manifest-fetched SQLCipher/PDFium blobs locally instead of downloading them
   during the build.
4. Before submitting to Flathub, confirm that the app ID `im.axi.axichat`
   matches a domain you control and decide how the required Dart defines should
   be provided in a reviewer-visible source manifest.
5. After running `./tool/archive_flatpak_inputs.sh`, upload the generated
   archive somewhere stable and replace the local `type: dir`
   `flatpak-inputs` source with the printed `type: archive` snippet. Then
   replace the local Axichat source `dir` with a reviewer-visible git or
   archive source.
