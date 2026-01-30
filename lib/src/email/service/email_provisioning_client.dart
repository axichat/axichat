// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:convert';

import 'package:axichat/src/common/security_flags.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
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
  unauthorized,
  unavailable,
  invalidResponse,
  network,
  authenticationFailed,
  notFound,
}

class EmailProvisioningApiException implements Exception {
  const EmailProvisioningApiException({
    required this.code,
    this.statusCode,
    this.isRecoverable = false,
    this.debugMessage,
  });

  final EmailProvisioningApiErrorCode code;
  final bool isRecoverable;
  final int? statusCode;
  final String? debugMessage;

  @override
  String toString() =>
      'EmailProvisioningApiException($code, status: $statusCode): '
      '${debugMessage ?? ''}';
}

class EmailProvisioningClient {
  static const String _defaultProvisioningBaseUrl = 'https://axi.im:8443';
  static const String _baseUrlDefineKey = 'EMAIL_PROVISIONING_BASE_URL';
  static const String _publicTokenDefineKey = 'EMAIL_PUBLIC_TOKEN';
  static const String _publicTokenPlaceholder = 'set-email-public-token';
  static const Duration _requestTimeout = Duration(seconds: 12);

  EmailProvisioningClient({
    required Uri baseUrl,
    required String publicToken,
    http.Client? httpClient,
    Logger? logger,
  })  : _baseUrl = _normalizeBase(baseUrl),
        _publicToken = _normalizePublicToken(publicToken),
        _httpClient = httpClient ?? http.Client(),
        _ownsClient = httpClient == null,
        _log = logger ?? Logger('EmailProvisioningClient') {
    _validateBaseUrl(_baseUrl);
    if (!_publicTokenConfigured) {
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
    final baseUrl = (overrideBaseUrl != null &&
            overrideBaseUrl.scheme.isNotEmpty &&
            overrideBaseUrl.host.isNotEmpty)
        ? overrideBaseUrl
        : envBaseUrl.isEmpty
            ? Uri.parse(_defaultProvisioningBaseUrl)
            : Uri.parse(envBaseUrl);
    final overrideToken = publicTokenOverride?.trim() ?? '';
    return EmailProvisioningClient(
      baseUrl: baseUrl,
      publicToken: overrideToken.isNotEmpty ? overrideToken : envPublicToken,
      httpClient: httpClient,
      logger: logger,
    );
  }

  final Uri _baseUrl;
  final String _publicToken;
  final http.Client _httpClient;
  final bool _ownsClient;
  final Logger _log;

  bool get _publicTokenConfigured =>
      _publicToken.isNotEmpty && _publicToken != _publicTokenPlaceholder;

  void _validateBaseUrl(Uri baseUrl) {
    final scheme = baseUrl.scheme.toLowerCase();
    if (scheme == 'https') return;
    const allowInsecure = !kReleaseMode && kAllowInsecureEmailProvisioning;
    if (!allowInsecure) {
      throw StateError(
        'Email provisioning base URL must use HTTPS in this build.',
      );
    }
    _log.warning(
      'Using insecure email provisioning base URL '
      '(development override enabled).',
    );
  }

  void _ensureConfigured() {
    if (_publicTokenConfigured) return;
    throw const EmailProvisioningApiException(
      code: EmailProvisioningApiErrorCode.unavailable,
    );
  }

  Future<EmailProvisioningCredentials> createAccount({
    required String localpart,
    required String password,
  }) async {
    _ensureConfigured();
    final normalizedLocalpart = localpart.trim();
    if (normalizedLocalpart.isEmpty) {
      throw const EmailProvisioningApiException(
        code: EmailProvisioningApiErrorCode.invalidResponse,
        debugMessage: 'Signup rejected: empty localpart.',
      );
    }
    if (password.trim().isEmpty) {
      throw const EmailProvisioningApiException(
        code: EmailProvisioningApiErrorCode.invalidResponse,
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
      throw const EmailProvisioningApiException(
        code: EmailProvisioningApiErrorCode.network,
        isRecoverable: true,
        debugMessage: 'Signup request failed: network error.',
      );
    }

    if (response.statusCode == 201 || response.statusCode == 200) {
      return _parseCredentials(response.body, password);
    }

    if (response.statusCode == 401) {
      _log.severe('Email provisioning unauthorized.');
      throw const EmailProvisioningApiException(
        code: EmailProvisioningApiErrorCode.unauthorized,
        debugMessage: 'Signup request unauthorized.',
      );
    }

    if (response.statusCode >= 500) {
      _log.warning('Email provisioning unavailable: ${response.statusCode}');
      throw const EmailProvisioningApiException(
        code: EmailProvisioningApiErrorCode.unavailable,
        isRecoverable: true,
        debugMessage: 'Signup request failed: server unavailable.',
      );
    }

    if (response.statusCode == 403) {
      _log.severe('Email provisioning forbidden.');
      throw const EmailProvisioningApiException(
        code: EmailProvisioningApiErrorCode.unauthorized,
        debugMessage: 'Signup request forbidden.',
      );
    }

    if (response.statusCode >= 400) {
      final detail = _errorMessageFrom(response.body);
      final recoverable = response.statusCode != 451;
      _log.info(
        'Email provisioning rejected request '
        '(${response.statusCode}).',
      );
      throw EmailProvisioningApiException(
        code: EmailProvisioningApiErrorCode.invalidResponse,
        isRecoverable: recoverable,
        statusCode: response.statusCode,
        debugMessage: detail ?? 'Signup request rejected.',
      );
    }

    _log.warning('Email provisioning failed: ${response.statusCode}');
    throw EmailProvisioningApiException(
      code: EmailProvisioningApiErrorCode.invalidResponse,
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
      throw const EmailProvisioningApiException(
        code: EmailProvisioningApiErrorCode.network,
        isRecoverable: true,
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
      throw const EmailProvisioningApiException(
        code: EmailProvisioningApiErrorCode.authenticationFailed,
        isRecoverable: true,
        debugMessage: 'Delete account rejected: authentication failed.',
      );
    }

    if (response.statusCode == 403) {
      _log.severe('Email account deletion forbidden.');
      throw const EmailProvisioningApiException(
        code: EmailProvisioningApiErrorCode.unauthorized,
        debugMessage: 'Delete account forbidden.',
      );
    }

    if (response.statusCode >= 500) {
      _log.warning(
        'Email account deletion unavailable: ${response.statusCode}',
      );
      throw const EmailProvisioningApiException(
        code: EmailProvisioningApiErrorCode.unavailable,
        isRecoverable: true,
        debugMessage: 'Delete account unavailable.',
      );
    }

    final detail = _errorMessageFrom(response.body);
    _log.warning(
      'Email account deletion failed (${response.statusCode})'
      '.',
    );
    throw EmailProvisioningApiException(
      code: EmailProvisioningApiErrorCode.invalidResponse,
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
      throw const EmailProvisioningApiException(
        code: EmailProvisioningApiErrorCode.network,
        isRecoverable: true,
        debugMessage: 'Change password request failed: network error.',
      );
    }

    if (response.statusCode == 200) {
      return;
    }

    if (response.statusCode == 401) {
      throw const EmailProvisioningApiException(
        code: EmailProvisioningApiErrorCode.authenticationFailed,
        isRecoverable: true,
        debugMessage: 'Change password rejected: authentication failed.',
      );
    }

    if (response.statusCode == 404) {
      throw const EmailProvisioningApiException(
        code: EmailProvisioningApiErrorCode.notFound,
        debugMessage: 'Change password rejected: account not found.',
      );
    }

    if (response.statusCode >= 500) {
      _log.warning('Email password change unavailable: ${response.statusCode}');
      throw const EmailProvisioningApiException(
        code: EmailProvisioningApiErrorCode.unavailable,
        isRecoverable: true,
        debugMessage: 'Change password unavailable.',
      );
    }

    final detail = _errorMessageFrom(response.body);
    throw EmailProvisioningApiException(
      code: EmailProvisioningApiErrorCode.invalidResponse,
      statusCode: response.statusCode,
      debugMessage: detail ?? 'Change password failed: invalid response.',
    );
  }

  Uri _buildEndpoint(String resource) {
    final segments = [
      ..._baseUrl.pathSegments.where((segment) => segment.isNotEmpty),
      resource,
    ];
    return _baseUrl.replace(pathSegments: segments);
  }

  Map<String, String> _headers() => {
        'Content-Type': 'application/json',
        'X-Auth-Token': _publicToken,
      };

  static Uri _normalizeBase(Uri baseUrl) {
    if (baseUrl.scheme.isEmpty || baseUrl.host.isEmpty) {
      throw StateError(
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
      throw const EmailProvisioningApiException(
        code: EmailProvisioningApiErrorCode.invalidResponse,
        debugMessage: 'Signup response invalid.',
      );
    }
  }

  String? _errorMessageFrom(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is String && error.trim().isNotEmpty) {
          return error.trim();
        }
      }
    } on FormatException {
      return null;
    }
    return null;
  }
}
