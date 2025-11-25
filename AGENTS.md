# Axichat Development Guide

## 🎯 PROJECT CONTEXT

**Modular XMPP + SMTP messenger with NO big tech dependencies**

- XMPP for IM functionality, DeltaChat Core Rust for SMTP functionality
- SQLCipher database + Flutter Secure Storage for credentials
- No Firebase, Google Services, or tracking
- Cross-platform: Android, iOS, Windows, Linux, macOS

**Core Concepts:**

- **JID == Email address**: Jabber ID format and Email format both -> `user@domain.com`

## 🏗️ ARCHITECTURE

### CRITICAL DECLARATIVE and REACTIVE FLOW used throughout ENTIRE APP

- HIGHEST PRIORITY!: **Declarative NOT imperative**: User updates UI -> UI updates BLoCs -> BLoCs update storage -> storage updates BLoCs -> BLoCs update UI

**Same sequence for chats, calendar, email, blocklist, drafts, etc.**

1. **Widget Layer → BLoC Actions**
   ```dart
   // lib/src/chat/view/chat.dart:210-213
   onSend: (message) {
     context.read<ChatBloc>().add(ChatMessageSent(text: message.text));
     _focusNode.requestFocus();
   }
   ```

2. **BLoC Layer → Service Functions**
   ```dart
   // lib/src/chat/bloc/chat_bloc.dart:137-148
   Future<void> _onChatMessageSent(ChatMessageSent event, Emitter<ChatState> emit) async {
     _stopTyping();
     emit(state.copyWith(typing: false));
     await _messageService.sendMessage(
       jid: jid!,
       text: event.text,
       encryptionProtocol: state.chat!.encryptionProtocol,
     );
   }
   ```
3. **Service Layer → moxxmpp Library**
   ```dart
   // lib/src/xmpp/message_service.dart:188-209
   Future<void> sendMessage({required String jid, required String text}) async {
     final message = Message(/*... create message object ...*/);
     await db.saveMessage(message); // Save to database first
     
     if (!await _connection.sendMessage(message.toMox())) {
       throw XmppMessageException();
     }
   }
   
   // lib/src/xmpp/xmpp_connection.dart:98-103  
   Future<bool> sendMessage(mox.MessageEvent packet) async {
     await getManager<mox.MessageManager>()?.sendMessage(packet.to, packet.extensions);
   }
   ```
4. **moxxmpp Library → Events**
   ```dart
   // moxxmpp emits mox.MessageEvent when message sent/received/processed
   // lib/src/xmpp/message_service.dart:50-51
   EventManager<mox.XmppEvent> get _eventManager => super._eventManager
     ..registerHandler<mox.MessageEvent>((event) async {
       // Process incoming mox.MessageEvent from moxxmpp library
     });
   ```
5. **Event Managers → Database Updates**
   ```dart
   // lib/src/xmpp/message_service.dart:51-129  
   ..registerHandler<mox.MessageEvent>((event) async {
     final message = Message.fromMox(event);
     
     if (!message.noStore) {
       final db = await database;
       await db.executeOperation(
         operation: () => db.saveMessage(message), // _dbOp wrapper
         operationName: 'save incoming message',
       );
     }
   });
   ```
6. **Database → Service Streams**
   ```dart
   // lib/src/xmpp/message_service.dart:25-31
   Stream<List<Message>> messageStreamForChat(String jid) =>
     createSingleItemStream<List<Message>, XmppDatabase>(
       watchFunction: (db) async {
         final stream = db.watchChatMessages(jid); // Drift auto-emits on changes
         final initial = await db.getChatMessages(jid);
         return stream.startWith(initial); // BaseStreamService pattern
       },
     );
   ```
7. **Service Streams → BLoC Updates**
   ```dart
   // lib/src/chat/bloc/chat_bloc.dart:46-51
   _chatSubscription = _chatsService
       .chatStream(jid!)
       .listen((chat) => add(_ChatUpdated(chat)));
   _messageSubscription = _messageService
       .messageStreamForChat(jid!, end: messageBatchSize)
       .listen((items) => add(_ChatMessagesUpdated(items)));
   ```
