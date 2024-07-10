part of 'package:chat/src/xmpp/xmpp_service.dart';

extension on mox.MessageEvent {
  bool get displayable {
    return extensions.get<mox.MessageBodyData>()?.body?.isNotEmpty ??
        false ||
            extensions.get<mox.StatelessFileSharingData>() != null ||
            extensions.get<mox.FileUploadNotificationData>() != null;
  }
}

mixin MessageService on XmppBase {
  Future<void> _handleError(mox.MessageEvent event) async {}
  Future<bool> _handleCorrection(mox.MessageEvent event, String jid) async {
    final correctionData =
        event.extensions.get<mox.LastMessageCorrectionData>();
    if (correctionData == null) return false;
    return true;
  }

  Future<bool> _handleRetraction(mox.MessageEvent event, String jid) async {
    final retractionData = event.extensions.get<mox.MessageRetractionData>();
    if (retractionData == null) return false;
    return true;
  }

  Future<bool> _handleFileUploadNotificationReplacement(
    mox.MessageEvent event,
    String jid,
  ) async {
    final replacementData =
        event.extensions.get<mox.FileUploadNotificationReplacementData>();
    if (replacementData == null) return false;
    return true;
  }

  Future<bool> _handleReactions(mox.MessageEvent event, String jid) async {
    final reactionsData = event.extensions.get<mox.MessageReactionsData>();
    if (reactionsData == null) return false;
    return true;
  }

  Future<void> _handleFile(mox.MessageEvent event, String jid) async {}
}
