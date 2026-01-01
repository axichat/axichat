import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

const String _oauthSecurityModeSsl = 'ssl';
const String _oauthSecurityModeStartTls = 'starttls';
const int _oauthCodeVerifierBytes = 32;
const int _oauthStateBytes = 16;

const String _gmailClientIdEnvKey = 'AXI_GMAIL_OAUTH_CLIENT_ID';
const String _gmailClientSecretEnvKey = 'AXI_GMAIL_OAUTH_CLIENT_SECRET';
const String _outlookClientIdEnvKey = 'AXI_OUTLOOK_OAUTH_CLIENT_ID';
const String _outlookClientSecretEnvKey = 'AXI_OUTLOOK_OAUTH_CLIENT_SECRET';
const String _yahooClientIdEnvKey = 'AXI_YAHOO_OAUTH_CLIENT_ID';
const String _yahooClientSecretEnvKey = 'AXI_YAHOO_OAUTH_CLIENT_SECRET';

const String _oauthClientIdMissing = '';
const String _oauthClientSecretMissing = '';

const String _gmailAuthEndpoint =
    'https://accounts.google.com/o/oauth2/v2/auth';
const String _gmailTokenEndpoint = 'https://oauth2.googleapis.com/token';
const String _outlookAuthEndpoint =
    'https://login.microsoftonline.com/common/oauth2/v2.0/authorize';
const String _outlookTokenEndpoint =
    'https://login.microsoftonline.com/common/oauth2/v2.0/token';
const String _yahooAuthEndpoint =
    'https://api.login.yahoo.com/oauth2/request_auth';
const String _yahooTokenEndpoint =
    'https://api.login.yahoo.com/oauth2/get_token';

const List<String> _gmailDomains = <String>[
  'gmail.com',
  'googlemail.com',
];
const List<String> _outlookDomains = <String>[
  'outlook.com',
  'hotmail.com',
  'live.com',
];
const List<String> _yahooDomains = <String>[
  'yahoo.com',
  'ymail.com',
  'rocketmail.com',
];

const String _gmailImapHost = 'imap.gmail.com';
const String _gmailSmtpHost = 'smtp.gmail.com';
const String _outlookImapHost = 'outlook.office365.com';
const String _outlookSmtpHost = 'smtp.office365.com';
const String _yahooImapHost = 'imap.mail.yahoo.com';
const String _yahooSmtpHost = 'smtp.mail.yahoo.com';

const int _oauthImapPort = 993;
const int _oauthSmtpPort = 587;

const List<String> _gmailScopes = <String>[
  'https://mail.google.com/',
];
const List<String> _outlookScopes = <String>[
  'https://outlook.office.com/IMAP.AccessAsUser.All',
  'https://outlook.office.com/SMTP.Send',
  'offline_access',
];
const List<String> _yahooScopes = <String>[
  'mail-r',
  'mail-w',
];

const String _oauthResponseType = 'code';
const String _oauthCodeChallengeMethod = 'S256';
const String _oauthAccessType = 'offline';
const String _oauthPromptConsent = 'consent';
const String _oauthPromptSelectAccount = 'select_account';

enum EmailOauthProvider {
  gmail,
  outlook,
  yahoo,
}

extension EmailOauthProviderDetails on EmailOauthProvider {
  String get storageValue => name;

  String get clientId => switch (this) {
        EmailOauthProvider.gmail => const String.fromEnvironment(
            _gmailClientIdEnvKey,
            defaultValue: _oauthClientIdMissing,
          ),
        EmailOauthProvider.outlook => const String.fromEnvironment(
            _outlookClientIdEnvKey,
            defaultValue: _oauthClientIdMissing,
          ),
        EmailOauthProvider.yahoo => const String.fromEnvironment(
            _yahooClientIdEnvKey,
            defaultValue: _oauthClientIdMissing,
          ),
      };

  String get clientSecret => switch (this) {
        EmailOauthProvider.gmail => const String.fromEnvironment(
            _gmailClientSecretEnvKey,
            defaultValue: _oauthClientSecretMissing,
          ),
        EmailOauthProvider.outlook => const String.fromEnvironment(
            _outlookClientSecretEnvKey,
            defaultValue: _oauthClientSecretMissing,
          ),
        EmailOauthProvider.yahoo => const String.fromEnvironment(
            _yahooClientSecretEnvKey,
            defaultValue: _oauthClientSecretMissing,
          ),
      };

  bool get isConfigured => clientId.isNotEmpty;

  String get authorizationEndpoint => switch (this) {
        EmailOauthProvider.gmail => _gmailAuthEndpoint,
        EmailOauthProvider.outlook => _outlookAuthEndpoint,
        EmailOauthProvider.yahoo => _yahooAuthEndpoint,
      };

