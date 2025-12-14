import 'package:axichat/src/storage/credential_store.dart';

class AuthBootstrap {
  const AuthBootstrap({required this.hasStoredLoginCredentials});

  final bool hasStoredLoginCredentials;
}

const _rememberMeChoiceKeyName = 'remember_me_choice';
const _jidKeyName = 'jid';
const _passwordKeyName = 'password';
const _passwordPreHashedKeyName = 'password_prehashed_v1';

Future<bool> resolveHasStoredLoginCredentials(
  CredentialStore credentialStore,
) async {
  final rememberMeChoiceKey = CredentialStore.registerKey(
    _rememberMeChoiceKeyName,
  );
  final rememberMeRaw = await credentialStore.read(key: rememberMeChoiceKey);
  final rememberMe = _parseBoolOrNull(rememberMeRaw) ?? true;
  if (!rememberMe) return false;

  final jidKey = CredentialStore.registerKey(_jidKeyName);
  final passwordKey = CredentialStore.registerKey(_passwordKeyName);
  final passwordPreHashedKey = CredentialStore.registerKey(
    _passwordPreHashedKeyName,
  );

  final storedJid = await credentialStore.read(key: jidKey);
  final storedPassword = await credentialStore.read(key: passwordKey);
  final storedPasswordPreHashed = _parseBoolOrNull(
    await credentialStore.read(key: passwordPreHashedKey),
  );

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
