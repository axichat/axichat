import 'package:axichat/src/storage/models.dart';
import 'package:equatable/equatable.dart';

enum FanOutRecipientState { queued, sending, sent, failed }

class FanOutRecipientStatus extends Equatable {
  const FanOutRecipientStatus({
    required this.chat,
    required this.state,
    this.deltaMsgId,
    this.error,
  });

  final Chat chat;
  final FanOutRecipientState state;
  final int? deltaMsgId;
  final Object? error;

  bool get isFailure => state == FanOutRecipientState.failed;

  @override
  List<Object?> get props => [chat, state, deltaMsgId, error];
}

class FanOutSendReport extends Equatable {
  const FanOutSendReport({
    required this.shareId,
    required this.statuses,
    this.subjectToken,
    this.attachmentWarning = false,
  });

  final String shareId;
  final String? subjectToken;
  final bool attachmentWarning;
  final List<FanOutRecipientStatus> statuses;

  bool get hasFailures => statuses.any((status) => status.isFailure);

  @override
  List<Object?> get props =>
      [shareId, subjectToken, attachmentWarning, statuses];
}

class FanOutTarget extends Equatable {
  const FanOutTarget._({
    required this.chat,
    required this.address,
    required this.displayName,
  });

  factory FanOutTarget.chat(Chat chat) => FanOutTarget._(
        chat: chat,
        address: chat.emailAddress,
        displayName: chat.contactDisplayName,
      );

  factory FanOutTarget.address({
    required String address,
    String? displayName,
  }) =>
      FanOutTarget._(
        chat: null,
        address: address,
        displayName: displayName,
      );

  final Chat? chat;
  final String? address;
  final String? displayName;

  String get key => chat?.jid ?? address!;

  @override
  List<Object?> get props => [chat?.jid, address, displayName];
}

class ShareContext extends Equatable {
  const ShareContext({
    required this.shareId,
    required this.participants,
  });

  final String shareId;
  final List<Chat> participants;

  @override
  List<Object?> get props => [shareId, participants];
}