8. **BLoC → Widget UI Updates**
   ```dart
   // lib/src/chat/view/chat.dart:78-86
   return BlocBuilder<ChatBloc, ChatState>(
     builder: (context, state) {
       final user = ChatUser(id: profile?.jid ?? '', firstName: profile?.username ?? '');
       return Chat(
         messages: state.items, // UI rebuilds automatically on state.items change
         user: user,
         onSend: (message) => context.read<ChatBloc>().add(ChatMessageSent(text: message.text)),
       );
     },
   );
   ```

### Separation of Concerns

```dart
// XMPP Service factory with dependency injection
factory XmppService({
  required FutureOr<XmppConnection> Function() buildConnection,
  required FutureOr<XmppStateStore> Function(String, String) buildStateStore,
  required FutureOr<XmppDatabase> Function(String, String) buildDatabase,
  NotificationService? notificationService,
}) => XmppService._(buildConnection, buildStateStore, buildDatabase, notificationService);

// BLoC layer dependency injection
class ChatBloc extends Bloc<ChatEvent, ChatState> {
  ChatBloc({
    required MessageService messageService,
    required ChatsService chatsService,
    required NotificationService notificationService,
  });
}

// Provider-based injection at runtime
BlocProvider
(
create: (context) => ChatsCubit(
chatsService: context.read<XmppService>(),
),
)
```

### Code Style Requirements

- NEVER use `_build` helpers for building widgets. Private method helpers starting with `_build` are FORBIDDEN. ALWAYS create an actual widget instead.
- Do not invent new colors. Always pull colors/borders from the shared theme extensions (`context.colorScheme`, `context.decoration`, tokens in `app.dart`) so widgets stay visually consistent.
- **Always use cascade operators where possible** to reduce repetition
- **Extract common functionality to extension methods**, especially for enums
- **After every code change:** Run `dart format .` → `dart analyze` → `dart fix --apply` using MCP
  tools

```dart
// DatabaseOperations extension eliminates repetitive error handling
extension DatabaseOperations on XmppDatabase {
  Future<T> executeQuery<T>({required operation, operationName}) async {}
}

// Use cascade operators for multiple operations
final button = ShadButton()
  ..onPressed = () => handlePress()
  ..child = Text('Submit')
  ..style = ButtonStyle();
```

### Take Advantage of Dart's Strong Typing to Write Fool-Proof Code

- Create new types for specific uses. Prefer not to use typedefs.

```dart
// Compile-time safety - can't use unregistered keys
final jidKey = CredentialStore.registerKey('jid');
await
credentialStore.read
(
key
:
jidKey
); // ✅ Type-safe
// await credentialStore.read(key: 'typo'); // ❌ Runtime error
```

### Models Organization

```

lib/src/storage/
├── models.dart # Export barrel (DO NOT add logic here)
├── models/
│ ├── message_models.dart # Message, Reaction, Notification
│ ├── chat_models.dart # Chat, RosterItem, Presence
│ ├── file_models.dart # FileMetadata, Sticker, Draft
│ └── database_converters.dart # JSON converters
└── database_extensions.dart # Database operation helpers

```

## Build, Test, and Development Commands

- USE THE DART MCP; if it is unavailable fall back to the commands below.
- `flutter pub get` — install dependencies after modifying `pubspec.yaml`.
- `dart run build_runner build --delete-conflicting-outputs` — regenerate Drift, Freezed, router, or other annotated artifacts whenever schemas/models change.
- `flutter run` (add `--flavor dev` for staging) powers manual smoke tests.
- Always run `dart format .` followed by `dart analyze` (or equivalent IDE actions) before sharing patches to keep the lint suite predictable.
- `flutter test` — execute unit and widget suites; scope with `flutter test test/chat`.
- `flutter test integration_test` — run integration coverage on an attached emulator/device.
- `dart test` — useful for pure Dart targets (storage/xmpp) when you want CLI output and tighter filters.

## Coding Style & Naming Conventions

