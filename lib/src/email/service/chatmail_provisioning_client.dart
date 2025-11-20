import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

const _defaultProvisioningBaseUrl = 'http://axi.im:8787';
const _baseUrlDefineKey = 'EMAIL_PROVISIONING_BASE_URL';
const _sharedSecretDefineKey = 'EMAIL_PROVISIONING_SHARED_SECRET';
const _sharedSecretPlaceholder = 'set-email-shared-secret';

class EmailProvisioningCredentials {
  const EmailProvisioningCredentials({
    required this.email,
    required this.password,
    required this.principalId,
  });

  final String email;
  final String password;
  final int principalId;
}

enum EmailProvisioningApiErrorCode {
  unauthorized,
  unavailable,
  invalidResponse,
  network,
  authenticationFailed,
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
    required String sharedSecret,
    http.Client? httpClient,
    Logger? logger,
  })  : _baseUrl = _normalizeBase(baseUrl),
        _sharedSecret = _normalizeSharedSecret(sharedSecret),
        _httpClient = httpClient ?? http.Client(),
        _log = logger ?? Logger('EmailProvisioningClient');

  factory EmailProvisioningClient.fromEnvironment({
    http.Client? httpClient,
    Logger? logger,
  }) {
    const envBaseUrl = String.fromEnvironment(
      _baseUrlDefineKey,
      defaultValue: '',
    );
    const envSharedSecret = String.fromEnvironment(
      _sharedSecretDefineKey,
      defaultValue: _sharedSecretPlaceholder,
    );
    final baseUrl = envBaseUrl.isEmpty
        ? Uri.parse(_defaultProvisioningBaseUrl)
        : Uri.parse(envBaseUrl);
    return EmailProvisioningClient(
      baseUrl: baseUrl,
      sharedSecret: envSharedSecret,
      httpClient: httpClient,
      logger: logger,
    );
  }

  final Uri _baseUrl;
  final String _sharedSecret;
  final http.Client _httpClient;
  final Logger _log;

  Future<EmailProvisioningCredentials> createAccount({
    required String localpart,
    required String password,
  }) async {
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
      _log.severe('Email provisioning unauthorized: ${response.body}');
      throw const EmailProvisioningApiException(
        'Signup is temporarily unavailable. Please try again later.',
        code: EmailProvisioningApiErrorCode.unauthorized,
      );
    }

    if (response.statusCode >= 500) {
      final detail = _errorMessageFrom(response.body);
      _log.warning(
        'Email provisioning unavailable: ${response.statusCode}'
        '${detail == null ? '' : ' $detail'}',
      );
      throw const EmailProvisioningApiException(
        'We couldn\'t reach the email service. Please check your '
        'connection and try again.',
        code: EmailProvisioningApiErrorCode.unavailable,
        isRecoverable: true,
      );
    }

    if (response.statusCode == 403) {
      _log.severe('Email provisioning forbidden: ${response.body}');
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
        '(${response.statusCode}): $message',
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
    required int principalId,
    required String email,
    required String password,
  }) async {
    final uri = _buildEndpoint('account');
    final normalizedEmail = email.trim();
    final headers = _headers();
    final payload = jsonEncode({
      'principal_id': principalId,
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
        _log.info('Email account already deleted for $normalizedEmail');
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
      _log.severe(
        'Email account deletion forbidden: ${response.body}',
      );
      throw const EmailProvisioningApiException(
        'Unable to delete email account. Please try again later.',
        code: EmailProvisioningApiErrorCode.unauthorized,
      );
    }

    if (response.statusCode >= 500) {
      final detail = _errorMessageFrom(response.body);
      _log.warning(
        'Email account deletion unavailable: ${response.statusCode}'
        '${detail == null ? '' : ' $detail'}',
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
      '${detail == null ? '' : ': $detail'}',
    );
    throw EmailProvisioningApiException(
      detail ?? 'Unable to delete email account. Please try again later.',
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
        'X-Auth-Token': _sharedSecret,
      };

  static Uri _normalizeBase(Uri baseUrl) {
    if (baseUrl.scheme.isEmpty || baseUrl.host.isEmpty) {
      throw StateError(
        'Email provisioning base URL must include a scheme and host.',
      );
    }
    return baseUrl;
  }

  static String _normalizeSharedSecret(String sharedSecret) {
    final normalized = sharedSecret.trim();
    if (normalized.isEmpty || normalized == _sharedSecretPlaceholder) {
      throw StateError(
        'Email provisioning shared secret missing. Set '
        '--dart-define=$_sharedSecretDefineKey=<secret> before running.',
      );
    }
    return normalized;
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
      final principalId = decoded['principal_id'];
      if (email is! String || email.isEmpty) {
        throw const FormatException('Missing email field');
      }
      if (principalId is! num) {
        throw const FormatException('Missing principal_id field');
      }
      return EmailProvisioningCredentials(
        email: email,
        password: password,
        principalId: principalId.toInt(),
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
