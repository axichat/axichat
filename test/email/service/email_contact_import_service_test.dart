// ignore_for_file: depend_on_referenced_packages

import 'dart:io';

import 'package:axichat/src/email/service/email_contact_import_service.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockEmailService emailService;
  late Directory tempDir;

  setUp(() async {
    emailService = MockEmailService();
    tempDir = await Directory.systemTemp.createTemp(
      'email_contact_import_service',
    );

    when(() => emailService.hasActiveSession).thenReturn(true);
    when(
      () => emailService.createContactAddress(
        address: any(named: 'address'),
        displayName: any(named: 'displayName'),
        fromAddress: any(named: 'fromAddress'),
      ),
    ).thenAnswer((_) async {});
    when(() => emailService.syncContactsFromCore()).thenAnswer((_) async {});
  });

  tearDown(() async {
    resetMocktailState();
    await tempDir.delete(recursive: true);
  });

  test('imports contacts with one sync after the batch completes', () async {
    final file = File('${tempDir.path}/contacts.csv');
    await file.writeAsString(
      'Name,Email\n'
      'Alice,alice@example.com\n'
      'Bob,bob@example.com\n',
    );
    final service = EmailContactImportService(emailService: emailService);

    final summary = await service.importContacts(
      file: file,
      format: EmailContactImportFormat.genericCsv,
    );

    expect(summary.imported, 2);
    expect(summary.failed, 0);
    verify(
      () => emailService.createContactAddress(
        address: 'alice@example.com',
        displayName: 'Alice',
        fromAddress: null,
      ),
    ).called(1);
    verify(
      () => emailService.createContactAddress(
        address: 'bob@example.com',
        displayName: 'Bob',
        fromAddress: null,
      ),
    ).called(1);
    verify(() => emailService.syncContactsFromCore()).called(1);
  });

  test(
    'throws import failure when final sync fails after creating contacts',
    () async {
      final file = File('${tempDir.path}/contacts.csv');
      await file.writeAsString(
        'Name,Email\n'
        'Alice,alice@example.com\n',
      );
      final service = EmailContactImportService(emailService: emailService);

      when(
        () => emailService.syncContactsFromCore(),
      ).thenThrow(const EmailServiceStoppingException());

      await expectLater(
        () => service.importContacts(
          file: file,
          format: EmailContactImportFormat.genericCsv,
        ),
        throwsA(isA<EmailContactImportFailedException>()),
      );

      verify(
        () => emailService.createContactAddress(
          address: 'alice@example.com',
          displayName: 'Alice',
          fromAddress: null,
        ),
      ).called(1);
      verify(() => emailService.syncContactsFromCore()).called(1);
    },
  );
}
