# Working Notes for storage

# Storage Module

- MUST refer to https://drift.simonbinder.eu/ when modifying Drift related code
- MUST refer to https://pub.dev/packages/flutter_secure_storage when modifying credential storage
- MUST refer to https://pub.dev/packages/hive when modifying state store related code
 
## Core abstractions
- `database.dart`: Drift/SQLCipher database definitions (part `database.g.dart`). Interfaces `Database` (close) and `XmppDatabase` with full contract for messages, reactions, chats (mute/favorite/archive/spam/hidden/alerts/encryption/marker responsiveness), drafts CRUD + attachments, blocklist, roster, presence, chat state, OMEMO (devices, device lists, trusts, ratchets, bundle cache, prekey rotation time), file metadata, message shares, markers/acked flags, chat open/close, chat pagination, search, etc. Uses `XmppDrift` concrete implementation (generated). Utilities for db file path and SQLCipher initialization.
- `state_store.dart`: Hive-backed `XmppStateStore` wrapper with registered keys, watch/read/write/delete APIs, deleteAll(burn), and Hive box setup helpers.
- `credential_store.dart`: Secure credential storage using `flutter_secure_storage`; exposes `read/write/delete/deleteAll`, registration of typed keys, optional burn deletes, and `.close()`. Used by Authentication/Email.
- `database_extensions.dart`: Helpers for Database implementations (e.g., for drift operations; review before edits).
- `impatient_completer.dart`: Wrapper providing inspectable completer with `isCompleted`, `value`, `completer`.

## Models (Drift/Freezed)
- `models.dart`: Barrel exporting models below.
- `models/chat_models.dart`: Chat/Presence/Roster/Blocklist/etc. definitions; generated counterparts `.freezed.dart`/`.g.dart`. Includes enums like `MessageTransport`, `MessageTimelineFilter`, `EncryptionProtocol`, chat flags, and converters.
- `models/message_models.dart`: Message entities (body, timestamps, encryption, errors, reactions preview), `Reaction`, `MessageShareData` and related DAO data; generated `.freezed.dart`.
- `models/file_models.dart`: File metadata (paths, mime, size, dimensions, encryption info) with Freezed/generators.
- `models/omemo_models.dart`: OMEMO device/trust/ratchet/bundle cache structs with Freezed. Keep in sync with omemo service expectations.
- `models/database_converters.dart`: Drift type converters used across models.
- Generated files: `database.g.dart`, `*_freezed.dart`, `*_g.dart` (Drift table code). Do not hand-edit; run build_runner after schema/model updates.

## Usage reminders
- Regenerate after model/table changes: `dart run build_runner build --delete-conflicting-outputs`.
- DB is SQLCipher-backed; file/key management handled in `XmppService`/`EmailService` via prefix+passphrase written to CredentialStore. Avoid leaking secrets in logs. Migration/testing should include DAO round-trips and prekey/omemo data consistency.
