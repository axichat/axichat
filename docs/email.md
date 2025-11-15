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

Subject lines & fan-out metadata

Blocking email contacts & spam mitigation

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

The email stack mirrors the production XMPP layering so transport-specific logic never leaks into widgets or blocs. The core pieces are:

- `lib/src/email/transport/email_delta_transport.dart` wraps Delta Chat Core via `delta_ffi`. It is responsible for provisioning the native context, starting/stopping IO, translating Delta events into strongly typed Dart models, and persisting outbound metadata (`_recordOutgoing`) into Drift.
- `lib/src/email/sync/delta_event_consumer.dart` fans Delta events into the shared database. Incoming messages are converted to `Message` rows, attachments are normalized via `EmailMetadata`, and share metadata is hydrated before emitting items downstream.
- `lib/src/email/service/email_service.dart` owns provisioning, lifecycle, and the API surface (`sendMessage`, `fanOutSend`, `messageStreamForChat`, `shareContextForMessage`, etc.). It mirrors the mixin architecture used in `XmppService` so `ChatBloc`, `DraftCubit`, and widgets only need to switch transports via `MessageTransport`.
- Existing blocs consume `EmailService` through dependency injection (`lib/src/app.dart`) and stay transport-agnostic by reading from the same Drift watchers (`XmppDatabase`). Any email-only actions (e.g., fan-out retries, attachment optimization) live inside `ChatBloc` while UI-only pieces stay under `lib/src/chat/view`.

3) Subject lines & fan-out metadata
-----------------------------------

Email users expect a subject even when we route messages through Delta Core. Today the composer only exposes a body field, so every email arrives with Delta’s default subject. We close that gap by threading a subject string through the entire email send/resend stack:

1. **Composer state.** Add a dedicated subject controller to `ChatBloc`/`ChatState`. When `MessageTransport.email` is active, the composer renders a single-line input above `ChatCutoutComposer` (reuse the existing `RecipientChipsBar` padding so the layout remains stable). Add a new `ChatSubjectChanged` event that debounces updates and persists text in `state.emailSubject`.
2. **Drafts.** Extend `FanOutDraft`, the Drift `Drafts` table, and `DraftCubit.saveDraft` to persist both body and subject. Draft hydration already passes through `_rehydrateEmailDraft`; augment it to restore the subject controller and keep the subject associated with the `shareId`.
3. **Database schema.** Introduce a nullable `subject` column on `MessageShares` plus a convenience getter on `Message` so we can render subjects in the timeline header, recipient chips, and resend sheets. Regenerate Drift via `dart run build_runner build --delete-conflicting-outputs` after adding the column and the associated DAO helpers (`XmppDatabase.getMessageShareById`, `saveMessageShareSubject`).
4. **Sending.** Update `EmailService.sendMessage` and `fanOutSend` to accept an optional `subject`. When set, write it to the `MessageShares` row before dispatching to `_transport`. Because Delta Core does not expose raw email headers, we continue to rely on `ShareTokenCodec` for correlation but prepend the subject token plus the subject to the outgoing body so replies from legacy mail clients can be matched. Locally we strip the `[s:...]` tag (`ShareTokenCodec.stripToken`) so the UI only shows the user’s subject/body.
5. **Receiving.** `EmailService.shareContextForMessage` and `DeltaEventConsumer._applyShareMetadata` should populate the `ShareContext` with the stored subject. That lets `ChatBloc` render subject pills or banners for mixed fan-out threads and makes retry UI (`state.fanOutReports`) human-readable.
6. **Surfacing to users.** Show the subject above the body for the first message in a share thread, in the fan-out status sheet, and inside email drafts (“Subject — X recipients”). When the subject is empty we fall back to the current behaviour.

With these changes, email recipients see meaningful subjects, drafts survive transport switches, and our timeline can distinguish multi-recipient blasts without inventing new chat types.

4) Blocking email contacts & spam mitigation
--------------------------------------------

Delta Core does not talk to the XMPP blocklist, so we need local plumbing for email-specific abuse controls. The goal is to reuse the existing block/unblock UI while keeping storage and enforcement transport-aware.

**Local blocklist.**

- Add a new Drift table (`email_blocklist`) storing the lower-cased email address plus timestamps. Provide `EmailBlocklistAccessor` helpers (stream of blocked contacts, `upsertBlockedAddress`, `deleteBlockedAddress`).
- Create an `EmailBlockingService` under `lib/src/email/service` that exposes `block`, `unblock`, `blocklistStream`, and `isBlocked`. Wire it into `EmailService` so `ChatBloc` or the existing `BlockButtonInline` can route email block requests via dependency injection (`context.read<EmailService>()?.blocking`).
- Update `DeltaEventConsumer._handleIncoming` to check the blocklist before persisting a message. Blocked addresses should skip database writes, suppress notifications, and increment a counter so we can surface “Blocked 3 messages” badges.
- Make the block/unblock UI transport-aware: when the chat’s `MessageTransport` is email we call the email blocking service; otherwise we retain the XMPP `BlockingService`.

**Spam pathways.**

- Introduce an `email_spamlist` Drift table plus an `EmailSpamService` helper so we can persist every address the user marks as spam without touching the XMPP blocklist.
- When a user taps “Report spam,” flip the chat’s new `spam` flag with `ChatsService.toggleChatSpam` and add the sender to the spam list. The chat disappears from the primary inbox and shows up under the new Spam tab beside Drafts/Blocked; users can move it back to the inbox at any time.
- Update `DeltaEventConsumer` to check the spam list before persisting a message: flagged senders are saved normally but tagged with `MessageWarning.emailSpamQuarantined`, notifications are suppressed, and the owning chat remains in the spam folder.
- Because everything is still stored in Drift, the Spam folder UI can be a thin wrapper around `ChatsCubit` that filters `chat.spam == true`, with “Move to inbox” actions wired through the same `EmailSpamService`/`ChatsService` pair.

Together these pieces give users clarity (spam lives in a quarantine view), an obvious way to flag abusive senders, and a simple recovery path if something is mis-classified.
