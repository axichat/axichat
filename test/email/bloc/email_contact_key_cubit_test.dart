// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:io';

import 'package:axichat/src/email/bloc/email_contact_key_cubit.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(File('/tmp/fallback-public-key.asc'));
    registerFallbackValue(EmailOpenPgpIdentityBinding.addressMatch);
  });

  test(
    'load without active email account does not query contact key',
    () async {
      final emailService = MockEmailService();
      when(
        () => emailService.activeEncryptionAccountInfo(),
      ).thenAnswer((_) async => null);

      final cubit = EmailContactKeyCubit(emailService: emailService);
      addTearDown(cubit.close);

      await cubit.load(address: 'friend@example.com', displayName: 'Friend');

      expect(cubit.state, const EmailContactKeyIdle());
      verify(() => emailService.activeEncryptionAccountInfo()).called(1);
      verifyNever(
        () => emailService.trustedContactKeyForAddress('friend@example.com'),
      );
    },
  );

  test('failed inspection clears pending contact key import', () async {
    final emailService = MockEmailService();
    final firstFile = File('/tmp/first-public-key.asc');
    final badFile = File('/tmp/bad-public-key.asc');
    const account = EmailEncryptionAccountInfo(
      normalizedAddress: 'user@example.com',
      deltaAccountId: 1,
    );
    when(
      () => emailService.activeEncryptionAccountInfo(),
    ).thenAnswer((_) async => account);
    when(
      () => emailService.trustedContactKeyForAddress('friend@example.com'),
    ).thenAnswer((_) async => null);
    when(
      () => emailService.inspectContactPublicKey(
        address: 'friend@example.com',
        source: firstFile,
      ),
    ).thenAnswer(
      (_) async => const EmailOpenPgpKeyMetadata(
        kind: EmailOpenPgpKeyKind.public,
        fingerprint: 'ABCD',
        userIds: <String>[],
        hasExpectedAddress: false,
        hasEncryptionCapability: true,
      ),
    );
    when(
      () => emailService.inspectContactPublicKey(
        address: 'friend@example.com',
        source: badFile,
      ),
    ).thenThrow(const EmailContactKeyUnsupportedFormatException());

    final cubit = EmailContactKeyCubit(emailService: emailService);
    addTearDown(cubit.close);

    await cubit.load(address: 'friend@example.com', displayName: 'Friend');
    await cubit.inspectPublicKey(firstFile);
    expect(cubit.state, isA<EmailContactKeyConfirmationRequired>());

    await cubit.inspectPublicKey(badFile);
    expect(cubit.state, const EmailContactKeyIdle(account: account));

    final states = expectLater(
      cubit.stream,
      emitsInOrder([
        const EmailContactKeyFailure(EmailContactKeyFailureReason.importFailed),
        const EmailContactKeyIdle(account: account),
      ]),
    );

    await cubit.confirmImport();
    await states;
    expect(cubit.state, const EmailContactKeyIdle(account: account));
    verifyNever(
      () => emailService.importTrustedContactPublicKey(
        address: any(named: 'address'),
        displayName: any(named: 'displayName'),
        source: any(named: 'source'),
        identityBinding: any(named: 'identityBinding'),
        expectedFingerprint: any(named: 'expectedFingerprint'),
      ),
    );
  });

  test('matching public key imports without confirmation', () async {
    final emailService = MockEmailService();
    final file = File('/tmp/friend-public-key.asc');
    const account = EmailEncryptionAccountInfo(
      normalizedAddress: 'user@example.com',
      deltaAccountId: 1,
    );
    const metadata = EmailOpenPgpKeyMetadata(
      kind: EmailOpenPgpKeyKind.public,
      fingerprint: 'ABCD',
      userIds: ['Friend <friend@example.com>'],
      hasExpectedAddress: true,
      hasEncryptionCapability: true,
    );
    EmailTrustedContactKey? trustedKey;
    final importedKey = EmailTrustedContactKey(
      deltaAccountId: 1,
      normalizedAddress: 'friend@example.com',
      fingerprint: 'ABCD',
      deltaContactId: 17,
      deltaChatId: 91,
      identityBinding: EmailOpenPgpIdentityBinding.addressMatch,
      userIds: const ['Friend <friend@example.com>'],
      importedAt: DateTime.fromMillisecondsSinceEpoch(0),
    );
    when(
      () => emailService.activeEncryptionAccountInfo(),
    ).thenAnswer((_) async => account);
    when(
      () => emailService.trustedContactKeyForAddress('friend@example.com'),
    ).thenAnswer((_) async => trustedKey);
    when(
      () => emailService.inspectContactPublicKey(
        address: 'friend@example.com',
        source: file,
      ),
    ).thenAnswer((_) async => metadata);
    when(
      () => emailService.importTrustedContactPublicKey(
        address: 'friend@example.com',
        displayName: 'Friend',
        source: any(named: 'source'),
        identityBinding: EmailOpenPgpIdentityBinding.addressMatch,
        expectedFingerprint: 'ABCD',
      ),
    ).thenAnswer((_) async {
      trustedKey = importedKey;
      return importedKey;
    });

    final cubit = EmailContactKeyCubit(emailService: emailService);
    addTearDown(cubit.close);

    await cubit.load(address: 'friend@example.com', displayName: 'Friend');
    final states = expectLater(
      cubit.stream,
      emitsInOrder([
        const EmailContactKeyInspecting(),
        const EmailContactKeyImporting(),
        const EmailContactKeySuccess(EmailContactKeySuccessKind.imported),
        EmailContactKeyIdle(
          account: account,
          trustedKey: importedKey,
          normalizedAddress: 'friend@example.com',
        ),
      ]),
    );
    await cubit.inspectPublicKey(file);
    await states;

    expect(
      cubit.state,
      EmailContactKeyIdle(
        account: account,
        trustedKey: importedKey,
        normalizedAddress: 'friend@example.com',
      ),
    );
    verify(
      () => emailService.importTrustedContactPublicKey(
        address: 'friend@example.com',
        displayName: 'Friend',
        source: any(named: 'source'),
        identityBinding: EmailOpenPgpIdentityBinding.addressMatch,
        expectedFingerprint: 'ABCD',
      ),
    ).called(1);
  });

  test('mismatched public key waits for confirmation before import', () async {
    final emailService = MockEmailService();
    final file = File('/tmp/friend-public-key.asc');
    const account = EmailEncryptionAccountInfo(
      normalizedAddress: 'user@example.com',
      deltaAccountId: 1,
    );
    const metadata = EmailOpenPgpKeyMetadata(
      kind: EmailOpenPgpKeyKind.public,
      fingerprint: 'ABCD',
      userIds: ['Other <other@example.com>'],
      hasExpectedAddress: false,
      hasEncryptionCapability: true,
    );
    EmailTrustedContactKey? trustedKey;
    final importedKey = EmailTrustedContactKey(
      deltaAccountId: 1,
      normalizedAddress: 'friend@example.com',
      fingerprint: 'ABCD',
      deltaContactId: 17,
      deltaChatId: 91,
      identityBinding: EmailOpenPgpIdentityBinding.userConfirmed,
      userIds: const ['Other <other@example.com>'],
      importedAt: DateTime.fromMillisecondsSinceEpoch(0),
    );
    when(
      () => emailService.activeEncryptionAccountInfo(),
    ).thenAnswer((_) async => account);
    when(
      () => emailService.trustedContactKeyForAddress('friend@example.com'),
    ).thenAnswer((_) async => trustedKey);
    when(
      () => emailService.inspectContactPublicKey(
        address: 'friend@example.com',
        source: file,
      ),
    ).thenAnswer((_) async => metadata);
    when(
      () => emailService.importTrustedContactPublicKey(
        address: 'friend@example.com',
        displayName: 'Friend',
        source: any(named: 'source'),
        identityBinding: EmailOpenPgpIdentityBinding.userConfirmed,
        expectedFingerprint: 'ABCD',
      ),
    ).thenAnswer((_) async {
      trustedKey = importedKey;
      return importedKey;
    });

    final cubit = EmailContactKeyCubit(emailService: emailService);
    addTearDown(cubit.close);

    await cubit.load(address: 'friend@example.com', displayName: 'Friend');
    final states = expectLater(
      cubit.stream,
      emitsInOrder([
        const EmailContactKeyInspecting(),
        const EmailContactKeyConfirmationRequired(metadata),
        const EmailContactKeyImporting(),
        const EmailContactKeySuccess(EmailContactKeySuccessKind.imported),
        EmailContactKeyIdle(
          account: account,
          trustedKey: importedKey,
          normalizedAddress: 'friend@example.com',
        ),
      ]),
    );
    await cubit.inspectPublicKey(file);

    expect(cubit.state, const EmailContactKeyConfirmationRequired(metadata));
    verifyNever(
      () => emailService.importTrustedContactPublicKey(
        address: 'friend@example.com',
        displayName: 'Friend',
        source: any(named: 'source'),
        identityBinding: EmailOpenPgpIdentityBinding.userConfirmed,
        expectedFingerprint: 'ABCD',
      ),
    );

    await cubit.confirmImport();
    await states;

    expect(
      cubit.state,
      EmailContactKeyIdle(
        account: account,
        trustedKey: importedKey,
        normalizedAddress: 'friend@example.com',
      ),
    );
    verify(
      () => emailService.importTrustedContactPublicKey(
        address: 'friend@example.com',
        displayName: 'Friend',
        source: any(named: 'source'),
        identityBinding: EmailOpenPgpIdentityBinding.userConfirmed,
        expectedFingerprint: 'ABCD',
      ),
    ).called(1);
  });

  test('cancelled public key confirmation does not import', () async {
    final emailService = MockEmailService();
    final file = File('/tmp/friend-public-key.asc');
    const account = EmailEncryptionAccountInfo(
      normalizedAddress: 'user@example.com',
      deltaAccountId: 1,
    );
    const metadata = EmailOpenPgpKeyMetadata(
      kind: EmailOpenPgpKeyKind.public,
      fingerprint: 'ABCD',
      userIds: ['Other <other@example.com>'],
      hasExpectedAddress: false,
      hasEncryptionCapability: true,
    );
    when(
      () => emailService.activeEncryptionAccountInfo(),
    ).thenAnswer((_) async => account);
    when(
      () => emailService.trustedContactKeyForAddress('friend@example.com'),
    ).thenAnswer((_) async => null);
    when(
      () => emailService.inspectContactPublicKey(
        address: 'friend@example.com',
        source: file,
      ),
    ).thenAnswer((_) async => metadata);

    final cubit = EmailContactKeyCubit(emailService: emailService);
    addTearDown(cubit.close);

    await cubit.load(address: 'friend@example.com', displayName: 'Friend');
    await cubit.inspectPublicKey(file);
    await cubit.cancelImport();

    expect(cubit.state, const EmailContactKeyIdle(account: account));
    verifyNever(
      () => emailService.importTrustedContactPublicKey(
        address: any(named: 'address'),
        displayName: any(named: 'displayName'),
        source: any(named: 'source'),
        identityBinding: any(named: 'identityBinding'),
        expectedFingerprint: any(named: 'expectedFingerprint'),
      ),
    );
  });

  test('remove failure reloads existing key state', () async {
    final emailService = MockEmailService();
    const account = EmailEncryptionAccountInfo(
      normalizedAddress: 'user@example.com',
      deltaAccountId: 1,
    );
    final trustedKey = EmailTrustedContactKey(
      deltaAccountId: 1,
      normalizedAddress: 'friend@example.com',
      fingerprint: 'ABCD',
      deltaContactId: 17,
      deltaChatId: 91,
      identityBinding: EmailOpenPgpIdentityBinding.addressMatch,
      userIds: const ['Friend <friend@example.com>'],
      importedAt: DateTime.fromMillisecondsSinceEpoch(0),
    );
    when(
      () => emailService.activeEncryptionAccountInfo(),
    ).thenAnswer((_) async => account);
    when(
      () => emailService.trustedContactKeyForAddress('friend@example.com'),
    ).thenAnswer((_) async => trustedKey);
    when(
      () => emailService.removeTrustedContactPublicKey('friend@example.com'),
    ).thenThrow(const EmailContactKeyRemoveFailedException());

    final cubit = EmailContactKeyCubit(emailService: emailService);
    addTearDown(cubit.close);

    await cubit.load(address: 'friend@example.com', displayName: 'Friend');
    final states = expectLater(
      cubit.stream,
      emitsInOrder([
        const EmailContactKeyRemoving(),
        const EmailContactKeyFailure(EmailContactKeyFailureReason.removeFailed),
        EmailContactKeyIdle(
          account: account,
          trustedKey: trustedKey,
          normalizedAddress: 'friend@example.com',
        ),
      ]),
    );

    await cubit.remove();
    await states;

    expect(
      cubit.state,
      EmailContactKeyIdle(
        account: account,
        trustedKey: trustedKey,
        normalizedAddress: 'friend@example.com',
      ),
    );
  });
}
