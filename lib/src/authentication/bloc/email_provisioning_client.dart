// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:convert';
import 'dart:io';

import 'package:axichat/src/common/address_tools.dart';
import 'package:axichat/src/common/security_flags.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:logging/logging.dart';

class EmailProvisioningCredentials {
  const EmailProvisioningCredentials({
    required this.email,
    required this.password,
  });

  final String email;
  final String password;
}

enum EmailProvisioningApiErrorCode {
  authFailed('auth_failed'),
  invalidCode('invalid_code'),
  challengeExpired('challenge_expired'),
  challengeFailed('challenge_failed'),
  rateLimited('rate_limited'),
  recoveryNotConfigured('recovery_not_configured'),
  repairRequired('repair_required'),
  idempotencyConflict('idempotency_conflict'),
  invalidResetToken('invalid_reset_token'),
  resetTokenExpired('reset_token_expired'),
  xmppServiceUnavailable('xmpp_service_unavailable'),
  unknown('unknown');

  const EmailProvisioningApiErrorCode(this.wireValue);

  final String wireValue;

  static EmailProvisioningApiErrorCode fromWire(String? value) {
    final normalized = value?.trim().toLowerCase();
    for (final code in values) {
      if (code.wireValue == normalized) {
        return code;
      }
    }
    return unknown;
  }
}

class RecoveryStatus {
  const RecoveryStatus({
    required this.recoveryEmailConfigured,
    required this.totpConfigured,
    this.recoveryEmail,
    this.maskedRecoveryEmail,
  });

  final bool recoveryEmailConfigured;
  final bool totpConfigured;
  final String? recoveryEmail;
  final String? maskedRecoveryEmail;

  bool get hasRecoveryMethod => recoveryEmailConfigured || totpConfigured;

  factory RecoveryStatus.fromJson(Map<String, dynamic> json) {
    bool readBool(List<String> keys) {
      for (final key in keys) {
        final value = json[key];
        if (value is bool) return value;
      }
      return false;
    }

    String? readString(List<String> keys) {
      for (final key in keys) {
        final value = json[key];
        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }
      }
      return null;
    }

    final explicitMaskedRecoveryEmail = readString([
      'masked_recovery_email',
      'recovery_email_masked',
    ]);
    final recoveryEmailValue = readString(['recovery_email']);
    final recoveryEmail =
        recoveryEmailValue != null &&
            !recoveryEmailValue.contains('*') &&
            isValidAddress(recoveryEmailValue)
        ? recoveryEmailValue
        : null;
    final maskedRecoveryEmail =
        explicitMaskedRecoveryEmail ?? recoveryEmailValue;
    return RecoveryStatus(
      recoveryEmailConfigured:
          readBool([
            'recovery_email_enabled',
            'recovery_email_configured',
            'email_enabled',
            'has_recovery_email',
          ]) ||
          maskedRecoveryEmail != null,
      totpConfigured: readBool([
        'totp_enabled',
        'totp_configured',
        'authenticator_enabled',
        'has_totp',
      ]),
      recoveryEmail: recoveryEmail,
      maskedRecoveryEmail: maskedRecoveryEmail,
    );
  }
}

class RecoveryEmailChallenge {
  const RecoveryEmailChallenge({required this.challenge});

  final String challenge;
}

class RecoveryTotpSetup {
  const RecoveryTotpSetup({
    required this.otpauthUri,
    required this.secret,
    required this.challenge,
  });

  final String otpauthUri;
  final String secret;
  final String? challenge;
}

class RecoveryResetToken {
  const RecoveryResetToken({required this.resetToken});

  final String resetToken;
}

sealed class EmailProvisioningApiException implements Exception {
  const EmailProvisioningApiException({
    this.statusCode,
    this.isRecoverable = false,
    this.debugMessage,
  });

  final bool isRecoverable;
  final int? statusCode;
  final String? debugMessage;

  @override
  String toString() =>
      '$runtimeType(status: $statusCode): '
      '${debugMessage ?? ''}';
}

final class EmailProvisioningApiUnauthorizedException
    extends EmailProvisioningApiException {
  const EmailProvisioningApiUnauthorizedException({
    super.statusCode,
    super.debugMessage,
  });
}

