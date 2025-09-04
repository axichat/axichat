# Axichat Development Guide

## 🎯 PROJECT CONTEXT

**Privacy-focused XMPP messenger with NO big tech dependencies**

- End-to-end encryption via OMEMO2 (Signal Protocol)
- SQLCipher database + Flutter Secure Storage for credentials
- No Firebase, Google Services, or tracking
- Cross-platform: Android, iOS, Windows, Linux, macOS

## 📋 XMPP DOMAIN VOCABULARY

**Core Concepts:**

- **JID**: Jabber ID format `user@domain.com`
- **Stanza**: XMPP message unit (message/presence/iq)
- **Roster**: Contact list with subscription states (none/to/from/both)
- **BTBV**: Blind Trust Before Verification (OMEMO trust model)
- **Ratchet**: Double Ratchet algorithm for forward-secure encryption
- **Bundle**: OMEMO public key package for session establishment
- **MKSkipped**: Message keys for out-of-order message decryption

## 🏗️ ARCHITECTURE

### CRITICAL DECLARATIVE and REACTIVE FLOW used throughout ENTIRE APP

**Same sequence for roster, chats, presence, blocklist, drafts, etc.**

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
├── models.dart              # Export barrel (DO NOT add logic here)
├── models/
│   ├── message_models.dart # Message, Reaction, Notification
│   ├── omemo_models.dart   # All crypto models with parallel toJson
│   ├── chat_models.dart    # Chat, RosterItem, Presence
│   ├── file_models.dart    # FileMetadata, Sticker, Draft
│   └── database_converters.dart # JSON converters
└── database_extensions.dart # Database operation helpers

```

## 🔐 SECURITY REQUIREMENTS

**NEVER log/expose:** JIDs, passwords, message content, keys
**Always encrypt:** Messages use OMEMO by default  
**Credential access:** Only via RegisteredCredentialKey system
**Database:** SQLCipher with user-derived passphrase
**Trust model:** BTBV (Blind Trust Before Verification)

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

All custom UI components use `Axi` prefix: `AxiAppBar`, `AxiAvatar`, `AxiMessageTile`

**After model changes:** `dart run build_runner build --delete-conflicting-outputs`