  String get tokenEndpoint => switch (this) {
        EmailOauthProvider.gmail => _gmailTokenEndpoint,
        EmailOauthProvider.outlook => _outlookTokenEndpoint,
        EmailOauthProvider.yahoo => _yahooTokenEndpoint,
      };

  List<String> get scopes => switch (this) {
        EmailOauthProvider.gmail => _gmailScopes,
        EmailOauthProvider.outlook => _outlookScopes,
        EmailOauthProvider.yahoo => _yahooScopes,
      };

  Map<String, String> get extraAuthorizationParams => switch (this) {
        EmailOauthProvider.gmail => const <String, String>{
            'access_type': _oauthAccessType,
            'prompt': _oauthPromptConsent,
          },
        EmailOauthProvider.outlook => const <String, String>{
            'prompt': _oauthPromptSelectAccount,
          },
        EmailOauthProvider.yahoo => const <String, String>{},
      };

  String get imapHost => switch (this) {
        EmailOauthProvider.gmail => _gmailImapHost,
        EmailOauthProvider.outlook => _outlookImapHost,
        EmailOauthProvider.yahoo => _yahooImapHost,
      };

  String get smtpHost => switch (this) {
        EmailOauthProvider.gmail => _gmailSmtpHost,
        EmailOauthProvider.outlook => _outlookSmtpHost,
        EmailOauthProvider.yahoo => _yahooSmtpHost,
      };

  int get imapPort => _oauthImapPort;
  int get smtpPort => _oauthSmtpPort;

  String get imapSecurity => _oauthSecurityModeSsl;
  String get smtpSecurity => _oauthSecurityModeStartTls;
}

EmailOauthProvider? emailOauthProviderForDomain(String domain) {
  final String normalized = domain.trim().toLowerCase();
  if (_gmailDomains.contains(normalized)) {
    return EmailOauthProvider.gmail;
  }
  if (_outlookDomains.contains(normalized)) {
    return EmailOauthProvider.outlook;
  }
  if (_yahooDomains.contains(normalized)) {
    return EmailOauthProvider.yahoo;
  }
  return null;
}

EmailOauthProvider? emailOauthProviderForAddress(String address) {
  final int atIndex = address.indexOf('@');
  if (atIndex < 0 || atIndex == address.length - 1) {
    return null;
  }
  final String domain = address.substring(atIndex + 1);
  return emailOauthProviderForDomain(domain);
}

EmailOauthProvider? emailOauthProviderFromStorage(String value) {
  final String normalized = value.trim();
  if (normalized.isEmpty) {
    return null;
  }
  return EmailOauthProvider.values.cast<EmailOauthProvider?>().firstWhere(
      (provider) => provider?.storageValue == normalized,
      orElse: () => null);
}

class EmailOauthAuthorization {
  const EmailOauthAuthorization({
    required this.provider,
    required this.authorizationUrl,
    required this.redirectUri,
    required this.codeVerifier,
    required this.state,
  });

  final EmailOauthProvider provider;
  final String authorizationUrl;
  final String redirectUri;
  final String codeVerifier;
  final String state;
}

class EmailOauthTokens {
  const EmailOauthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
}

EmailOauthAuthorization? buildEmailOauthAuthorization({
  required String address,
  required String redirectUri,
}) {
  final EmailOauthProvider? provider = emailOauthProviderForAddress(address);
  if (provider == null || !provider.isConfigured) {
    return null;
  }
  final String state = _randomToken(_oauthStateBytes);
  final String codeVerifier = _randomToken(_oauthCodeVerifierBytes);
  final String codeChallenge = _codeChallenge(codeVerifier);
  final String scope = provider.scopes.join(' ');
  final Map<String, String> query = <String, String>{
    'response_type': _oauthResponseType,
    'client_id': provider.clientId,
    'redirect_uri': redirectUri,
    'scope': scope,
    'state': state,
    'code_challenge': codeChallenge,
    'code_challenge_method': _oauthCodeChallengeMethod,
    ...provider.extraAuthorizationParams,
  };
  final Uri uri = Uri.parse(provider.authorizationEndpoint).replace(
    queryParameters: query,
  );
  return EmailOauthAuthorization(
    provider: provider,
    authorizationUrl: uri.toString(),
    redirectUri: redirectUri,
    codeVerifier: codeVerifier,
    state: state,
  );
}

String _randomToken(int lengthBytes) {
  final Random rng = Random.secure();
  final List<int> bytes = List<int>.generate(
    lengthBytes,
    (_) => rng.nextInt(256),
    growable: false,
  );
  return base64Url.encode(bytes).replaceAll('=', '');
}

String _codeChallenge(String codeVerifier) {
  final List<int> bytes = utf8.encode(codeVerifier);
  final Digest digest = sha256.convert(bytes);
  return base64Url.encode(digest.bytes).replaceAll('=', '');
}