final class EmailProvisioningApiUnavailableException
    extends EmailProvisioningApiException {
  const EmailProvisioningApiUnavailableException({
    super.statusCode,
    super.debugMessage,
  }) : super(isRecoverable: true);
}

final class EmailProvisioningApiInvalidConfigurationException
    extends EmailProvisioningApiException {
  const EmailProvisioningApiInvalidConfigurationException({
    super.statusCode,
    super.debugMessage,
  });
}

final class EmailProvisioningApiInvalidResponseException
    extends EmailProvisioningApiException {
  const EmailProvisioningApiInvalidResponseException({
    super.statusCode,
    super.isRecoverable,
    super.debugMessage,
  });
}

final class EmailProvisioningApiNetworkException
    extends EmailProvisioningApiException {
  const EmailProvisioningApiNetworkException({
    super.statusCode,
    super.debugMessage,
  }) : super(isRecoverable: true);
}

final class EmailProvisioningApiAuthenticationFailedException
    extends EmailProvisioningApiException {
  const EmailProvisioningApiAuthenticationFailedException({
    super.statusCode,
    super.debugMessage,
  }) : super(isRecoverable: true);
}

final class EmailProvisioningApiNotFoundException
    extends EmailProvisioningApiException {
  const EmailProvisioningApiNotFoundException({
    super.statusCode,
    super.debugMessage,
  });
}

final class EmailProvisioningApiAlreadyExistsException
    extends EmailProvisioningApiException {
  const EmailProvisioningApiAlreadyExistsException({
    super.statusCode,
    super.debugMessage,
  });
}

final class EmailProvisioningApiRejectedException
    extends EmailProvisioningApiException {
  const EmailProvisioningApiRejectedException({
    required this.code,
    super.statusCode,
    super.isRecoverable,
    super.debugMessage,
  });

  final EmailProvisioningApiErrorCode code;
}

class EmailProvisioningClient {
  static const String _defaultProvisioningBaseUrl = 'https://axi.im:8443';
  static const String _baseUrlDefineKey = 'EMAIL_PROVISIONING_BASE_URL';
  static const String _publicTokenDefineKey = 'EMAIL_PUBLIC_TOKEN';
  static const String _publicTokenPlaceholder = 'set-email-public-token';
  static const Duration _requestTimeout = Duration(seconds: 15);

  EmailProvisioningClient({
    required Uri baseUrl,
    required String publicToken,
    bool requirePublicToken = true,
    http.Client? httpClient,
    Logger? logger,
  }) : _baseUrl = _normalizeBase(baseUrl),
       _publicToken = _normalizePublicToken(publicToken),
       _requirePublicToken = requirePublicToken,
       _httpClient = httpClient ?? _buildHttpClient(),
       _ownsClient = httpClient == null,
       _debugBadCertificateCallbackEnabled = httpClient == null && kDebugMode,
       _log = logger ?? Logger('EmailProvisioningClient') {
    _validateBaseUrl(_baseUrl);
    _log.info(
      'Email provisioning client configured: '
      'base=$_baseUrl '
      'ownsClient=$_ownsClient '
      'badCertAllowed=$_debugBadCertificateCallbackEnabled '
      'requirePublicToken=$_requirePublicToken '
      'publicTokenConfigured=$_publicTokenConfigured',
    );
    if (_requirePublicToken && !_publicTokenConfigured) {
      _log.warning('Email provisioning public token missing.');
    }
  }

  factory EmailProvisioningClient.fromEnvironment({
    Uri? baseUrlOverride,
    String? publicTokenOverride,
    http.Client? httpClient,
    Logger? logger,
  }) {
    const envBaseUrl = String.fromEnvironment(
      _baseUrlDefineKey,
      defaultValue: '',
    );
    const envPublicToken = String.fromEnvironment(
      _publicTokenDefineKey,
      defaultValue: _publicTokenPlaceholder,
    );
    final overrideBaseUrl = baseUrlOverride;
    final baseUrl =
        (overrideBaseUrl != null &&
            overrideBaseUrl.scheme.isNotEmpty &&
            overrideBaseUrl.host.isNotEmpty)
        ? overrideBaseUrl
        : envBaseUrl.isEmpty
        ? Uri.parse(_defaultProvisioningBaseUrl)
        : Uri.parse(envBaseUrl);
    final defaultHost = Uri.parse(_defaultProvisioningBaseUrl).host;
    final overrideProvided = publicTokenOverride != null;
    final overrideToken = publicTokenOverride?.trim() ?? '';
    final useBundledToken =
        !overrideProvided && baseUrl.host.toLowerCase() == defaultHost;
    final resolvedToken = useBundledToken ? envPublicToken : overrideToken;
    return EmailProvisioningClient(
      baseUrl: baseUrl,
      publicToken: resolvedToken,
      requirePublicToken: useBundledToken,
      httpClient: httpClient,
      logger: logger,
    );
  }

