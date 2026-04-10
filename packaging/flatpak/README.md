# Flatpak / Flathub

This directory contains Axichat's Flatpak metadata, the current local
bundle-based manifest, and a newer source-build manifest for Flathub work.

Files:

- `im.axi.axichat.desktop`: desktop file named the way Flathub expects.
- `flathub.json`: Flathub submission config; currently limits the app to
  `x86_64`.
- `im.axi.axichat.metainfo.xml`: AppStream metadata.
- `im.axi.axichat.flathub.yml.in`: template used to render a submission-ready
  Flathub manifest with the pinned Axichat GitHub tag/commit plus the uploaded
  `flatpak-inputs` archive URL and SHA256.
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
- `../../tool/prepare_flathub_submission.sh`: archives the selected git ref,
  archives the staged `flatpak-inputs`, and renders
  `build/flathub-submission/im.axi.axichat.yml`.

Local maintainer flows:

1. Build the Linux release bundle with Shorebird by default:
   `./tool/release_linux.sh --version v0.6.1 [-- <extra flutter args>]`
2. Build the current bundle-based Flatpak:
   `flatpak-builder --force-clean build-dir packaging/flatpak/im.axi.axichat.yml`
3. Optionally run it:
   `flatpak-builder --run build-dir packaging/flatpak/im.axi.axichat.yml axichat`
4. To exercise the source-build path, run:
   `./tool/build_flatpak_source.sh`
5. To render Flathub submission files, run:
   `./tool/prepare_flathub_submission.sh --git-ref v0.6.1 [--inputs-url ...]`
6. To package only the remaining local staged inputs for hosting, run:
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

1. `im.axi.axichat.source.yml` stays useful for local source-build testing, but
   it still depends on local `type: dir` sources and therefore is not directly
   suitable for submission to Flathub.
2. The source-build helper disables Shorebird with
   `--dart-define=ENABLE_SHOREBIRD=false`, because the Flathub build path uses
   `flutter build linux` rather than an authenticated `shorebird release linux`.
3. The manifest now pins the external Flutter/SQLCipher/PDFium sources, and
   the source-build helper rewrites the plugin CMake files to consume the
   manifest-fetched SQLCipher/PDFium blobs locally instead of downloading them
   during the build.
4. `./tool/prepare_flathub_submission.sh` now renders
   `build/flathub-submission/im.axi.axichat.yml` plus `flathub.json` using
   either the pinned Axichat GitHub tag/commit or a branch/commit pair, plus
   the uploaded `flatpak-inputs` archive URL and SHA256 value. Upload the
   generated `flatpak-inputs` archive somewhere stable, then rerun the script
   with the final public URL.
5. Before submitting to Flathub, confirm that the app ID `im.axi.axichat`
   matches a domain you control and that the public archive URLs are
   reviewer-visible and stable.
6. The `flatpak-inputs` archive is not a prebuilt app. It is the offline
   dependency snapshot consumed by `packaging/flatpak/build-source.sh` so
   Flathub can rebuild Axichat from source without live pub/git/cargo fetches.
