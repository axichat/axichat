<p align="center">
  <img src="assets/icons/generated/app_icon_android_foreground.png" width="120" alt="Axichat icon" />
</p>

<h1 align="center">Axichat</h1>

<p align="center"><strong>Privacy-first, cross-platform XMPP chat built with Flutter.</strong></p>

<p align="center">
  <a href="https://github.com/axichat/axichat/releases/latest/download/app-production-release.apk">
    <img alt="Download the Android APK" src="https://img.shields.io/badge/Download%20the%20APK-1BA5FF?style=for-the-badge&logo=android&logoColor=white" />
  </a>
  <a href="https://github.com/axichat/axichat/releases/latest/download/axichat-windows.zip">
    <img alt="Download the Windows build" src="https://img.shields.io/badge/Download%20Windows-4178D4?style=for-the-badge&logo=windows&logoColor=white" />
  </a>
  <a href="https://github.com/axichat/axichat/releases/latest/download/axichat-linux.tar.gz">
    <img alt="Download the Linux build" src="https://img.shields.io/badge/Download%20Linux-2CA5E0?style=for-the-badge&logo=linux&logoColor=white" />
  </a>
</p>

---

## Why Axichat?

- **Own your network** – Native with no Firebase, Google Play Services, or proprietary push relays.
- **First-party push + secure storage** – SQLCipher for the local database and Axichat-operated notification relays keep metadata private.
- **Truly cross-platform** – Android, Windows, and Linux builds share the same polished UI with upcoming macOS/iOS support.
- **Operations-ready UX** – Deadline-safe notifications, monitored overlays, and a consistent notification stack across the entire app.

## Highlights

### Rich multi-recipient fan-out
- Compose once, send to a curated fan-out list with live encryption badges per recipient.
- Automatically tracks delivery per recipient and displays cross-recipient banners ("Also sent to…").
- Subject tokens (ULIDs) keep replies correlated even when external clients respond.

### Unified messaging experience
- Direct/All toggles inside every conversation let you declutter the timeline when focusing on 1:1 chats.
- Message history, reactions, and participant data stay in sync through Drift migrations (`dart run build_runner build --delete-conflicting-outputs`).
- Custom render objects power fluid chat bubbles without post-frame hacks.

### Platform flavors
- `production` flavor ships to users (default in `flutter run`).
- `development` flavor uses `[DEV] Axichat` branding plus `.dev` app ID suffix, perfect for staging servers or Shorebird dev releases.

## Screenshots

<p float="left">
  <img src="/metadata/en-US/images/phoneScreenshots/1-unread_chats_white.png" width="49%"  alt="Chats page" />
  <img src="/metadata/en-US/images/phoneScreenshots/4-open_chat_dark.png" width="49%"  alt="Message page" />
</p>

## Downloading & Installing

1. Pick the platform button above (APK, Windows `.zip`, or Linux `.tar.gz`).
2. Verify the checksum/signature provided in the GitHub Release notes.
3. Install:
   - **Android** – Sideload the APK or deploy through your preferred device manager.
   - **Windows** – Extract the archive and run `Axichat.exe`.
   - **Linux** – Extract into a directory and launch `./axichat` (see `linux/axichat.desktop` for desktop entry guidance).

## Build From Source

```bash
flutter pub get
flutter pub run flutter_launcher_icons # optional: regenerate launcher art
dart run build_runner build --delete-conflicting-outputs
flutter build apk --flavor production --release
```

Use the flavor that matches your deployment (`--flavor development` for staging). After any model changes under `lib/src/storage/models`, re-run the `build_runner` command above.
