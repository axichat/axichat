import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

const _defaultProvisioningBaseUrl = 'http://axi.im:3691';
const _baseUrlDefineKey = 'CHATMAIL_PROVISIONING_BASE_URL';
const _tokenDefineKey = 'CHATMAIL_PROVISIONING_TOKEN';
const _tokenPlaceholder = 'set-chatmail-token';

class ChatmailCredentials {
  const ChatmailCredentials({required this.email, required this.password});

  final String email;
  final String password;
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
    required String token,
    http.Client? httpClient,
    Logger? logger,
  })  : _baseUrl = _normalizeBase(baseUrl),
        _token = _normalizeToken(token),
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
    const envToken = String.fromEnvironment(
      _tokenDefineKey,
      defaultValue: _tokenPlaceholder,
    );
    final baseUrl = envBaseUrl.isEmpty
        ? Uri.parse(_defaultProvisioningBaseUrl)
        : Uri.parse(envBaseUrl);
    return ChatmailProvisioningClient(
      baseUrl: baseUrl,
      token: envToken,
      httpClient: httpClient,
      logger: logger,
    );
  }

  final Uri _baseUrl;
  final String _token;
  final http.Client _httpClient;
  final Logger _log;

  Future<ChatmailCredentials> createAccount() async {
    final uri = _buildEndpoint();
    http.Response response;
    try {
      response = await _httpClient.post(uri);
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
      return _parseCredentials(response.body);
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
      'new_email',
    ];
    return _baseUrl.replace(
      pathSegments: segments,
      queryParameters: {'t': _token},
    );
  }

  static Uri _normalizeBase(Uri baseUrl) {
    if (baseUrl.scheme.isEmpty || baseUrl.host.isEmpty) {
      throw StateError(
        'Chatmail provisioning base URL must include a scheme and host.',
      );
    }
    return baseUrl;
  }

  static String _normalizeToken(String token) {
    final normalized = token.trim();
    if (normalized.isEmpty || normalized == _tokenPlaceholder) {
      throw StateError(
        'Chatmail provisioning token missing. Set '
        '--dart-define=$_tokenDefineKey=<token> before running.',
      );
    }
    return normalized;
  }

  ChatmailCredentials _parseCredentials(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Expected JSON object');
      }
      final email = decoded['email'];
      final password = decoded['password'];
      if (email is! String || email.isEmpty) {
        throw const FormatException('Missing email field');
      }
      if (password is! String || password.isEmpty) {
        throw const FormatException('Missing password field');
      }
      return ChatmailCredentials(email: email, password: password);
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
