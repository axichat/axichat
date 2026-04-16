// ignore_for_file: depend_on_referenced_packages

import 'dart:io';

import 'package:axichat/src/profile/bloc/profile_export_cubit.dart';
import 'package:axichat/src/profile/utils/contact_exporter.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.temporaryPath);

  final String temporaryPath;

  @override
  Future<String?> getTemporaryPath() async => temporaryPath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockXmppService xmppService;
  late Directory tempDir;
  late PathProviderPlatform originalPlatform;

  const labels = ContactExportLabels(
    csvHeaderName: 'Name',
    csvHeaderAddress: 'Address',
    fallbackLabel: 'contacts',
  );

  setUp(() async {
    xmppService = MockXmppService();
    tempDir = await Directory.systemTemp.createTemp('profile_export_cubit');
    originalPlatform = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
  });

  tearDown(() async {
    PathProviderPlatform.instance = originalPlatform;
    await tempDir.delete(recursive: true);
  });

  test('exportEmailContacts uses the unified contacts snapshot', () async {
    when(() => xmppService.loadContactsSnapshot()).thenAnswer(
      (_) async => [
        const ContactDirectoryEntry(
          address: 'xmpp-only@example.com',
          hasXmppRoster: true,
          hasEmailContact: false,
          emailNativeIds: <String>[],
          xmppTitle: 'XMPP Only',
        ),
        const ContactDirectoryEntry(
          address: 'email-only@example.com',
          hasXmppRoster: false,
          hasEmailContact: true,
          emailNativeIds: <String>['dc-1'],
          emailDisplayName: 'Email Only',
        ),
        const ContactDirectoryEntry(
          address: 'both@example.com',
          hasXmppRoster: true,
          hasEmailContact: true,
          emailNativeIds: <String>['dc-2'],
          xmppTitle: 'Both Contact',
          emailDisplayName: 'Both Email',
        ),
      ],
    );
    final cubit = ProfileExportCubit(xmppService: xmppService);
    addTearDown(cubit.close);

    final result = await cubit.exportEmailContacts(
      ContactExportFormat.vcard,
      labels,
    );

    expect(result.outcome.isSuccess, isTrue);
    expect(result.itemCount, 2);
    final file = result.file;
    expect(file, isNotNull);
    final body = await file!.readAsString();
    expect(body, contains('EMAIL:email-only@example.com'));
    expect(body, contains('EMAIL:both@example.com'));
    expect(body, contains('FN:Email Only'));
    expect(body, contains('FN:Both Email'));
    expect(body, isNot(contains('FN:Both Contact')));
    expect(body, isNot(contains('EMAIL:xmpp-only@example.com')));
    expect(p.basename(file.path), startsWith('email-contacts-'));
  });

  test('exportXmppContacts uses the unified contacts snapshot', () async {
    when(() => xmppService.loadContactsSnapshot()).thenAnswer(
      (_) async => [
        const ContactDirectoryEntry(
          address: 'xmpp-only@example.com',
          hasXmppRoster: true,
          hasEmailContact: false,
          emailNativeIds: <String>[],
          xmppTitle: 'XMPP Only',
        ),
        const ContactDirectoryEntry(
          address: 'email-only@example.com',
          hasXmppRoster: false,
          hasEmailContact: true,
          emailNativeIds: <String>['dc-1'],
          emailDisplayName: 'Email Only',
        ),
        const ContactDirectoryEntry(
          address: 'both@example.com',
          hasXmppRoster: true,
          hasEmailContact: true,
          emailNativeIds: <String>['dc-2'],
          xmppTitle: 'Both Contact',
          emailDisplayName: 'Both Email',
        ),
      ],
    );
    final cubit = ProfileExportCubit(xmppService: xmppService);
    addTearDown(cubit.close);

    final result = await cubit.exportXmppContacts(
      ContactExportFormat.vcard,
      labels,
    );

    expect(result.outcome.isSuccess, isTrue);
    expect(result.itemCount, 2);
    final file = result.file;
    expect(file, isNotNull);
    final body = await file!.readAsString();
    expect(body, contains('IMPP:xmpp:xmpp-only@example.com'));
    expect(body, contains('IMPP:xmpp:both@example.com'));
    expect(body, contains('FN:Both Contact'));
    expect(body, isNot(contains('FN:Both Email')));
    expect(body, isNot(contains('email-only@example.com')));
    expect(p.basename(file.path), startsWith('xmpp-contacts-'));
  });
}
