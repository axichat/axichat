class ChatSubjectCodec {
  static const String _marker = '\u2060';

  static String composeXmppBody({
    required String body,
    required String? subject,
  }) {
    final trimmedBody = body.trim();
    final trimmedSubject = subject?.trim();
    final hasSubject = trimmedSubject?.isNotEmpty == true;
    final hasBody = trimmedBody.isNotEmpty;
    if (!hasSubject) {
      return trimmedBody;
    }
    if (!hasBody) {
      return '$_marker$trimmedSubject';
    }
    return '$_marker$trimmedSubject\n\n$trimmedBody';
  }

  static ({String? subject, String body}) splitXmppBody(String? text) {
    if (text == null || text.isEmpty || !text.startsWith(_marker)) {
      return (subject: null, body: text ?? '');
    }
    final raw = text.substring(1);
    final separatorIndex = raw.indexOf('\n\n');
    if (separatorIndex == -1) {
      final subject = raw.trim();
      return (subject: subject.isEmpty ? null : subject, body: '');
    }
    final subject = raw.substring(0, separatorIndex).trim();
    final body = raw.substring(separatorIndex + 2);
    return (subject: subject.isEmpty ? null : subject, body: body);
  }
}