- NEVER use "magic values" or literals. ALWAYS create a named variable/constant if it's a one place use. 
- Use 2-space indentation, trailing commas to aid `dart format`, and snake_case file names; classes/enums remain in PascalCase.
- Reusable UI must be implemented as `StatelessWidget`/`StatefulWidget` classes—do not expose widgets as helper functions or builders.
- Name BLoC layers consistently (`FeatureBloc`, `FeatureState`, `FeatureEvent`) inside their owning feature folders.
- Use extensions to make common operations easier, especially when you have to keep chaining the same methods together.
- Avoid using operators on enums, prefer using built-in getters. For example:
```dart

enum Subscription {
none,
to,
from,
both;

static Subscription fromString(String value) => switch (value) {
'to' => to,
'from' => from,
'both' => both,
_ => none,
};

bool get isNone => this == none;

bool get isTo => this == to;

bool get isFrom => this == from;

bool get isBoth => this == both;
}
```
- Prefer explicit types, exhaustive `switch` statements, cascade operators, and intent-revealing names (`checkOmemoSupport`, `startOmemoOperation`).
- Keep logging consistent by reusing the existing `Logger` instances—never leave `print` in production paths—and avoid leaking sensitive data.
- Widgets should remain declarative/stateless whenever reasonable; move business logic into blocs/services per `BLOC_GUIDE.md`.
- Follow the design tokens and UI helpers exported by `lib/src/common/ui/ui.dart` and `lib/src/app.dart`.

## 🧱 Custom Render Objects Playbook

- When a widget must react to geometry discovered in the same layout pass (chat bubble cutouts, overlap-aware paddings, etc.), promote it to a `MultiChildRenderObjectWidget` so the render object can lay out the body, compute limits, and then size overlays without juggling `GlobalKey`s or post-frame hacks.
- Define parent-data slots (`body`, `reaction`, `recipients`, …) for each child so layout/paint/hit-test steps stay deterministic; this also keeps animation math centralized instead of replicated in widgets.
- If other systems (selection hit regions, autoscroll) need bubble bounds, register the render boxes in a tiny registry on attach/detach rather than scattering duplicate global keys—registries avoid reparenting assertions and are cheaper to query.
- Keep render-object configuration strictly declarative (e.g., `CutoutStyle` structs describing depth/radius/padding) so designers can tweak visuals from widget code without touching the render-layer implementation every time.

## 🔐 SECURITY REQUIREMENTS

**NEVER log/expose:** JIDs, passwords, message content, keys
**Credential access:** Only via RegisteredCredentialKey system
**Database:** SQLCipher with user-derived passphrase

## 🎨 UI PATTERNS

### Design Tokens

```dart

const axiGreen = Color(0xff80ffa0); // Brand color
const listItemPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 8);
const baseAnimationDuration = Duration(milliseconds: 300);
const messageBatchSize = 50; // Pagination size
```

### Extensions (from app.dart)

```dart
context.colorScheme // ShadColorScheme
context.textTheme // ShadTextTheme  
context.decoration // ShadDecoration
context.radius // BorderRadius

// Mobile hover strategy for touch devices
const mobileHoverStrategies = ShadHoverStrategies(
  hover: {ShadHoverStrategy.onLongPressDown},
  unhover: {ShadHoverStrategy.onLongPressUp, ShadHoverStrategy.onLongPressCancel},
);
```

### Component Prefix: Axi

**IMPORTANT:** The `Axi` prefix is ONLY for custom versions of existing widgets, not for entirely new widgets.

Examples:
- ✅ `AxiAppBar` - Custom version of standard AppBar
- ✅ `AxiAvatar` - Custom version of Avatar widget
- ✅ `AxiMessageTile` - Custom version of ListTile for messages
- ❌ `AxiCalendarWidget` - Wrong! Calendar is a new widget, use `CalendarWidget`
- ❌ `AxiTaskTile` - Wrong! TaskTile is a new widget, use `TaskTile`

- Calendar screens stay declarative—wire interactions into bloc helpers (for example `commitTaskInteraction`) and never mutate calendar models from widgets or controllers.

**After model changes:** `dart run build_runner build --delete-conflicting-outputs`

[//]: # (- NEVER read from .pub-cache)
