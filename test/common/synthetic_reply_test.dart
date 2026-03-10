import 'package:axichat/src/common/synthetic_reply.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('syntheticReplySubject falls back to quoted subject then sender', () {
    expect(
      syntheticReplySubject(
        subject: null,
        quotedSubject: 'Original subject',
        quotedSenderLabel: 'peer@axi.im',
      ),
      'Re: Original subject',
    );
    expect(
      syntheticReplySubject(
        subject: null,
        quotedSubject: null,
        quotedSenderLabel: 'peer@axi.im',
      ),
      'Re: peer@axi.im',
    );
  });

  test('syntheticReplyEnvelope appends an indented quoted block', () {
    final envelope = syntheticReplyEnvelope(
      body: 'Reply body',
      subject: null,
      quotedSubject: 'Original subject',
      quotedBody: 'Line one\n\nLine two',
      quotedSenderLabel: 'peer@axi.im',
    );

    expect(envelope.subject, 'Re: Original subject');
    expect(
      envelope.body,
      'Reply body\n\n> Original subject\n>\n> Line one\n>\n> Line two',
    );
  });
}
