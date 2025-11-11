# Email Service Integration Checklist

Goal: deliver an email transport that mirrors the app’s existing XMPP behaviour, exposing an `EmailService` counterpart to `XmppService` and letting users switch transports seamlessly from compose and chat flows.

## 1. Foundation
- [x] Audit current `XmppService` composition (`lib/src/xmpp/xmpp_service.dart`) to enumerate required capabilities (connection lifecycle, chat/message/roster mixins, notifications, state stores).
- [x] Sketch `EmailService` API surface that mirrors `XmppService` (connect/login, disconnect, chat/message streams, typing markers, etc.) while delegating to Delta Core primitives.
- [x] Decide on dependency injection root (likely `lib/src/email/service/email_service.dart`) and how it will be registered alongside `XmppService` in `lib/src/app.dart`.

### XmppService Feature Snapshot
- Connection lifecycle (`connect`, `_establishConnection`, `_initConnection`) managing moxxmpp negotiators, SASL, stream state, and reconnect handling.
- Database/state orchestration via `_dbOp*` helpers, Drift (`XmppDrift`) access, Hive-backed state store, and credential persistence through `CredentialStore`.
- Event routing built on `EventManager<mox.XmppEvent>` with mixins registering handlers for messages, markers, roster pushes, blocklist updates, OMEMO status, etc.
- Mixins providing domain APIs consumed by UI/BLoCs:
  - `ChatsService` (chat streams, open/close, mute/favorite, encryption toggles).
  - `MessageService` (message streams, sending, drafts, file metadata, ack/receipt handling, pseudo-messages).
  - `RosterService`, `PresenceService`, `BlockingService`, `OmemoService` (contacts, availability, blocklist, encryption maintenance).
  - `BaseStreamService` utilities for combining Drift watchers with cached snapshots.
- Foreground/broadcast integration: notifications (`NotificationService`), foreground service toggles, OMEMO activity stream fan-out, and lifecycle listeners.
- Reset/shutdown flows ensuring managers, databases, and sockets are cleaned up, matching logout/burn semantics.

## 2. Storage & Models
- [x] Confirm database schema has all email-specific fields; add any missing columns (e.g., delivery status, attachment info) plus Drift migrations.
- [x] Ensure `Message`, `Chat`, and related DAOs expose helpers to distinguish transport (`deltaChatId`, `emailAddress`) without breaking XMPP code paths.
- [x] Extend DAO queries/watchers to include email chats in default lists while keeping existing ordering rules intact.

## 3. Service Implementation
- [x] Create `EmailService` that owns an `EmailDeltaTransport`, database handle, notification service, and state store equivalents.
- [x] Provide stream APIs (`chatsStream`, `messageStreamForChat`, `draftsStream`, etc.) reusing shared database code so Bloc consumers can remain transport-agnostic. *(EmailService mirrors the Drift watchers now.)*
- [x] Implement message sending, typing indicators (or email-safe no-ops), chat open/close semantics, and delivery receipts compatible with the UI expectations.
- [x] Mirror lifecycle hooks: foreground/background handling, reset/teardown, credential persistence via `CredentialStore`.
- [x] Bridge Delta events into the unified message stream (`_messageStream` equivalent) so notifications and UI updates trigger identically to XMPP.

### Architecture Plan (draft)
- Introduce `EmailService` under `lib/src/email/service/email_service.dart`, backed by the existing `EmailDeltaTransport`. It will expose chat/message APIs analogous to `XmppService` via dedicated mixins (e.g., `EmailChatsService`, `EmailMessageService`) implemented atop shared helpers (`EmailDatabaseOps`, `EmailBaseStreamService`).
- Create a `UnifiedMessagingService` façade that implements the current `ChatsService`, `MessageService`, `BlockingService`, etc. contracts by delegating to either `XmppService` or `EmailService` depending on chat metadata (`deltaChatId`/`emailAddress` markers). Existing Blocs/UI can keep depending on a single provider.
- Extract shared persistence utilities (stream composition, message saving helpers, `dbFileFor` accessors) so both transports reuse the same code without copying logic.
- Update `lib/src/app.dart` wiring to instantiate `XmppService` + `EmailService`, then provide the façade while still exposing transport-specific dependencies (e.g., OMEMO overlays continue to talk to the raw `XmppService`).
- Maintain a transport registry that records which backend a chat uses (persisted per chat record) and ensures compose/new-chat flows respect the user’s transport choice.

## 4. UI & State Management
- [x] Introduce a transport selector (compose form toggle + in-chat control) that records the preferred transport per conversation.
- [x] Update `DraftCubit`, `ChatBloc`, `ChatsCubit`, and any other consumers to resolve the correct service (`XmppService` vs `EmailService`) at runtime based on chat metadata.
- [x] Ensure chat list, contact roster, and profile panes display email chats (titles, avatars, unread badges) without XMPP-specific assumptions. *(Chats list now badges the active transport.)*
- [x] Handle features that don’t apply to email (e.g., OMEMO toggles, roster subscriptions) with graceful fallbacks or hidden UI. *(Encryption toggles hidden for email chats pending full removal.)*

## 5. Background, Notifications, & Sync
- [x] Decide on background sync expectations for email (periodic polling vs push) and implement equivalent hooks in `EmailService`. *(`setClientState` now proxies to start/stop just like CSI.)*
- [x] Integrate with `NotificationService` so incoming email messages trigger the same flow as XMPP (respect mute/focus states).
- [x] Verify logout/burn flows stop the email transport, clear credentials, and wipe transport-specific caches.

## 6. Testing & Tooling
- [x] Add unit tests for `EmailService` covering send/receive, provisioning, and state transitions (mocking `DeltaSafe` + database).
- [x] Extend integration tests in `test/` to exercise email toggles, ensuring UI parity with XMPP. _(Transport extension + lifecycle tests added; full widget coverage pending native-assets support.)_
- [x] Update build scripts to ensure `dart run build_runner` and native hook compilation run automatically for CI (document any prerequisites). *(Documented `build_runner` + native assets steps in `docs/email.md`.)*

## 7. Documentation & Rollout
- [x] Update `docs/email.md` with the `EmailService` architecture, explaining transport selection and lifecycle.
- [x] Document manual QA steps (e.g., sending email chats, verifying fallback to XMPP) and add them to the release checklist.
- [x] Call out follow-up work or remaining risks in `.claude/plans` (if applicable) to guide subsequent iterations.
