// ignore_for_file: depend_on_referenced_packages

import 'dart:async';

import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/common/search/search_models.dart';
import 'package:axichat/src/contacts/bloc/contacts_cubit.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks.dart';

void main() {
  late MockXmppService xmppService;
  late MockEmailService emailService;
  late StreamController<List<ContactDirectoryEntry>> contactsController;
  late ContactsCubit cubit;

  setUpAll(() {
    registerFallbackValue(<String>[]);
    registerFallbackValue(<Message>[]);
  });

  setUp(() {
    xmppService = MockXmppService();
    emailService = MockEmailService();
    contactsController = StreamController<List<ContactDirectoryEntry>>();
    when(
      () => xmppService.contactDirectoryStream(),
    ).thenAnswer((_) => contactsController.stream);
    cubit = ContactsCubit(xmppService: xmppService, emailService: emailService);
  });

  tearDown(() async {
    await cubit.close();
    await contactsController.close();
    resetMocktailState();
  });

  test('filters, searches, and sorts contacts with favorites pinned', () async {
    contactsController.add(const [
      ContactDirectoryEntry(
        address: 'gamma@example.com',
        hasXmppRoster: true,
        hasEmailContact: false,
        emailNativeIds: <String>[],
        xmppTitle: 'Gamma',
      ),
      ContactDirectoryEntry(
        address: 'alpha@example.com',
        hasXmppRoster: false,
        hasEmailContact: true,
        emailNativeIds: <String>['alpha'],
        emailDisplayName: 'Alpha',
      ),
      ContactDirectoryEntry(
        address: 'beta@example.com',
        hasXmppRoster: true,
        hasEmailContact: true,
        emailNativeIds: <String>['beta'],
        xmppTitle: 'Beta roster',
        emailDisplayName: 'Beta email',
        displayNameOverride: 'Beta local',
        favorited: true,
      ),
    ]);

    await cubit.stream.firstWhere((state) => state.items?.length == 3);

    expect(cubit.state.visibleItems?.map((item) => item.address), [
      'beta@example.com',
      'alpha@example.com',
      'gamma@example.com',
    ]);

    cubit.updateCriteria(
      query: 'local',
      sort: SearchSortOrder.newestFirst,
      filterId: SearchFilterId.all,
    );

    expect(cubit.state.visibleItems?.map((item) => item.address), [
      'beta@example.com',
    ]);

    cubit.updateCriteria(
      query: '',
      sort: SearchSortOrder.oldestFirst,
      filterId: SearchFilterId.email,
    );

    expect(cubit.state.visibleItems?.map((item) => item.address), [
      'beta@example.com',
      'alpha@example.com',
    ]);

    cubit.updateCriteria(
      query: '',
      sort: SearchSortOrder.newestFirst,
      filterId: SearchFilterId.favorites,
    );

    expect(cubit.state.visibleItems?.map((item) => item.address), [
      'beta@example.com',
    ]);
  });

  test('adds XMPP contacts through roster only', () async {
    when(
      () => xmppService.addToRoster(jid: 'alice@example.com', title: 'Alice'),
    ).thenAnswer((_) async {});

    await cubit.addContact(
      address: 'alice@example.com',
      displayName: ' Alice ',
      transport: MessageTransport.xmpp,
    );

    verify(
      () => xmppService.addToRoster(jid: 'alice@example.com', title: 'Alice'),
    ).called(1);
    verifyNever(
      () => xmppService.addManualContact(
        address: any(named: 'address'),
        displayName: any(named: 'displayName'),
      ),
    );
    verifyNever(
      () => emailService.addContactAddress(
        address: any(named: 'address'),
        displayName: any(named: 'displayName'),
      ),
    );
    expect(
      cubit.state.actionState,
      const ContactActionSuccess(
        action: ContactActionType.addContact,
        address: 'alice@example.com',
      ),
    );
  });

  test('reports XMPP add failure without creating a private contact', () async {
    when(
      () => xmppService.addToRoster(jid: 'alice@example.com', title: 'Alice'),
    ).thenThrow(XmppRosterException());

    await cubit.addContact(
      address: 'alice@example.com',
      displayName: 'Alice',
      transport: MessageTransport.xmpp,
    );

    verifyNever(
      () => xmppService.addManualContact(
        address: any(named: 'address'),
        displayName: any(named: 'displayName'),
      ),
    );
    expect(
      cubit.state.actionState,
      const ContactActionFailure(
        action: ContactActionType.addContact,
        address: 'alice@example.com',
        reason: ContactFailureReason.addFailed,
      ),
    );
  });

  test('adds email contacts through email contact service only', () async {
    when(
      () => emailService.addContactAddress(
        address: 'mail@example.com',
        displayName: 'Mail',
      ),
    ).thenAnswer((_) async {});

    await cubit.addContact(
      address: 'mail@example.com',
      displayName: ' Mail ',
      transport: MessageTransport.email,
    );

    verify(
      () => emailService.addContactAddress(
        address: 'mail@example.com',
        displayName: 'Mail',
      ),
    ).called(1);
    verifyNever(
      () => emailService.ensureChatForAddress(
        address: any(named: 'address'),
        displayName: any(named: 'displayName'),
      ),
    );
    verifyNever(
      () => xmppService.addManualContact(
        address: any(named: 'address'),
        displayName: any(named: 'displayName'),
      ),
    );
    verifyNever(
      () => xmppService.addToRoster(
        jid: any(named: 'jid'),
        title: any(named: 'title'),
      ),
    );
    expect(
      cubit.state.actionState,
      const ContactActionSuccess(
        action: ContactActionType.addContact,
        address: 'mail@example.com',
      ),
    );
  });

  test(
    'reports email add failure without creating a private contact',
    () async {
      when(
        () => emailService.addContactAddress(
          address: 'mail@example.com',
          displayName: 'Mail',
        ),
      ).thenThrow(const EmailServiceMissingAddressException());

      await cubit.addContact(
        address: 'mail@example.com',
        displayName: 'Mail',
        transport: MessageTransport.email,
      );

      verifyNever(
        () => xmppService.addManualContact(
          address: any(named: 'address'),
          displayName: any(named: 'displayName'),
        ),
      );
      expect(
        cubit.state.actionState,
        const ContactActionFailure(
          action: ContactActionType.addContact,
          address: 'mail@example.com',
          reason: ContactFailureReason.addFailed,
        ),
      );
    },
  );

  test(
    'removes mixed contacts from roster, email, then private metadata',
    () async {
      const contact = ContactDirectoryEntry(
        address: 'mixed@example.com',
        hasPrivateContact: true,
        hasXmppRoster: true,
        hasEmailContact: true,
        emailNativeIds: <String>['delta_contact_7'],
      );
      when(
        () => xmppService.removeFromRoster(jid: 'mixed@example.com'),
      ).thenAnswer((_) async {});
      when(
        () => emailService.deleteContactsByNativeIds(const <String>[
          'delta_contact_7',
        ]),
      ).thenAnswer((_) async {});
      when(
        () =>
            xmppService.deactivatePrivateContact(address: 'mixed@example.com'),
      ).thenAnswer((_) async {});

      await cubit.removeContact(contact);

      verifyInOrder([
        () => xmppService.removeFromRoster(jid: 'mixed@example.com'),
        () => emailService.deleteContactsByNativeIds(const <String>[
          'delta_contact_7',
        ]),
        () =>
            xmppService.deactivatePrivateContact(address: 'mixed@example.com'),
      ]);
      verifyNever(() => xmppService.deleteChat(jid: any(named: 'jid')));
      verifyNever(() => xmppService.deleteChatMessages(jid: any(named: 'jid')));
      verifyNever(() => emailService.deleteMessages(any()));
      expect(
        cubit.state.actionState,
        const ContactActionSuccess(
          action: ContactActionType.removeContact,
          address: 'mixed@example.com',
        ),
      );
    },
  );

  test('email unavailable prevents mixed contact source removals', () async {
    final noEmailXmppService = MockXmppService();
    final noEmailContactsController =
        StreamController<List<ContactDirectoryEntry>>();
    when(
      () => noEmailXmppService.contactDirectoryStream(),
    ).thenAnswer((_) => noEmailContactsController.stream);
    final noEmailCubit = ContactsCubit(xmppService: noEmailXmppService);
    addTearDown(noEmailCubit.close);
    addTearDown(noEmailContactsController.close);
    const contact = ContactDirectoryEntry(
      address: 'mixed@example.com',
      hasPrivateContact: true,
      hasXmppRoster: true,
      hasEmailContact: true,
      emailNativeIds: <String>['delta_contact_7'],
    );

    await noEmailCubit.removeContact(contact);

    verifyNever(
      () => noEmailXmppService.removeFromRoster(jid: any(named: 'jid')),
    );
    verifyNever(
      () => noEmailXmppService.deactivatePrivateContact(
        address: any(named: 'address'),
      ),
    );
    expect(
      noEmailCubit.state.actionState,
      const ContactActionFailure(
        action: ContactActionType.removeContact,
        address: 'mixed@example.com',
        reason: ContactFailureReason.unavailable,
      ),
    );
  });

  test('remove failure stops later source removals', () async {
    const contact = ContactDirectoryEntry(
      address: 'mixed@example.com',
      hasPrivateContact: true,
      hasXmppRoster: true,
      hasEmailContact: true,
      emailNativeIds: <String>['delta_contact_7'],
    );
    when(
      () => xmppService.removeFromRoster(jid: 'mixed@example.com'),
    ).thenAnswer((_) async {});
    when(
      () => emailService.deleteContactsByNativeIds(const <String>[
        'delta_contact_7',
      ]),
    ).thenThrow(const EmailServiceMissingAddressException());

    await cubit.removeContact(contact);

    verify(
      () => xmppService.removeFromRoster(jid: 'mixed@example.com'),
    ).called(1);
    verify(
      () => emailService.deleteContactsByNativeIds(const <String>[
        'delta_contact_7',
      ]),
    ).called(1);
    verifyNever(
      () =>
          xmppService.deactivatePrivateContact(address: any(named: 'address')),
    );
    expect(
      cubit.state.actionState,
      const ContactActionFailure(
        action: ContactActionType.removeContact,
        address: 'mixed@example.com',
        reason: ContactFailureReason.removeFailed,
      ),
    );
  });

  test(
    'removes private-only contacts by deactivating private metadata',
    () async {
      final contact = ContactDirectoryEntry(
        address: 'private@example.com',
        hasPrivateContact: true,
        hasXmppRoster: false,
        hasEmailContact: false,
        emailNativeIds: const <String>[],
        favorited: true,
        folderCollectionId: 'Projects',
        detailFields: [
          ContactDetailFieldEntry(
            fieldId: 'note',
            kind: ContactDetailFieldKind.note,
            value: 'Important',
            sortOrder: 0,
            active: true,
            updatedAt: DateTime.utc(2026),
          ),
        ],
      );
      when(
        () => xmppService.deactivatePrivateContact(
          address: 'private@example.com',
        ),
      ).thenAnswer((_) async {});

      await cubit.removeContact(contact);

      verify(
        () => xmppService.deactivatePrivateContact(
          address: 'private@example.com',
        ),
      ).called(1);
      verifyNever(() => xmppService.removeFromRoster(jid: any(named: 'jid')));
      verifyNever(() => emailService.deleteContactsByNativeIds(any()));
      expect(
        cubit.state.actionState,
        const ContactActionSuccess(
          action: ContactActionType.removeContact,
          address: 'private@example.com',
        ),
      );
    },
  );

  test('toggles favorite preference through the service', () async {
    const contact = ContactDirectoryEntry(
      address: 'alpha@example.com',
      hasXmppRoster: false,
      hasEmailContact: true,
      emailNativeIds: <String>['alpha'],
    );
    when(
      () => xmppService.setContactFavorited(
        address: 'alpha@example.com',
        favorited: true,
      ),
    ).thenAnswer((_) async {});

    await cubit.setFavorited(contact: contact, favorited: true);

    verify(
      () => xmppService.setContactFavorited(
        address: 'alpha@example.com',
        favorited: true,
      ),
    ).called(1);
    expect(
      cubit.state.actionState,
      const ContactActionSuccess(
        action: ContactActionType.favorite,
        address: 'alpha@example.com',
      ),
    );
  });

  test('updates favorite state immediately while preference saves', () async {
    const contact = ContactDirectoryEntry(
      address: 'alpha@example.com',
      hasXmppRoster: false,
      hasEmailContact: true,
      emailNativeIds: <String>['alpha'],
    );
    final saveCompleter = Completer<void>();
    contactsController.add(const [contact]);
    await cubit.stream.firstWhere((state) => state.items?.length == 1);
    when(
      () => xmppService.setContactFavorited(
        address: 'alpha@example.com',
        favorited: true,
      ),
    ).thenAnswer((_) => saveCompleter.future);

    final save = cubit.setFavorited(contact: contact, favorited: true);

    expect(cubit.state.visibleItems?.single.favorited, isTrue);
    saveCompleter.complete();
    await save;
  });

  test('restores favorite state when preference save fails', () async {
    const contact = ContactDirectoryEntry(
      address: 'alpha@example.com',
      hasXmppRoster: false,
      hasEmailContact: true,
      emailNativeIds: <String>['alpha'],
    );
    contactsController.add(const [contact]);
    await cubit.stream.firstWhere((state) => state.items?.length == 1);
    when(
      () => xmppService.setContactFavorited(
        address: 'alpha@example.com',
        favorited: true,
      ),
    ).thenThrow(XmppContactDirectoryException());

    await cubit.setFavorited(contact: contact, favorited: true);

    expect(cubit.state.visibleItems?.single.favorited, isFalse);
    expect(cubit.state.actionState, isA<ContactActionFailure>());
  });

  test('renames contacts with XMPP roster sync enabled when present', () async {
    const contact = ContactDirectoryEntry(
      address: 'alpha@example.com',
      hasXmppRoster: true,
      hasEmailContact: true,
      emailNativeIds: <String>['alpha'],
    );
    when(
      () => xmppService.setContactDisplayNameOverride(
        address: 'alpha@example.com',
        displayName: 'Alice',
      ),
    ).thenAnswer((_) async {});
    when(
      () => xmppService.renameRosterContact(
        jid: 'alpha@example.com',
        title: 'Alice',
      ),
    ).thenAnswer((_) async {});

    await cubit.renameContact(contact: contact, displayName: ' Alice ');

    verify(
      () => xmppService.setContactDisplayNameOverride(
        address: 'alpha@example.com',
        displayName: 'Alice',
      ),
    ).called(1);
    verify(
      () => xmppService.renameRosterContact(
        jid: 'alpha@example.com',
        title: 'Alice',
      ),
    ).called(1);
    expect(
      cubit.state.actionState,
      const ContactActionSuccess(
        action: ContactActionType.rename,
        address: 'alpha@example.com',
      ),
    );
  });

  test('keeps local rename success when XMPP roster sync fails', () async {
    const contact = ContactDirectoryEntry(
      address: 'alpha@example.com',
      hasXmppRoster: true,
      hasEmailContact: false,
      emailNativeIds: <String>[],
    );
    when(
      () => xmppService.setContactDisplayNameOverride(
        address: 'alpha@example.com',
        displayName: 'Alice',
      ),
    ).thenAnswer((_) async {});
    when(
      () => xmppService.renameRosterContact(
        jid: 'alpha@example.com',
        title: 'Alice',
      ),
    ).thenThrow(XmppRosterException());

    await cubit.renameContact(contact: contact, displayName: 'Alice');

    expect(
      cubit.state.actionState,
      const ContactActionSuccess(
        action: ContactActionType.rename,
        address: 'alpha@example.com',
      ),
    );
  });

  test('resets local display name override without roster sync', () async {
    const contact = ContactDirectoryEntry(
      address: 'alpha@example.com',
      hasXmppRoster: true,
      hasEmailContact: true,
      emailNativeIds: <String>['alpha'],
      displayNameOverride: 'Alice',
    );
    when(
      () => xmppService.setContactDisplayNameOverride(
        address: 'alpha@example.com',
        displayName: null,
      ),
    ).thenAnswer((_) async {});

    await cubit.resetContactDisplayName(contact: contact);

    verify(
      () => xmppService.setContactDisplayNameOverride(
        address: 'alpha@example.com',
        displayName: null,
      ),
    ).called(1);
    verifyNever(
      () => xmppService.renameRosterContact(
        jid: any(named: 'jid'),
        title: any(named: 'title'),
      ),
    );
    expect(
      cubit.state.actionState,
      const ContactActionSuccess(
        action: ContactActionType.resetRename,
        address: 'alpha@example.com',
      ),
    );
  });

  test('sets contact folder rule through the service', () async {
    const contact = ContactDirectoryEntry(
      address: 'alpha@example.com',
      hasXmppRoster: false,
      hasEmailContact: true,
      emailNativeIds: <String>['alpha'],
    );
    when(
      () => xmppService.setContactFolderRule(
        address: 'alpha@example.com',
        collectionId: 'Projects',
      ),
    ).thenAnswer((_) async {});

    await cubit.setContactFolderRule(
      contact: contact,
      collectionId: ' Projects ',
    );

    verify(
      () => xmppService.setContactFolderRule(
        address: 'alpha@example.com',
        collectionId: 'Projects',
      ),
    ).called(1);
    expect(
      cubit.state.actionState,
      const ContactActionSuccess(
        action: ContactActionType.setFolderRule,
        address: 'alpha@example.com',
        collectionId: 'Projects',
      ),
    );
  });

  test('keeps confirmed folder rule state while preference saves', () async {
    const contact = ContactDirectoryEntry(
      address: 'alpha@example.com',
      hasXmppRoster: false,
      hasEmailContact: true,
      emailNativeIds: <String>['alpha'],
    );
    final saveCompleter = Completer<void>();
    contactsController.add(const [contact]);
    await cubit.stream.firstWhere((state) => state.items?.length == 1);
    when(
      () => xmppService.setContactFolderRule(
        address: 'alpha@example.com',
        collectionId: 'Projects',
      ),
    ).thenAnswer((_) => saveCompleter.future);

    final save = cubit.setContactFolderRule(
      contact: contact,
      collectionId: 'Projects',
    );

    expect(cubit.state.visibleItems?.single.folderCollectionId, isNull);
    saveCompleter.complete();
    await save;
  });

  test('clears contact folder rule through the service', () async {
    const contact = ContactDirectoryEntry(
      address: 'alpha@example.com',
      hasXmppRoster: false,
      hasEmailContact: true,
      emailNativeIds: <String>['alpha'],
      folderCollectionId: 'Projects',
    );
    when(
      () => xmppService.clearContactFolderRule(address: 'alpha@example.com'),
    ).thenAnswer((_) async {});

    await cubit.clearContactFolderRule(contact: contact);

    verify(
      () => xmppService.clearContactFolderRule(address: 'alpha@example.com'),
    ).called(1);
    expect(
      cubit.state.actionState,
      const ContactActionSuccess(
        action: ContactActionType.clearFolderRule,
        address: 'alpha@example.com',
        collectionId: 'Projects',
      ),
    );
  });
}
