// ignore_for_file: depend_on_referenced_packages

import 'dart:async';

import 'package:axichat/src/common/search/search_models.dart';
import 'package:axichat/src/contacts/bloc/contacts_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks.dart';

void main() {
  late MockXmppService xmppService;
  late StreamController<List<ContactDirectoryEntry>> contactsController;
  late ContactsCubit cubit;

  setUp(() {
    xmppService = MockXmppService();
    contactsController = StreamController<List<ContactDirectoryEntry>>();
    when(
      () => xmppService.contactDirectoryStream(),
    ).thenAnswer((_) => contactsController.stream);
    cubit = ContactsCubit(xmppService: xmppService);
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

  test(
    'updates folder rule state immediately while preference saves',
    () async {
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

      expect(cubit.state.visibleItems?.single.folderCollectionId, 'Projects');
      saveCompleter.complete();
      await save;
    },
  );

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
