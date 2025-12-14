import 'dart:convert';

import 'package:axichat/src/common/security_flags.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

const _defaultProvisioningBaseUrl = 'https://axi.im:8787';
const _baseUrlDefineKey = 'EMAIL_PROVISIONING_BASE_URL';
const _publicTokenDefineKey = 'EMAIL_PUBLIC_TOKEN';
const _publicTokenPlaceholder = 'set-email-public-token';

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
  const EmailProvisioningApiException(
    this.message, {
    required this.code,
    this.statusCode,
    this.isRecoverable = false,
  });

  final String message;
  final EmailProvisioningApiErrorCode code;
  final bool isRecoverable;
  final int? statusCode;

  @override
  String toString() =>
      'EmailProvisioningApiException($code, status: $statusCode): $message';
}

class EmailProvisioningClient {
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
    final baseUrl = envBaseUrl.isEmpty
        ? Uri.parse(_defaultProvisioningBaseUrl)
        : Uri.parse(envBaseUrl);
    return EmailProvisioningClient(
      baseUrl: baseUrl,
      publicToken: envPublicToken,
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

  void _ensureConfigured(String message) {
    if (_publicTokenConfigured) return;
    throw EmailProvisioningApiException(
      message,
      code: EmailProvisioningApiErrorCode.unavailable,
    );
  }

  Future<EmailProvisioningCredentials> createAccount({
    required String localpart,
    required String password,
  }) async {
    _ensureConfigured(
      'Signup is temporarily unavailable. Please try again later.',
    );
    final normalizedLocalpart = localpart.trim();
    if (normalizedLocalpart.isEmpty) {
      throw const EmailProvisioningApiException(
        'Signup is temporarily unavailable. Please try again later.',
        code: EmailProvisioningApiErrorCode.invalidResponse,
      );
    }
    if (password.trim().isEmpty) {
      throw const EmailProvisioningApiException(
        'Signup is temporarily unavailable. Please try again later.',
        code: EmailProvisioningApiErrorCode.invalidResponse,
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
      response = await _httpClient.post(
        uri,
        headers: headers,
        body: payload,
      );
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'Failed to reach email provisioning service',
        error,
        stackTrace,
      );
      throw const EmailProvisioningApiException(
        'We couldn\'t reach the email service. Please check your '
        'connection and try again.',
        code: EmailProvisioningApiErrorCode.network,
        isRecoverable: true,
      );
    }

    if (response.statusCode == 201 || response.statusCode == 200) {
      return _parseCredentials(response.body, password);
    }

    if (response.statusCode == 401) {
      _log.severe('Email provisioning unauthorized.');
      throw const EmailProvisioningApiException(
        'Signup is temporarily unavailable. Please try again later.',
        code: EmailProvisioningApiErrorCode.unauthorized,
      );
    }

    if (response.statusCode >= 500) {
      _log.warning(
        'Email provisioning unavailable: ${response.statusCode}',
      );
      throw const EmailProvisioningApiException(
        'We couldn\'t reach the email service. Please check your '
        'connection and try again.',
        code: EmailProvisioningApiErrorCode.unavailable,
        isRecoverable: true,
      );
    }

    if (response.statusCode == 403) {
      _log.severe('Email provisioning forbidden.');
      throw const EmailProvisioningApiException(
        'Signup is temporarily unavailable. Please try again later.',
        code: EmailProvisioningApiErrorCode.unauthorized,
      );
    }

    if (response.statusCode >= 400) {
      final detail = _errorMessageFrom(response.body);
      final message = detail ??
          'That username is unavailable. Please choose a different one.';
      final recoverable = response.statusCode != 451;
      _log.info(
        'Email provisioning rejected request '
        '(${response.statusCode}).',
      );
      throw EmailProvisioningApiException(
        message,
        code: EmailProvisioningApiErrorCode.invalidResponse,
        isRecoverable: recoverable,
        statusCode: response.statusCode,
      );
    }

    _log.warning('Email provisioning failed: ${response.statusCode}');
    throw EmailProvisioningApiException(
      'Signup is temporarily unavailable. Please try again later.',
      code: EmailProvisioningApiErrorCode.invalidResponse,
      statusCode: response.statusCode,
    );
  }

  Future<void> deleteAccount({
    required String email,
    required String password,
  }) async {
    _ensureConfigured(
      'We could not delete your email account. Please try again later.',
    );
    final uri = _buildEndpoint('account');
    final normalizedEmail = email.trim();
    final headers = _headers();
    final payload = jsonEncode({
      'email': normalizedEmail,
      'password': password,
    });
    http.Response response;
    try {
      response = await _httpClient.delete(
        uri,
        headers: headers,
        body: payload,
      );
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'Failed to reach email account deletion service',
        error,
        stackTrace,
      );
      throw const EmailProvisioningApiException(
        'We could not delete your email account. Please check your '
        'connection and try again.',
        code: EmailProvisioningApiErrorCode.network,
        isRecoverable: true,
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
        'Incorrect password. Please try again.',
        code: EmailProvisioningApiErrorCode.authenticationFailed,
        isRecoverable: true,
      );
    }

    if (response.statusCode == 403) {
      _log.severe('Email account deletion forbidden.');
      throw const EmailProvisioningApiException(
        'Unable to delete email account. Please try again later.',
        code: EmailProvisioningApiErrorCode.unauthorized,
      );
    }

    if (response.statusCode >= 500) {
      _log.warning(
        'Email account deletion unavailable: ${response.statusCode}',
      );
      throw const EmailProvisioningApiException(
        'We could not delete your email account. Please try again later.',
        code: EmailProvisioningApiErrorCode.unavailable,
        isRecoverable: true,
      );
    }

    final detail = _errorMessageFrom(response.body);
    _log.warning(
      'Email account deletion failed (${response.statusCode})'
      '.',
    );
    throw EmailProvisioningApiException(
      detail ?? 'Unable to delete email account. Please try again later.',
      code: EmailProvisioningApiErrorCode.invalidResponse,
      statusCode: response.statusCode,
    );
  }