  final Uri _baseUrl;
  final String _publicToken;
  final bool _requirePublicToken;
  final http.Client _httpClient;
  final bool _ownsClient;
  final bool _debugBadCertificateCallbackEnabled;
  final Logger _log;

  bool get _publicTokenConfigured =>
      _publicToken.isNotEmpty && _publicToken != _publicTokenPlaceholder;

  void _validateBaseUrl(Uri baseUrl) {
    final scheme = baseUrl.scheme.toLowerCase();
    if (scheme == 'https') return;
    const allowInsecure = !kReleaseMode && kAllowInsecureEmailProvisioning;
    if (!allowInsecure) {
      throw const EmailProvisioningApiInvalidConfigurationException(
        debugMessage: 'Email provisioning base URL must use HTTPS.',
      );
    }
    _log.warning(
      'Using insecure email provisioning base URL '
      '(development override enabled).',
    );
  }

  static http.Client _buildHttpClient() {
    if (!kDebugMode) {
      return http.Client();
    }
    return IOClient(HttpClient()..badCertificateCallback = (_, _, _) => true);
  }

  void _ensureConfigured() {
    if (!_requirePublicToken) return;
    if (_publicTokenConfigured) return;
    throw const EmailProvisioningApiUnavailableException();
  }

  Future<EmailProvisioningCredentials> createAccount({
    required String localpart,
    required String password,
  }) async {
    _ensureConfigured();
    final normalizedLocalpart = localpart.trim();
    if (normalizedLocalpart.isEmpty) {
      throw const EmailProvisioningApiInvalidResponseException(
        debugMessage: 'Signup rejected: empty localpart.',
      );
    }
    if (password.trim().isEmpty) {
      throw const EmailProvisioningApiInvalidResponseException(
        debugMessage: 'Signup rejected: empty password.',
      );
    }
    final uri = _buildEndpoint('signup');
    final payload = jsonEncode({
      'localpart': normalizedLocalpart,
      'password': password,
    });
    final headers = _headers();
    http.Response response;
    try {
      response = await _httpClient
          .post(uri, headers: headers, body: payload)
          .timeout(_requestTimeout);
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'Failed to reach email provisioning service',
        error,
        stackTrace,
      );
      throw const EmailProvisioningApiNetworkException(
        debugMessage: 'Signup request failed: network error.',
      );
    }

    if (response.statusCode == 201 || response.statusCode == 200) {
      return _parseCredentials(response.body, password);
    }

    if (response.statusCode == 401) {
      _log.severe('Email provisioning unauthorized.');
      throw const EmailProvisioningApiUnauthorizedException(
        debugMessage: 'Signup request unauthorized.',
      );
    }

    if (response.statusCode >= 500) {
      _log.warning('Email provisioning unavailable: ${response.statusCode}');
      throw const EmailProvisioningApiUnavailableException(
        debugMessage: 'Signup request failed: server unavailable.',
      );
    }

    if (response.statusCode == 403) {
      _log.severe('Email provisioning forbidden.');
      throw const EmailProvisioningApiUnauthorizedException(
        debugMessage: 'Signup request forbidden.',
      );
    }

    if (response.statusCode == 409) {
      final detail = _errorMessageFrom(response.body);
      _log.info('Email provisioning rejected duplicate signup.');
      throw EmailProvisioningApiAlreadyExistsException(
        statusCode: response.statusCode,
        debugMessage:
            detail ?? 'Signup request rejected: account already exists.',
      );
    }

