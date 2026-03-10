# Axichat F-Droid Prep

This folder contains the Axichat F-Droid metadata template and release notes for maintainers.

## Current Build Contract

- Package id: `im.axi.axichat`
- Flavor: `production`
- Artifacts:
  - `build/app/outputs/flutter-apk/app-armeabi-v7a-production-release.apk`
  - `build/app/outputs/flutter-apk/app-arm64-v8a-production-release.apk`
  - `build/app/outputs/flutter-apk/app-x86_64-production-release.apk`
- F-Droid versionCode offsets:
  - armv7: `1000 + pubspec build code`
  - arm64: `2000 + pubspec build code`
  - x86_64: `4000 + pubspec build code`
- Email provisioning token define: `--dart-define=EMAIL_PUBLIC_TOKEN=axichatpublictoken`
- OTA updates: disabled for F-Droid via `--dart-define=ENABLE_SHOREBIRD=false`

## Release Checklist

1. Bump `version:` in `pubspec.yaml` (both name and build number).
2. Create and push the release tag (for example `v0.6.0`).
3. Update `fdroid/metadata/im.axi.axichat.yml`:
   - All `Builds[*].versionName`
   - All `Builds[*].versionCode` (`1000/2000/4000 + pubspec build code`)
   - All `Builds[*].commit`
   - `VercodeOperation`
   - `UpdateCheckData`
   - `CurrentVersion`
   - `CurrentVersionCode` (highest ABI-specific versionCode)
4. Run metadata consistency check:
   - `bash tool/check_fdroid_metadata_sync.sh`
5. Validate local F-Droid style Android build:
   - `flutter pub get`
   - `flutter pub run build_runner build --delete-conflicting-outputs`
   - `flutter build apk --flavor production --release --split-per-abi --dart-define=EMAIL_PUBLIC_TOKEN=axichatpublictoken --dart-define=ENABLE_SHOREBIRD=false`
6. Copy `fdroid/metadata/im.axi.axichat.yml` into the `fdroiddata` repo and open the merge request.

## Notes

- F-Droid signs release artifacts itself, so local release signing is optional.
- `android/app/build.gradle.kts` is configured to sign release only when a valid keystore is available.