  Future<void> changePassword({
    required String email,
    required String oldPassword,
    required String newPassword,
  }) async {
    _ensureConfigured(
      'We could not change your password. Please try again later.',
    );
    final uri = _buildEndpoint('password');
    final headers = _headers();
    final payload = jsonEncode({
      'email': email.trim(),
      'old_password': oldPassword,
      'new_password': newPassword,
    });

    http.Response response;
    try {
      response = await _httpClient.post(uri, headers: headers, body: payload);
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'Failed to reach email password change service',
        error,
        stackTrace,
      );
      throw const EmailProvisioningApiException(
        'We could not reach the email service. Please try again later.',
        code: EmailProvisioningApiErrorCode.network,
        isRecoverable: true,
      );
    }

    if (response.statusCode == 200) {
      return;
    }

    if (response.statusCode == 401) {
      throw const EmailProvisioningApiException(
        'Incorrect current password. Please try again.',
        code: EmailProvisioningApiErrorCode.authenticationFailed,
        isRecoverable: true,
      );
    }

    if (response.statusCode == 404) {
      throw const EmailProvisioningApiException(
        'Account not found.',
        code: EmailProvisioningApiErrorCode.notFound,
      );
    }

    if (response.statusCode >= 500) {
      _log.warning(
        'Email password change unavailable: ${response.statusCode}',
      );
      throw const EmailProvisioningApiException(
        'We could not change your password. Please try again later.',
        code: EmailProvisioningApiErrorCode.unavailable,
        isRecoverable: true,
      );
    }

    final detail = _errorMessageFrom(response.body);
    throw EmailProvisioningApiException(
      detail ?? 'Unable to change password. Please try again later.',
      code: EmailProvisioningApiErrorCode.invalidResponse,
      statusCode: response.statusCode,
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
      return EmailProvisioningCredentials(
        email: email,
        password: password,
      );
    } on FormatException catch (error, stackTrace) {
      _log.warning('Invalid email provisioning response', error, stackTrace);
      throw const EmailProvisioningApiException(
        'Signup is temporarily unavailable. Please try again later.',
        code: EmailProvisioningApiErrorCode.invalidResponse,
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

// Backwards compatibility aliases for existing callers.
typedef ChatmailCredentials = EmailProvisioningCredentials;
typedef ChatmailProvisioningException = EmailProvisioningApiException;
typedef ChatmailProvisioningErrorCode = EmailProvisioningApiErrorCode;
typedef ChatmailProvisioningClient = EmailProvisioningClient;
