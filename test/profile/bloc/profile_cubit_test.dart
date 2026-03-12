import 'dart:async';

import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks.dart';

void main() {
  late MockXmppService xmppService;
  late StreamController<bool> selfAvatarHydratingController;

  setUp(() {
    xmppService = MockXmppService();
    selfAvatarHydratingController = StreamController<bool>.broadcast();
    when(() => xmppService.myJid).thenReturn(null);
    when(() => xmppService.resource).thenReturn(null);
    when(() => xmppService.username).thenReturn(null);
    when(() => xmppService.cachedSelfAvatar).thenReturn(null);
    when(() => xmppService.selfAvatarHydrating).thenReturn(false);
    when(
      () => xmppService.selfAvatarHydratingStream,
    ).thenAnswer((_) => selfAvatarHydratingController.stream);
    when(
      () => xmppService.selfAvatarStream,
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => xmppService.storedConversationMessageCountStream(),
    ).thenAnswer((_) => const Stream<int>.empty());
    when(() => xmppService.getOwnAvatar()).thenAnswer((_) async => null);
  });

  tearDown(() async {
    await selfAvatarHydratingController.close();
  });

  test('syncSessionIdentity refreshes jid, resource, and username.', () async {
    final cubit = ProfileCubit(xmppService: xmppService);
    when(() => xmppService.myJid).thenReturn('newuser@axi.im');
    when(() => xmppService.resource).thenReturn('phone');
    when(() => xmppService.username).thenReturn('newuser');

    cubit.syncSessionIdentity();

    expect(cubit.state.jid, equals('newuser@axi.im'));
    expect(cubit.state.resource, equals('phone'));
    expect(cubit.state.username, equals('newuser'));
    await cubit.close();
  });

  test('clearSessionIdentity clears visible profile identity.', () async {
    when(() => xmppService.myJid).thenReturn('newuser@axi.im');
    when(() => xmppService.resource).thenReturn('phone');
    when(() => xmppService.username).thenReturn('newuser');
    final cubit = ProfileCubit(xmppService: xmppService);

    cubit.clearSessionIdentity();

    expect(cubit.state.jid, isEmpty);
    expect(cubit.state.resource, isEmpty);
    expect(cubit.state.username, isEmpty);
    expect(cubit.state.storedConversationMessageCount, equals(0));
    await cubit.close();
  });

  test('mirrors self avatar hydrating state from the xmpp service.', () async {
    when(() => xmppService.myJid).thenReturn('newuser@axi.im');
    when(() => xmppService.selfAvatarHydrating).thenReturn(true);
    final cubit = ProfileCubit(xmppService: xmppService);

    expect(cubit.state.avatarHydrating, isTrue);

    selfAvatarHydratingController.add(false);
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.avatarHydrating, isFalse);
    await cubit.close();
  });
}
