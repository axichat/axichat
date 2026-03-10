# Flatpak / Flathub

This directory contains the Flatpak metadata and manifest for Axichat's Linux
desktop bundle.

Files:

- `im.axi.axichat.desktop`: desktop file named the way Flathub expects.
- `im.axi.axichat.metainfo.xml`: AppStream metadata sourced from the existing
  repository descriptions and screenshots.
- `im.axi.axichat.yml`: Flatpak manifest that packages the locally built Linux
  bundle from `build/linux/x64/release/bundle`.

Local build flow:

1. Run `flutter build linux --release`.
2. Run `flatpak-builder --force-clean build-dir packaging/flatpak/im.axi.axichat.yml`.
3. Optionally run `flatpak-builder --run build-dir packaging/flatpak/im.axi.axichat.yml axichat`.

Before submitting to Flathub:

1. Confirm that the app ID `im.axi.axichat` matches a domain you control. If it
   does not, change the app ID across desktop packaging before publishing.
2. Decide whether Flathub will accept the bundle-based build flow or whether the
   manifest must be converted into a full source build for review.
3. If Flathub requires a source build, replace the local bundle source in
   `im.axi.axichat.yml` with a pinned source-build pipeline before submission.
