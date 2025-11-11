Email‑Backed Chat for Flutter via Delta Chat Core (Rust) + Dart FFI (Build Hooks / Code Assets)

Goal: Add an email-backed transport to your existing Flutter chat app using the Delta Chat Core (Rust) engine through Dart FFI. Package and ship the native library with Dart build hooks & code assets, and auto‑provision a Chatmail account silently when users register a profile.

Implementation note: the entire email transport stack must live under `lib/src/email`, mirroring the existing `lib/src/xmpp` architecture but swapping moxxmpp dependencies for Delta Chat Core. Keep the layering (services, data, sync, blocs) consistent so the two transports stay interchangeable.

Current implementation snapshot (Nov 2025):
- `EmailService` provisions Chatmail credentials, starts the Delta transport, and mirrors Delta events into the shared Drift database so existing chat streams pick up email traffic.
- UI exposes `MessageTransport` toggles in both compose and chat views; selections persist per chat via the state store (`XmppStateStore`) and `ChatTransportCubit`.
- `ChatBloc`/`DraftCubit` route sends to SMTP when the email transport is active while suppressing typing markers and read receipts for those chats.
- Notifications are raised for incoming email messages unless the chat is muted; logout/burn flows tear down the Delta context and clear stored credentials.

Transport flow & lifecycle
--------------------------
- `EmailService.messageStreamForChat`, `chatsStream`, and `draftsStream` mirror Drift watchers so Bloc consumers can stay transport-agnostic.
- Each chat’s preferred transport is stored in the Hive-backed state store; the chats list surfaces the active transport label alongside unread counts.
- Lifecycle events mirror XMPP’s CSI handling—`AuthenticationCubit` now calls `EmailService.setClientState`, which proxies to `start`/`stop` on the Delta transport so background sync behaviour stays aligned.
- Encryption/verification affordances are hidden for email chats (encryption is being removed entirely in a follow-up).

Build & tooling notes
---------------------
- Regenerate Freezed/Drift outputs after storage changes with:
  ```
  dart run build_runner build --delete-conflicting-outputs
  ```
- Native Delta binaries rely on the native-assets pipeline; ensure the Flutter toolchain has native assets enabled (dev/beta channel or `flutter config --enable-native-assets`) before running `flutter test` on CI.
- Unit tests for transport behaviour live in `test/email/service/email_service_test.dart` and `test/storage/models/chat_models_test.dart`.

Manual QA checklist
-------------------
1. Sign up or log in to create a fresh profile; verify Chatmail credentials are provisioned silently (no prompts).
2. Compose a new message, toggle the transport to Email, and send to an external address—confirm the message arrives and the chat badge shows “Email”.
3. Switch the in-chat transport back to XMPP, send, then reopen the chat to ensure the persisted preference loads correctly.
4. Background the app; after a minute send an email reply from the remote party and verify notifications still fire.
5. Re-open the app and confirm the Delta inbox resyncs (no duplicate messages, unread counts accurate).

Risks & follow-up
-----------------
- Native assets remain gated on enabling the Flutter experimental flag; track Flutter stable adoption to unblock CI for widget tests.
- UI clean-up for encryption toggles is partial—full removal follows once OMEMO code paths are excised.
- Mixed transport chats need broader end-to-end coverage; expand integration smoke tests once native assets are available.

Why this approach

Delta Chat Core exposes a stable C API we can bind to from Dart. It handles IMAP/SMTP, Autocrypt, groups, attachments, and an event system.
c.delta.chat
+2
c.delta.chat
+2

Build hooks + code assets (formerly “native assets”) let Dart/Flutter build and bundle native libraries portably; lookup is handled by annotations like @Native and DefaultAsset.
Dart
+2
Dart
+2

Chatmail relays allow “first‑login‑creates‑account” provisioning for frictionless onboarding (e.g., nine.testrun.org) so you can make an account behind the scenes.
Delta.Chat
+1

Table of contents

Scope & success criteria

Architecture overview

Repo layout & packages

Toolchain & environment

Native build: hooks + code assets

FFI bindings (ffigen)

Safe Dart wrappers + event isolate

Data model mapping & DB migrations

Transport adapter integration

Silent Chatmail provisioning flow

Backgrounding & notifications

Security & secrets

Testing strategy

CI/CD & release

Rollout plan & milestones

Risk register / watchlist

Appendix: reference snippets

1) Scope & success criteria

In scope

Keep current Flutter UI/domain. Add EmailTransport implemented atop Delta Core via FFI.

Mirror Delta Core data into your existing DB (idempotent upserts).

On user profile creation, silently create a Chatmail account and start syncing.

Basic feature set: sign‑in, send/receive text, attachments, groups, delivery/read updates.

Done when

A new user can create a chat profile → Chatmail is provisioned silently → messages send/receive in your existing UI → state persists across restarts → basic background fetch works per‑OS constraints.

2) Architecture overview
