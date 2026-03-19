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
