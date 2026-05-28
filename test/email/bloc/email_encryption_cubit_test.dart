// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:axichat/src/email/bloc/email_encryption_cubit.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(File('fallback.asc'));
    registerFallbackValue(Uint8List(0));
  });

  test(
    'platform saved export completes through service before activation',
    () async {
      final emailService = MockEmailService();
      final archiveBytes = Uint8List.fromList([1, 2, 3]);
      when(() => emailService.createEmailEncryptionKeyExport()).thenAnswer(
        (_) async => EmailEncryptionKeyExport(
          normalizedAddress: 'user@example.com',
          archiveBytes: archiveBytes,
        ),
      );
      when(
        () => emailService.completeEmailEncryptionKeyExportAfterPlatformSave(
          archiveBytes: any(named: 'archiveBytes'),
          platformResultPath: any(named: 'platformResultPath'),
          normalizedAddress: any(named: 'normalizedAddress'),
        ),
      ).thenAnswer((_) async {});

      final cubit = EmailEncryptionCubit(emailService: emailService);
      addTearDown(cubit.close);

      await cubit.createExport();
      await cubit.completePlatformSavedExport(
        '/document/axichat-email-openpgp-key.zip',
      );

      expect(
        cubit.state,
        const EmailEncryptionActivationReady('user@example.com'),
      );
      verify(
        () => emailService.completeEmailEncryptionKeyExportAfterPlatformSave(
          archiveBytes: archiveBytes,
          platformResultPath: '/document/axichat-email-openpgp-key.zip',
          normalizedAddress: 'user@example.com',
        ),
      ).called(1);
    },
  );

  test(
    'save picker failure clears pending export and emits save failure',
    () async {
      final emailService = MockEmailService();
      when(() => emailService.createEmailEncryptionKeyExport()).thenAnswer(
        (_) async => EmailEncryptionKeyExport(
          normalizedAddress: 'user@example.com',
          archiveBytes: Uint8List.fromList([1, 2, 3]),
        ),
      );

      final cubit = EmailEncryptionCubit(emailService: emailService);
      addTearDown(cubit.close);

      await cubit.createExport();
      await cubit.failExportSave();

      expect(
        cubit.state,
        const EmailEncryptionFailure(EmailEncryptionFailureReason.saveFailed),
      );
    },
  );

  test(
    'export ready state exposes the address but not the archive bytes',
    () async {
      final emailService = MockEmailService();
      final archiveBytes = Uint8List.fromList([1, 2, 3]);
      when(() => emailService.createEmailEncryptionKeyExport()).thenAnswer(
        (_) async => EmailEncryptionKeyExport(
          normalizedAddress: 'user@example.com',
          archiveBytes: archiveBytes,
        ),
      );

      final cubit = EmailEncryptionCubit(emailService: emailService);
      addTearDown(cubit.close);

      await cubit.createExport();
      final state = cubit.state as EmailEncryptionExportReady;
      final bytes = await cubit.exportBytesForSave(state);

      expect(state.props, const ['user@example.com']);
      expect(bytes, same(archiveBytes));
    },
  );

  test(
    'closing during export cancels imex and suppresses export ready',
    () async {
      final emailService = MockEmailService();
      final completer = Completer<EmailEncryptionKeyExport>();
      when(
        () => emailService.createEmailEncryptionKeyExport(),
      ).thenAnswer((_) => completer.future);
      when(
        () => emailService.cancelEmailEncryptionKeyExport(),
      ).thenAnswer((_) async {});

      final cubit = EmailEncryptionCubit(emailService: emailService);
      final states = <EmailEncryptionState>[];
      final subscription = cubit.stream.listen(states.add);
      addTearDown(subscription.cancel);

      final exportFuture = cubit.createExport();
      await Future<void>.delayed(Duration.zero);
      await cubit.close();
      completer.complete(
        EmailEncryptionKeyExport(
          normalizedAddress: 'user@example.com',
          archiveBytes: Uint8List.fromList([1, 2, 3]),
        ),
      );
      await exportFuture;

      expect(states, const [EmailEncryptionExportRunning()]);
      verify(() => emailService.cancelEmailEncryptionKeyExport()).called(1);
    },
  );

  test('activates an existing self key without import or export', () async {
    final emailService = MockEmailService();
    when(() => emailService.activeEncryptionAccountInfo()).thenAnswer(
      (_) async => const EmailEncryptionAccountInfo(
        normalizedAddress: 'alice@example.com',
        deltaAccountId: 1,
        hasSelfKey: true,
      ),
    );

    final cubit = EmailEncryptionCubit(emailService: emailService);
    addTearDown(cubit.close);

    await cubit.activateExistingKey();

    expect(
      cubit.state,
      const EmailEncryptionActivationReady('alice@example.com'),
    );
    verify(() => emailService.activeEncryptionAccountInfo()).called(1);
    verifyNever(() => emailService.createEmailEncryptionKeyExport());
    verifyNever(
      () => emailService.importEmailEncryptionPrivateKey(
        any(),
        expectedFingerprint: any(named: 'expectedFingerprint'),
        allowIdentityMismatch: any(named: 'allowIdentityMismatch'),
      ),
    );
  });

  test(
    'existing-key activation fails when the active account has no self key',
    () async {
      final emailService = MockEmailService();
      when(() => emailService.activeEncryptionAccountInfo()).thenAnswer(
        (_) async => const EmailEncryptionAccountInfo(
          normalizedAddress: 'alice@example.com',
          deltaAccountId: 1,
        ),
      );

      final cubit = EmailEncryptionCubit(emailService: emailService);
      addTearDown(cubit.close);

      await cubit.activateExistingKey();

      expect(
        cubit.state,
        const EmailEncryptionFailure(
          EmailEncryptionFailureReason.noPrivateKeyFound,
        ),
      );
    },
  );

  test(
    'import waits for user confirmation when self-key identity differs',
    () async {
      final emailService = MockEmailService();
      final source = File('/tmp/alice.asc');
      const metadata = EmailOpenPgpKeyMetadata(
        kind: EmailOpenPgpKeyKind.private,
        fingerprint: 'ABC123',
        userIds: ['Other <other@example.com>'],
        hasExpectedAddress: false,
        hasEncryptionCapability: true,
      );
      when(
        () => emailService.inspectEmailEncryptionPrivateKey(any()),
      ).thenAnswer((_) async => metadata);
      when(
        () => emailService.importEmailEncryptionPrivateKey(
          any(),
          expectedFingerprint: 'ABC123',
          allowIdentityMismatch: true,
        ),
      ).thenAnswer(
        (_) async => const EmailEncryptionAccountInfo(
          normalizedAddress: 'alice@example.com',
          deltaAccountId: 1,
        ),
      );

      final cubit = EmailEncryptionCubit(emailService: emailService);
      addTearDown(cubit.close);

      await cubit.importPrivateKey(source);

      expect(
        cubit.state,
        const EmailEncryptionSelfKeyConfirmationRequired(
          path: '/tmp/alice.asc',
          metadata: metadata,
        ),
      );
      verifyNever(
        () => emailService.importEmailEncryptionPrivateKey(
          any(),
          expectedFingerprint: 'ABC123',
          allowIdentityMismatch: true,
        ),
      );

      await cubit.confirmPrivateKeyImport();

      expect(
        cubit.state,
        const EmailEncryptionActivationReady('alice@example.com'),
      );
      verify(
        () => emailService.importEmailEncryptionPrivateKey(
          any(),
          expectedFingerprint: 'ABC123',
          allowIdentityMismatch: true,
        ),
      ).called(1);
    },
  );

  test(
    'cancelled identity confirmation does not import a pending key',
    () async {
      final emailService = MockEmailService();
      const account = EmailEncryptionAccountInfo(
        normalizedAddress: 'alice@example.com',
        deltaAccountId: 1,
      );
      const metadata = EmailOpenPgpKeyMetadata(
        kind: EmailOpenPgpKeyKind.private,
        fingerprint: 'ABC123',
        userIds: ['Other <other@example.com>'],
        hasExpectedAddress: false,
        hasEncryptionCapability: true,
      );
      when(
        () => emailService.inspectEmailEncryptionPrivateKey(any()),
      ).thenAnswer((_) async => metadata);
      when(
        () => emailService.activeEncryptionAccountInfo(),
      ).thenAnswer((_) async => account);

      final cubit = EmailEncryptionCubit(emailService: emailService);
      addTearDown(cubit.close);

      await cubit.importPrivateKey(File('/tmp/alice.asc'));
      await cubit.cancelPrivateKeyImport();

      expect(cubit.state, const EmailEncryptionIdle(account: account));
      verifyNever(
        () => emailService.importEmailEncryptionPrivateKey(
          any(),
          expectedFingerprint: 'ABC123',
          allowIdentityMismatch: true,
        ),
      );
    },
  );
}
