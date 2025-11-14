import 'package:axichat/src/email/models/email_attachment.dart';
import 'package:delta_ffi/delta_safe.dart' show DeltaCoreEvent;

/// Contract that allows the application to plug different transports
/// (Delta Chat, SMTP, etc.) behind the existing chat/domain layer.
abstract class ChatTransport {
  /// Prepares any persistent state (databases, caches, etc.).
  Future<void> ensureInitialized({
    required String databasePrefix,
    required String databasePassphrase,
  });

  /// Configures account credentials inside the transport.
  Future<void> configureAccount({
    required String address,
    required String password,
    required String displayName,
    Map<String, String> additional,
  });

  /// Opens connections / event streams.
  Future<void> start();

  /// Stops IO without disposing the underlying resources.
  Future<void> stop();

  /// Tears down all resources.
  Future<void> dispose();

  /// Sends a plaintext message to an existing chat id.
  Future<int> sendText({
    required int chatId,
    required String body,
    String? shareId,
    String? localBodyOverride,
  });

  /// Sends an attachment message to an existing chat id.
  Future<int> sendAttachment({
    required int chatId,
    required EmailAttachment attachment,
    String? shareId,
    String? captionOverride,
  });

  /// Ensures there is a 1:1 chat for the provided address and returns
  /// its Delta Chat chat_id.
  Future<int> ensureChatForAddress({
    required String address,
    String? displayName,
  });

  /// Returns the coarse connectivity state defined by Delta Chat core.
  Future<int?> connectivity();

  /// Stream of raw core events emitted by the transport.
  Stream<DeltaCoreEvent> get events;
}
