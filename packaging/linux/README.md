# Linux Deployment

Axichat's Linux release flow splits into two lanes:

- `.tar.gz`, `.deb`, and `.AppImage`: build on Linux with Shorebird by default
  via `./tool/release_linux.sh`
- Flathub: build from source with Flatpak, without Shorebird, via
  `./tool/prepare_flathub_submission.sh`

Why the split exists:

- Shorebird can build and patch Linux desktop releases, so the direct
  `.tar.gz`, `.deb`, and `.AppImage` artifacts should keep using
  `shorebird release linux` wherever possible.
- Flathub does not allow authenticated networked release tooling during the
  build and requires all build inputs to be reviewer-visible sources in the
  manifest. For that path Axichat uses `flutter build linux` with
  `--dart-define=ENABLE_SHOREBIRD=false`.

## `.tar.gz`, `.deb`, and `.AppImage`

Run on a Linux machine with Flutter Linux desktop tooling, Shorebird, and
`dpkg-deb` installed, plus `linuxdeploy` for the AppImage step:

```bash
./tool/release_linux.sh --version v0.7.0
```

Artifacts land in `dist/`:

- `axichat-linux.tar.gz`
- `axichat-linux-amd64.deb`
- `axichat-x86_64.AppImage`
- matching `.sha256` files

Useful overrides:

- `--builder flutter` if you explicitly need a non-Shorebird build
- `--package-only` to regenerate `.tar.gz`, `.deb`, and `.AppImage` from an
  existing `build/linux/x64/release/bundle` without creating a new Shorebird
  release
- `--bundle-dir <dir>` if the bundle you want to package lives somewhere else
- `--email-public-token <token>` or `EMAIL_PUBLIC_TOKEN=...`
- `--output-dir <dir>`

Repackaging example:

```bash
./tool/release_linux.sh --package-only --version v0.7.0
```

AppImage notes:

- AppImage is the right format if you want "download one file and run it" on
  many Linux distributions.
- If `linuxdeploy` itself is installed as an AppImage, the packaging script
  runs it in extract-and-run mode automatically, so FUSE is not required.
- Keep the raw `.tar.gz` only as a secondary bundle artifact; it is not as
  portable as an AppImage.
- Do not wrap an `.AppImage` inside another archive.

## Flathub

Run on Linux after committing the release state you want Flathub to build:

```bash
./tool/prepare_flathub_submission.sh \
  --git-ref v0.7.0 \
  --inputs-url https://github.com/axichat/axichat/releases/download/v0.7.0/axichat-flatpak-inputs.tar.gz
```

For Linux-only fixes that should not reuse or mint a cross-platform tag, render
the app source as branch+commit instead:

```bash
./tool/prepare_flathub_submission.sh \
  --git-ref 0123456789abcdef0123456789abcdef01234567 \
  --git-branch master \
  --inputs-url https://example.com/axichat-flatpak-inputs.tar.gz
```

What the script does:

- renders the app source as a pinned GitHub git source for the chosen tag/ref
- stages and archives the extra Flatpak-only inputs under `build/flatpak`
- renders `build/flathub-submission/im.axi.axichat.yml`
- copies `build/flathub-submission/flathub.json`

Generated local artifacts:

- `build/flathub-sources/axichat-flatpak-inputs.tar.gz`

Submission notes:

- The manifest pins the app source to `https://github.com/axichat/axichat.git`
  with `tag: v0.7.0` plus the resolved commit hash.
- If `--git-branch` is provided, the manifest uses `branch: <branch>` plus the
  resolved commit from `--git-ref`. This is useful when Flathub needs a Linux-
  only fix that should not trigger the cross-platform tag release workflows.
- Upload the generated `flatpak-inputs` archive to a stable public URL, then
  rerun the script with the final `--inputs-url`.
- A practical pattern is:
  1. run `./tool/prepare_flathub_submission.sh --git-ref v0.7.0`
  2. upload `build/flathub-sources/axichat-flatpak-inputs.tar.gz` to the GitHub
     Release for `v0.7.0`
  3. rerun `./tool/prepare_flathub_submission.sh --git-ref v0.7.0 --inputs-url https://github.com/axichat/axichat/releases/download/v0.7.0/axichat-flatpak-inputs.tar.gz`
- The generated `flathub.json` limits the app to `x86_64`, which matches the
  current Linux desktop / PDFium packaging.
- For local verification before submission, run `./tool/build_flatpak_source.sh`
  or `flatpak-builder --force-clean build-dir build/flathub-submission/im.axi.axichat.yml`
  after replacing placeholder URLs with reachable ones.

What `axichat-flatpak-inputs.tar.gz` is:

- not a prebuilt app bundle
- a source/dependency snapshot for the Flathub builder
- contains the staged pub cache, pinned Dart git dependencies, vendored Rust
  crates, and generated override/config files needed for an offline Flatpak
  source build
