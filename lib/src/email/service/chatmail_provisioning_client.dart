import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

const _defaultProvisioningBaseUrl = 'http://axi.im:8787';
const _baseUrlDefineKey = 'CHATMAIL_PROVISIONING_BASE_URL';
const _sharedSecretDefineKey = 'CHATMAIL_SHARED_SECRET';
const _sharedSecretPlaceholder = 'set-chatmail-shared-secret';

class ChatmailCredentials {
  const ChatmailCredentials({
    required this.email,
    required this.password,
    this.principalId,
  });

  final String email;
  final String password;
  final int? principalId;
}

enum ChatmailProvisioningErrorCode {
  unauthorized,
  unavailable,
  invalidResponse,
  network,
}

class ChatmailProvisioningException implements Exception {
  const ChatmailProvisioningException(
    this.message, {
    required this.code,
    this.statusCode,
    this.isRecoverable = false,
  });

  final String message;
  final ChatmailProvisioningErrorCode code;
  final bool isRecoverable;
  final int? statusCode;

  @override
  String toString() =>
      'ChatmailProvisioningException($code, status: $statusCode): $message';
}

class ChatmailProvisioningClient {
  ChatmailProvisioningClient({
    required Uri baseUrl,
    required String sharedSecret,
    http.Client? httpClient,
    Logger? logger,
  })  : _baseUrl = _normalizeBase(baseUrl),
        _sharedSecret = _normalizeSharedSecret(sharedSecret),
        _httpClient = httpClient ?? http.Client(),
        _log = logger ?? Logger('ChatmailProvisioningClient');

  factory ChatmailProvisioningClient.fromEnvironment({
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
    return ChatmailProvisioningClient(
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

  Future<ChatmailCredentials> createAccount({
    required String localpart,
    required String password,
  }) async {
    final normalizedLocalpart = localpart.trim();
    if (normalizedLocalpart.isEmpty) {
      throw const ChatmailProvisioningException(
        'Signup is temporarily unavailable. Please try again later.',
        code: ChatmailProvisioningErrorCode.invalidResponse,
      );
    }
    if (password.trim().isEmpty) {
      throw const ChatmailProvisioningException(
        'Signup is temporarily unavailable. Please try again later.',
        code: ChatmailProvisioningErrorCode.invalidResponse,
      );
    }
    final uri = _buildEndpoint();
    final payload = jsonEncode({
      'localpart': normalizedLocalpart,
      'password': password,
    });
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'X-Auth-Token': _sharedSecret,
    };
    http.Response response;
    try {
      response = await _httpClient.post(
        uri,
        headers: headers,
        body: payload,
      );
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'Failed to reach Chatmail provisioning service',
        error,
        stackTrace,
      );
      throw const ChatmailProvisioningException(
        'We couldn\'t reach the email service. Please check your '
        'connection and try again.',
        code: ChatmailProvisioningErrorCode.network,
        isRecoverable: true,
      );
    }

    if (response.statusCode == 200) {
      return _parseCredentials(response.body, password);
    }

    if (response.statusCode == 401) {
      _log.severe('Chatmail provisioning unauthorized: ${response.body}');
      throw const ChatmailProvisioningException(
        'Signup is temporarily unavailable. Please try again later.',
        code: ChatmailProvisioningErrorCode.unauthorized,
      );
    }

    if (response.statusCode >= 500) {
      final detail = _errorMessageFrom(response.body);
      _log.warning(
        'Chatmail provisioning unavailable: ${response.statusCode}'
        '${detail == null ? '' : ' $detail'}',
      );
      throw const ChatmailProvisioningException(
        'We couldn\'t reach the email service. Please check your '
        'connection and try again.',
        code: ChatmailProvisioningErrorCode.unavailable,
        isRecoverable: true,
      );
    }

    if (response.statusCode == 403) {
      _log.severe('Chatmail provisioning forbidden: ${response.body}');
      throw const ChatmailProvisioningException(
        'Signup is temporarily unavailable. Please try again later.',
        code: ChatmailProvisioningErrorCode.unauthorized,
      );
    }

    _log.warning('Chatmail provisioning failed: ${response.statusCode}');
    throw ChatmailProvisioningException(
      'Signup is temporarily unavailable. Please try again later.',
      code: ChatmailProvisioningErrorCode.invalidResponse,
      statusCode: response.statusCode,
    );
  }

  Uri _buildEndpoint() {
    final segments = [
      ..._baseUrl.pathSegments.where((segment) => segment.isNotEmpty),
      'signup',
    ];
    return _baseUrl.replace(pathSegments: segments);
  }

  static Uri _normalizeBase(Uri baseUrl) {
    if (baseUrl.scheme.isEmpty || baseUrl.host.isEmpty) {
      throw StateError(
        'Chatmail provisioning base URL must include a scheme and host.',
      );
    }
    return baseUrl;
  }

  static String _normalizeSharedSecret(String sharedSecret) {
    final normalized = sharedSecret.trim();
    if (normalized.isEmpty || normalized == _sharedSecretPlaceholder) {
      throw StateError(
        'Chatmail provisioning shared secret missing. Set '
        '--dart-define=$_sharedSecretDefineKey=<secret> before running.',
      );
    }
    return normalized;
  }

  ChatmailCredentials _parseCredentials(String payload, String password) {
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
      return ChatmailCredentials(
        email: email,
        password: password,
        principalId: principalId is int ? principalId : null,
      );
    } on FormatException catch (error, stackTrace) {
      _log.warning('Invalid Chatmail provisioning response', error, stackTrace);
      throw const ChatmailProvisioningException(
        'Signup is temporarily unavailable. Please try again later.',
        code: ChatmailProvisioningErrorCode.invalidResponse,
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
