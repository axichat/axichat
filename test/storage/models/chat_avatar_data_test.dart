import 'package:axichat/src/avatar/avatar_presentation.dart';
import 'package:axichat/src/storage/models/chat_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final baseChat = Chat(
    jid: 'peer@axi.im',
    title: 'Peer',
    type: ChatType.chat,
    lastChangeTimestamp: DateTime(2024, 1, 1),
  );

  test('avatar data uses self avatar path and loading for self chats', () {
    final avatarData = baseChat.avatarPresentation(
      selfJid: 'peer@axi.im',
      selfAvatarPath: '/avatars/self.enc',
      selfAvatarLoading: true,
    );

    expect(avatarData.kind, AvatarKind.avatar);
    expect(avatarData.identifier, 'Peer');
    expect(avatarData.colorSeed, 'peer@axi.im');
    expect(avatarData.avatarPath, '/avatars/self.enc');
    expect(avatarData.loading, isTrue);
  });

  test('avatar data prefers explicit path overrides over chat paths', () {
    final chat = baseChat.copyWith(
      avatarPath: '  /avatars/primary.enc  ',
      contactAvatarPath: '/avatars/fallback.enc',
    );

    final avatarData = chat.avatarPresentation(
      avatarPathOverride: ' /avatars/override.enc ',
    );

    expect(avatarData.kind, AvatarKind.avatar);
    expect(avatarData.avatarPath, '/avatars/override.enc');
  });

  test('avatar data uses the app icon for the welcome thread', () {
    final welcomeChat = Chat(
      jid: 'axichat@welcome.axichat.invalid',
      title: 'Welcome',
      type: ChatType.chat,
      lastChangeTimestamp: DateTime(2024, 1, 1),
    );

    expect(welcomeChat.avatarPresentation().kind, AvatarKind.appIcon);
  });
}