    if (response.statusCode >= 400) {
      final detail = _errorMessageFrom(response.body);
      final recoverable = response.statusCode != 451;
      _log.info(
        'Email provisioning rejected request '
        '(${response.statusCode}).',
      );
      throw EmailProvisioningApiInvalidResponseException(
        isRecoverable: recoverable,
        statusCode: response.statusCode,
        debugMessage: detail ?? 'Signup request rejected.',
      );
    }

    _log.warning('Email provisioning failed: ${response.statusCode}');
    throw EmailProvisioningApiInvalidResponseException(
      statusCode: response.statusCode,
      debugMessage: 'Signup request failed: unexpected status.',
    );
  }

  Future<void> deleteAccount({
    required String email,
    required String password,
  }) async {
    _ensureConfigured();
    final uri = _buildEndpoint('account');
    final normalizedEmail = email.trim();
    final headers = _headers();
    final payload = jsonEncode({
      'email': normalizedEmail,
      'password': password,
    });
    http.Response response;
    try {
      response = await _httpClient
          .delete(uri, headers: headers, body: payload)
          .timeout(_requestTimeout);
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'Failed to reach email account deletion service',
        error,
        stackTrace,
      );
      throw const EmailProvisioningApiNetworkException(
        debugMessage: 'Email account deletion request failed.',
      );
    }

    if (response.statusCode == 200 || response.statusCode == 404) {
      if (response.statusCode == 404) {
        _log.info('Email account already deleted.');
      }
      return;
    }

    if (response.statusCode == 401) {
      throw const EmailProvisioningApiAuthenticationFailedException(
        debugMessage: 'Delete account rejected: authentication failed.',
      );
    }

    if (response.statusCode == 403) {
      _log.severe('Email account deletion forbidden.');
      throw const EmailProvisioningApiUnauthorizedException(
        debugMessage: 'Delete account forbidden.',
      );
    }

    if (response.statusCode >= 500) {
      _log.warning(
        'Email account deletion unavailable: ${response.statusCode}',
      );
      throw const EmailProvisioningApiUnavailableException(
        debugMessage: 'Delete account unavailable.',
      );
    }

    final detail = _errorMessageFrom(response.body);
    _log.warning(
      'Email account deletion failed (${response.statusCode})'
      '.',
    );
    throw EmailProvisioningApiInvalidResponseException(
      statusCode: response.statusCode,
      debugMessage: detail ?? 'Delete account failed: invalid response.',
    );
  }

  Future<void> changePassword({
    required String email,
    required String oldPassword,
    required String newPassword,
  }) async {
    _ensureConfigured();
    final uri = _buildEndpoint('password');
    final headers = _headers();
    final payload = jsonEncode({
      'email': email.trim(),
      'old_password': oldPassword,
      'new_password': newPassword,
    });

    http.Response response;
    try {
      response = await _httpClient
          .post(uri, headers: headers, body: payload)
          .timeout(_requestTimeout);
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'Failed to reach email password change service',
        error,
        stackTrace,
      );
      throw const EmailProvisioningApiNetworkException(
        debugMessage: 'Change password request failed: network error.',
      );
    }

    if (response.statusCode == 200) {
      return;
    }

    if (response.statusCode == 401) {
      throw const EmailProvisioningApiAuthenticationFailedException(
        debugMessage: 'Change password rejected: authentication failed.',
      );
    }

    if (response.statusCode == 404) {
      throw const EmailProvisioningApiNotFoundException(
        debugMessage: 'Change password rejected: account not found.',
      );
    }

    if (response.statusCode >= 500) {
      _log.warning('Email password change unavailable: ${response.statusCode}');
      throw const EmailProvisioningApiUnavailableException(
        debugMessage: 'Change password unavailable.',
      );
    }

    final detail = _errorMessageFrom(response.body);
    throw EmailProvisioningApiInvalidResponseException(
      statusCode: response.statusCode,
      debugMessage: detail ?? 'Change password failed: invalid response.',
    );
  }

  Future<void> changeHostedPassword({
    required String email,
    required String oldPassword,
    required String newPassword,
    required String idempotencyKey,
  }) async {
    final response = await _postV1Json(
      pathSegments: const ['password'],
      payload: {
        'email': email.trim(),
        'old_password': oldPassword,
        'new_password': newPassword,
      },
      idempotencyKey: idempotencyKey,
      logContext: 'axi.im password change',
    );
    if (response.statusCode == 200) {
      return;
    }
    _throwV1Exception(response, fallbackMessage: 'Password change rejected.');
  }

  Future<void> deleteHostedAccount({
    required String email,
    required String password,
    required String idempotencyKey,
  }) async {
    final response = await _deleteV1Json(
      pathSegments: const ['account'],
      payload: {'email': email.trim(), 'password': password},
      idempotencyKey: idempotencyKey,
      logContext: 'axi.im account deletion',
    );
    if (response.statusCode == 200) {
      return;
    }
    _throwV1Exception(response, fallbackMessage: 'Account deletion rejected.');
  }

  Future<RecoveryStatus> recoveryStatus({
    required String email,
    required String password,
  }) async {
    final response = await _postV1Json(
      pathSegments: const ['recovery', 'status'],
      payload: {'email': email.trim(), 'password': password},
      logContext: 'recovery status',
    );
    if (response.statusCode == 200) {
      return RecoveryStatus.fromJson(_decodeObject(response.body));
    }
    _throwV1Exception(response, fallbackMessage: 'Recovery status rejected.');
  }

  Future<RecoveryEmailChallenge> startRecoveryEmailSetup({
    required String email,
    required String password,
    required String recoveryEmail,
  }) async {
    final response = await _postV1Json(
      pathSegments: const ['recovery', 'email', 'start'],
      payload: {
        'username': _recoveryUsername(email),
        'password': password,
        'recovery_email': recoveryEmail.trim(),
      },
      logContext: 'recovery email setup start',
    );
    if (response.statusCode == 200) {
      return RecoveryEmailChallenge(
        challenge: _requiredString(_decodeObject(response.body), const [
          'challenge',
          'challenge_id',
        ]),
      );
    }
    _throwV1Exception(
      response,
      fallbackMessage: 'Recovery email setup rejected.',
    );
  }

  Future<void> confirmRecoveryEmailSetup({
    required String email,
    required String password,
    required String challenge,
    required String code,
  }) async {
    final response = await _postV1Json(
      pathSegments: const ['recovery', 'email', 'confirm'],
      payload: {
        'username': _recoveryUsername(email),
        'password': password,
        'challenge_id': challenge.trim(),
        'code': code.trim(),
      },
      logContext: 'recovery email setup confirm',
    );
    if (response.statusCode == 200) {
      return;
    }
    _throwV1Exception(
      response,
      fallbackMessage: 'Recovery email confirmation rejected.',
    );
  }

  Future<void> removeRecoveryEmail({
    required String email,
    required String password,
  }) async {
    final response = await _postV1Json(
      pathSegments: const ['recovery', 'email', 'remove'],
      payload: {'username': _recoveryUsername(email), 'password': password},
      logContext: 'recovery email remove',
    );
    if (response.statusCode == 200 || response.statusCode == 404) {
      return;
    }
    _throwV1Exception(
      response,
      fallbackMessage: 'Recovery email removal rejected.',
    );
  }

  Future<RecoveryTotpSetup> startRecoveryTotpSetup({
    required String email,
    required String password,
  }) async {
    final response = await _postV1Json(
      pathSegments: const ['recovery', 'totp', 'start'],
      payload: {'username': _recoveryUsername(email), 'password': password},
      logContext: 'recovery authenticator setup start',
    );
    if (response.statusCode == 200) {
      final decoded = _decodeObject(response.body);
      return RecoveryTotpSetup(
        otpauthUri: _requiredString(decoded, const ['otpauth_uri']),
        secret: _requiredString(decoded, const ['secret']),
        challenge: _optionalString(decoded, const [
          'challenge',
          'challenge_id',
        ]),
      );
    }
    _throwV1Exception(
      response,
      fallbackMessage: 'Authenticator setup rejected.',
    );
  }

  Future<void> confirmRecoveryTotpSetup({
    required String email,
    required String password,
    required String code,
    String? challenge,
  }) async {
    final response = await _postV1Json(
      pathSegments: const ['recovery', 'totp', 'confirm'],
      payload: {
        'username': _recoveryUsername(email),
        'password': password,
        if (challenge != null) 'challenge_id': challenge.trim(),
        'code': code.trim(),
      },
      logContext: 'recovery authenticator setup confirm',
    );
    if (response.statusCode == 200) {
      return;
    }
    _throwV1Exception(
      response,
      fallbackMessage: 'Authenticator confirmation rejected.',
    );
  }

  Future<void> removeRecoveryTotp({
    required String email,
    required String password,
  }) async {
    final response = await _postV1Json(
      pathSegments: const ['recovery', 'totp', 'remove'],
      payload: {'username': _recoveryUsername(email), 'password': password},
      logContext: 'recovery authenticator remove',
    );
    if (response.statusCode == 200 || response.statusCode == 404) {
      return;
    }
    _throwV1Exception(
      response,
      fallbackMessage: 'Authenticator removal rejected.',
    );
  }

  Future<RecoveryEmailChallenge> startRecoveryEmailReset({
    required String email,
    required String recoveryEmail,
  }) async {
    final username = _recoveryUsername(email);
    final response = await _postV1Json(
      pathSegments: const ['recovery', 'email', 'start-reset'],
      payload: {'username': username, 'recovery_email': recoveryEmail.trim()},
      logContext: 'recovery email reset start',
    );
    if (response.statusCode == 200) {
      final challenge = _requiredString(_decodeObject(response.body), const [
        'challenge',
        'challenge_id',
      ]);
      _log.info(
        'Recovery email reset start challenge received: '
        'usernameLength=${username.length} '
        'challengeLength=${challenge.length} '
        'challengeIdPrefix=${_debugTokenPrefix(challenge)}',
      );
      return RecoveryEmailChallenge(challenge: challenge);
    }
    _throwV1Exception(
      response,
      fallbackMessage: 'Recovery email reset rejected.',
    );
  }

  Future<RecoveryResetToken> verifyRecoveryEmailReset({
    required String email,
    required String challenge,
    required String code,
  }) async {
    final username = _recoveryUsername(email);
    final challengeId = challenge.trim();
    final recoveryCode = code.trim();
    _log.info(
      'Recovery email reset verify request metadata: '
      'usernameLength=${username.length} '
      'challengeLength=${challengeId.length} '
      'challengeIdPrefix=${_debugTokenPrefix(challengeId)} '
      'codeLength=${recoveryCode.length}',
    );
    final response = await _postV1Json(
      pathSegments: const ['recovery', 'email', 'verify'],
      payload: {
        'username': username,
        'challenge_id': challengeId,
        'code': recoveryCode,
      },
      logContext: 'recovery email reset verify',
    );
    if (response.statusCode == 200) {
      return RecoveryResetToken(
        resetToken: _requiredString(_decodeObject(response.body), const [
          'reset_token',
        ]),
      );
    }
    _throwV1Exception(
      response,
      fallbackMessage: 'Recovery email code rejected.',
    );
  }

  Future<RecoveryResetToken> verifyRecoveryTotpReset({
    required String email,
    required String code,
  }) async {
    final response = await _postV1Json(
      pathSegments: const ['recovery', 'totp', 'verify'],
      payload: {'username': _recoveryUsername(email), 'code': code.trim()},
      logContext: 'recovery authenticator reset verify',
    );
    if (response.statusCode == 200) {
      return RecoveryResetToken(
        resetToken: _requiredString(_decodeObject(response.body), const [
          'reset_token',
        ]),
      );
    }
    _throwV1Exception(
      response,
      fallbackMessage: 'Authenticator code rejected.',
    );
  }

  Future<void> resetPasswordWithRecovery({
    required String email,
    required String resetToken,
    required String newPassword,
  }) async {
    final response = await _postV1Json(
      pathSegments: const ['recovery', 'password', 'reset'],
      payload: {
        'username': _recoveryUsername(email),
        'reset_token': resetToken.trim(),
        'new_password': newPassword,
      },
      logContext: 'recovery password reset',
    );
    if (response.statusCode == 200) {
      return;
    }
    _throwV1Exception(
      response,
      fallbackMessage: 'Recovery password reset rejected.',
    );
  }

  Uri _buildEndpoint(String resource) {
    return _buildEndpointSegments([resource]);
  }

  Uri _buildV1Endpoint(Iterable<String> resourceSegments) {
    return _buildEndpointSegments(['v1', ...resourceSegments]);
  }

  Uri _buildEndpointSegments(Iterable<String> resourceSegments) {
    final segments = [
      ..._baseUrl.pathSegments.where((segment) => segment.isNotEmpty),
      ...resourceSegments.where((segment) => segment.trim().isNotEmpty),
    ];
    return _baseUrl.replace(pathSegments: segments);
  }

  Map<String, String> _headers({String? idempotencyKey}) {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (_publicTokenConfigured) {
      headers['X-Client-Token'] = _publicToken;
      headers['X-Auth-Token'] = _publicToken;
    }
    final normalizedIdempotencyKey = idempotencyKey?.trim();
    if (normalizedIdempotencyKey != null &&
        normalizedIdempotencyKey.isNotEmpty) {
      headers['Idempotency-Key'] = normalizedIdempotencyKey;
    }
    return headers;
  }

  Future<http.Response> _postV1Json({
    required Iterable<String> pathSegments,
    required Map<String, Object?> payload,
    required String logContext,
    String? idempotencyKey,
  }) async {
    final uri = _buildV1Endpoint(pathSegments);
    final headers = _headers(idempotencyKey: idempotencyKey);
    _log.info(
      'Email provisioning POST $logContext: '
      'url=$uri '
      'ownsClient=$_ownsClient '
      'badCertAllowed=$_debugBadCertificateCallbackEnabled '
      'clientToken=${headers.containsKey('X-Client-Token')}',
    );
    try {
      final response = await _httpClient
          .post(uri, headers: headers, body: jsonEncode(payload))
          .timeout(_requestTimeout);
      _log.info(
        'Email provisioning POST $logContext response: '
        'url=$uri '
        'status=${response.statusCode} '
        'errorCode=${_errorCodeFrom(response.body).wireValue} '
        'detail=${_errorMessageFrom(response.body) ?? ''}',
      );
      return response;
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'Failed to reach $logContext service at $uri '
        '(ownsClient=$_ownsClient, '
        'badCertAllowed=$_debugBadCertificateCallbackEnabled).',
        error,
        stackTrace,
      );
      throw EmailProvisioningApiNetworkException(
        debugMessage: '$logContext request failed: network error.',
      );
    }
  }

  Future<http.Response> _deleteV1Json({
    required Iterable<String> pathSegments,
    required Map<String, Object?> payload,
    required String logContext,
    String? idempotencyKey,
  }) async {
    final uri = _buildV1Endpoint(pathSegments);
    final headers = _headers(idempotencyKey: idempotencyKey);
    _log.info(
      'Email provisioning DELETE $logContext: '
      'url=$uri '
      'ownsClient=$_ownsClient '
      'badCertAllowed=$_debugBadCertificateCallbackEnabled '
      'clientToken=${headers.containsKey('X-Client-Token')}',
    );
    try {
      final response = await _httpClient
          .delete(uri, headers: headers, body: jsonEncode(payload))
          .timeout(_requestTimeout);
      _log.info(
        'Email provisioning DELETE $logContext response: '
        'url=$uri '
        'status=${response.statusCode} '
        'errorCode=${_errorCodeFrom(response.body).wireValue} '
        'detail=${_errorMessageFrom(response.body) ?? ''}',
      );
      return response;
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'Failed to reach $logContext service at $uri '
        '(ownsClient=$_ownsClient, '
        'badCertAllowed=$_debugBadCertificateCallbackEnabled).',
        error,
        stackTrace,
      );
      throw EmailProvisioningApiNetworkException(
        debugMessage: '$logContext request failed: network error.',
      );
    }
  }

  Never _throwV1Exception(
    http.Response response, {
    required String fallbackMessage,
  }) {
    final detail = _errorMessageFrom(response.body);
    final code = _errorCodeFrom(response.body);
    _log.warning(
      'Email provisioning v1 rejection: '
      'status=${response.statusCode} '
      'code=${code.wireValue} '
      'detail=${detail ?? ''} '
      'fallback=$fallbackMessage',
    );
    if (code != EmailProvisioningApiErrorCode.unknown) {
      throw EmailProvisioningApiRejectedException(
        code: code,
        statusCode: response.statusCode,
        isRecoverable:
            code == EmailProvisioningApiErrorCode.xmppServiceUnavailable,
        debugMessage: detail ?? fallbackMessage,
      );
    }
    if (response.statusCode == 503 || response.statusCode >= 500) {
      throw EmailProvisioningApiUnavailableException(
        statusCode: response.statusCode,
        debugMessage: fallbackMessage,
      );
    }
    if (response.statusCode == 429) {
      throw EmailProvisioningApiRejectedException(
        code: EmailProvisioningApiErrorCode.rateLimited,
        statusCode: response.statusCode,
        debugMessage: detail ?? fallbackMessage,
      );
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw EmailProvisioningApiRejectedException(
        code: EmailProvisioningApiErrorCode.authFailed,
        statusCode: response.statusCode,
        debugMessage: detail ?? fallbackMessage,
      );
    }
    throw EmailProvisioningApiRejectedException(
      code: code,
      statusCode: response.statusCode,
      debugMessage: detail ?? fallbackMessage,
    );
  }

  static Uri _normalizeBase(Uri baseUrl) {
    if (baseUrl.scheme.isEmpty || baseUrl.host.isEmpty) {
      throw const EmailProvisioningApiInvalidConfigurationException(
        debugMessage:
            'Email provisioning base URL must include a scheme and host.',
      );
    }
    return baseUrl;
  }

  static String _normalizePublicToken(String token) {
    return token.trim();
  }

  void close() {
    if (_ownsClient) {
      _httpClient.close();
    }
  }

  EmailProvisioningCredentials _parseCredentials(
    String payload,
    String password,
  ) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Expected JSON object');
      }
      final email = decoded['email'];
      if (email is! String || email.isEmpty) {
        throw const FormatException('Missing email field');
      }
      return EmailProvisioningCredentials(email: email, password: password);
    } on FormatException catch (error, stackTrace) {
      _log.warning('Invalid email provisioning response', error, stackTrace);
      throw const EmailProvisioningApiInvalidResponseException(
        debugMessage: 'Signup response invalid.',
      );
    }
  }

  String? _errorMessageFrom(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        for (final key in const [
          'detail',
          'message',
          'error_description',
          'error',
        ]) {
          final value = decoded[key];
          if (value is String && value.trim().isNotEmpty) {
            return value.trim();
          }
        }
      }
    } on FormatException {
      return null;
    }
    return null;
  }

  EmailProvisioningApiErrorCode _errorCodeFrom(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final code =
            decoded['code'] ??
            decoded['error_code'] ??
            decoded['error'] ??
            decoded['detail'];
        return code is String
            ? EmailProvisioningApiErrorCode.fromWire(code)
            : EmailProvisioningApiErrorCode.unknown;
      }
    } on FormatException {
      return EmailProvisioningApiErrorCode.unknown;
    }
    return EmailProvisioningApiErrorCode.unknown;
  }

  Map<String, dynamic> _decodeObject(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      throw const FormatException('Expected JSON object');
    } on FormatException catch (error, stackTrace) {
      _log.warning('Invalid email provisioning response', error, stackTrace);
      throw const EmailProvisioningApiInvalidResponseException(
        debugMessage: 'Response invalid.',
      );
    }
  }

  String? _optionalString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  String _recoveryUsername(String email) {
    final localPart = addressLocalPart(email);
    if (localPart != null && localPart.trim().isNotEmpty) {
      return localPart.trim().toLowerCase();
    }
    return email.trim().toLowerCase();
  }

  String _debugTokenPrefix(String token) {
    final trimmed = token.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    final end = trimmed.length < 8 ? trimmed.length : 8;
    return trimmed.substring(0, end);
  }

  String _requiredString(Map<String, dynamic> json, List<String> keys) {
    final value = _optionalString(json, keys);
    if (value != null) {
      return value;
    }
    throw const EmailProvisioningApiInvalidResponseException(
      debugMessage: 'Response invalid.',
    );
  }
}
