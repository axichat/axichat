// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/storage/credential_store.dart';

class AuthBootstrap {
  const AuthBootstrap({required this.hasStoredLoginCredentials});

  final bool hasStoredLoginCredentials;
}

const _rememberMeChoiceKeyName = 'remember_me_choice';
const _jidKeyName = 'jid';
const _passwordKeyName = 'password';
const _passwordPreHashedKeyName = 'password_prehashed_v1';
const bool _defaultRememberMeChoice = true;

Future<bool> resolveHasStoredLoginCredentials(
  CredentialStore credentialStore,
) async {
  final RegisteredCredentialKey rememberMeChoiceKey =
      CredentialStore.registerKey(
    _rememberMeChoiceKeyName,
  );
  final Future<String?> rememberMeFuture =
      credentialStore.read(key: rememberMeChoiceKey);
  final String? rememberMeRaw = await rememberMeFuture;
  final bool rememberMe =
      _parseBoolOrNull(rememberMeRaw) ?? _defaultRememberMeChoice;
  if (!rememberMe) return false;

  final RegisteredCredentialKey jidKey =
      CredentialStore.registerKey(_jidKeyName);
  final RegisteredCredentialKey passwordKey =
      CredentialStore.registerKey(_passwordKeyName);
  final RegisteredCredentialKey passwordPreHashedKey =
      CredentialStore.registerKey(
    _passwordPreHashedKeyName,
  );

  final Future<String?> storedJidFuture = credentialStore.read(key: jidKey);
  final Future<String?> storedPasswordFuture =
      credentialStore.read(key: passwordKey);
  final Future<String?> storedPasswordPreHashedFuture =
      credentialStore.read(key: passwordPreHashedKey);

  final String? storedJid = await storedJidFuture;
  final String? storedPassword = await storedPasswordFuture;
  final String? storedPasswordPreHashedRaw =
      await storedPasswordPreHashedFuture;
  final bool? storedPasswordPreHashed =
      _parseBoolOrNull(storedPasswordPreHashedRaw);

  return storedJid != null &&
      storedPassword != null &&
      storedPasswordPreHashed != null;
}

bool? _parseBoolOrNull(String? raw) {
  if (raw == null) return null;
  final normalized = raw.toLowerCase().trim();
  if (normalized == 'true') return true;
  if (normalized == 'false') return false;
  return null;
}
