// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/synthetic_forward.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('synthetic forward display sender supports marked subjects', () {
    final subject = markSyntheticForwardSubject('FWD: peer@axi.im');

    expect(
      syntheticForwardDisplaySenderLabel(
        subjectLabel: subject,
        emailMarkerPresent: false,
      ),
      'peer@axi.im',
    );
  });

  test('plain forwarded subjects need the email marker to parse sender', () {
    expect(
      syntheticForwardDisplaySenderLabel(
        subjectLabel: 'Fwd: Quarterly plan',
        emailMarkerPresent: false,
      ),
      isNull,
    );
    expect(
      syntheticForwardDisplaySenderLabel(
        subjectLabel: 'Fwd: peer@example.com',
        emailMarkerPresent: true,
      ),
      'peer@example.com',
    );
  });

  test('synthetic forwarded body promotes the original subject', () {
    final split = splitSyntheticForwardBody(
      'Subject: Original subject\n\nOriginal body',
    );

    expect(split.subject, 'Original subject');
    expect(split.body, 'Original body');
  });

  test('forwarded body sender labels extract the original author', () {
    expect(
      forwardedBodySenderLabel(
        '-------- Forwarded message --------\n'
        'From: Person <original@example.com>\n'
        'Subject: Hello\n'
        '\n'
        'Body',
      ),
      'original@example.com',
    );
  });

  test('forwarded body sender labels support variable dash envelopes', () {
    expect(
      forwardedBodySenderLabel(
        '---------- Forwarded message ---------\n'
        'From: Person <original@example.com>\n'
        'Subject: Hello\n'
        '\n'
        'Body',
      ),
      'original@example.com',
    );
  });

  test('forwarded body sender labels support begin forwarded envelopes', () {
    expect(
      forwardedBodySenderLabel(
        'Begin forwarded message:\n'
        'From: Person <original@example.com>\n'
        'Subject: Hello\n'
        '\n'
        'Body',
      ),
      'original@example.com',
    );
  });

  test('forwarded body sender labels decode quoted-printable headers', () {
    expect(
      forwardedBodySenderLabel(
        '---------- Forwarded message ---------\n'
        'From: Original=20Person=20=3Coriginal@example.com=3E\n'
        'Subject: Hello\n'
        '\n'
        'Body',
      ),
      'original@example.com',
    );
  });

  test(
    'forwarded body sender labels decode quoted-printable soft line breaks',
    () {
      expect(
        forwardedBodySenderLabel(
          '---------- Forwarded message ---------\n'
          'From: Original=20Person=20=3Coriginal@=\n'
          'example.com=3E\n'
          'Subject: Hello\n'
          '\n'
          'Body',
        ),
        'original@example.com',
      );
    },
  );

  test('forwarded body sender labels support top-level header blocks', () {
    expect(
      forwardedBodySenderLabel(
        'From: Original Person <original@example.com>\n'
        'Date: Tue, 19 Mar 2026 10:00:00 +0000\n'
        'Subject: Hello\n'
        'To: Forwarder <forwarder@example.com>\n'
        '\n'
        'Body',
      ),
      'original@example.com',
    );
  });

  test(
    'forwarded body sender labels skip MIME preambles before forwarded headers',
    () {
      expect(
        forwardedBodySenderLabel(
          'Content-Type: text/plain; charset="utf-8"\n'
          'Content-Transfer-Encoding: quoted-printable\n'
          '\n'
          'From: Original=20Person=20=3Coriginal@example.com=3E\n'
          'Date: Tue, 19 Mar 2026 10:00:00 +0000\n'
          'Subject: Quarterly plan\n'
          'To: Forwarder <forwarder@example.com>\n'
          '\n'
          'Forwarded body',
        ),
        'original@example.com',
      );
    },
  );

  test('forwarded preview labels prefer stored original senders', () {
    expect(
      preferredForwardedPreviewSenderLabel(
        forwardedOriginalSenderLabel: 'stored@example.com',
        forwardedSubjectSenderLabel: 'original@example.com',
        forwardedFromJid: 'forwarder@example.com',
      ),
      'stored@example.com',
    );
  });

  test(
    'forwarded preview labels prefer the original sender over the forwarder',
    () {
      expect(
        preferredForwardedPreviewSenderLabel(
          forwardedOriginalSenderLabel: null,
          forwardedSubjectSenderLabel: 'original@example.com',
          forwardedFromJid: 'forwarder@example.com',
        ),
        'original@example.com',
      );
    },
  );

  test('forwarded preview labels fall back to the forwarder', () {
    expect(
      preferredForwardedPreviewSenderLabel(
        forwardedOriginalSenderLabel: null,
        forwardedSubjectSenderLabel: null,
        forwardedFromJid: 'forwarder@example.com',
      ),
      'forwarder@example.com',
    );
  });
}
