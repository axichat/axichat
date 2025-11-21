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

<p align="center"><strong>If you're proactive, if you're busy, you'll love Axichat both because of what it has and what it doesn't have.</strong></p>

<table>
  <tr>
    <th>What Axichat Offers</th>
    <th>What We Avoid</th>
  </tr>
  <tr>
    <td>
      <ul>
        <li>Chat and email unified, providing the best of both worlds</li>
        <li>World's best calendar, for free</li>
        <li>Encryption on device and in transit</li>
        <li>Unique, state-of-the-art UI</li>
        <li>Native performance on every platform</li>
        <li>1st party push notifications</li>
        <li>Offline functionality</li>
      </ul>
    </td>
    <td>
      <ul>
        <li>Proprietary dependencies</li>
        <li>Trackers</li>
        <li>Vendor lock-in</li>
        <li>Sharing/selling ANY data</li>
        <li>Centralized servers</li>
        <li>3rd party push notifications</li>
      </ul>
    </td>
  </tr>
</table>

---

## Why?

- **Tools matter** - Would you rather write a letter while sitting at your desk or while standing up outside? Using the right software makes the same difference. Axichat is a desk for your digital letters.
- **Time matters** - You can always make more money, but not more time. My calendar is designed to help you seize the day, and our chat-like email formatting helps you to avoid spending it reading what you don't want to, retyping information, opening the wrong emails, and spamming alt+tab.
- **Privacy matters** - “Arguing that you don't care about the right to privacy because you have nothing to hide is no different than saying you don't care about free speech because you have nothing to say.” ― Edward Snowden

## What?

### Best calendar in the world:
- Natural language parsing (without any AI) so you can just type in what, when, how long, how often, due by, and more any way you want and the calendar will automatically schedule it for you.
- If you don't know when it needs to get done, that's completely fine. Axichat will just put it in the unscheduled list so you can quickly and easily dump your stream-of-consciousness.
- If it has a deadline then Axichat will notify you when it is getting close.
- Excellent for planning your entire personal routine, featuring a built-in Eisenhower Matrix so you can put first things first.
- Intuitive UI/UX that works seamlessly on all your devices: drag+drop to reschedule, drag to resize, copy+paste, batch edit, and much more.
- Available in Guest Mode so you don't even need an account or internet to use it.
- Scheduling, task management, and reminders all in one place with natural language processing (no AI) for frictionless use.

### Best chat interface:
- Get our (Groupchats, Reactions, Delivery Receipts)
- (Gmail, Outlook, etc.)

## When?

- Built in 2025

## Where?

- Built in New Zealand

## Who?

- For people with a lot to get done
- For people who want to take control of their communications and time

## How?

- Written in Dart + Flutter
- With Moxxmpp
- With DeltaChat Core Rust
- With Drift

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
