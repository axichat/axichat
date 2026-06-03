import 'dart:convert';

import 'package:axichat/src/authentication/bloc/email_provisioning_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'v1 repair_required responses are non-retryable stop conditions',
    () async {
      final client = EmailProvisioningClient(
        baseUrl: Uri.parse('https://axi.im:8443'),
        publicToken: 'token',
        httpClient: MockClient((request) async {
          expect(request.url.path, '/v1/password');
          return http.Response(
            jsonEncode({
              'code': 'repair_required',
              'error': 'Account repair is required.',
            }),
            500,
          );
        }),
      );

      await expectLater(
        client.changeHostedPassword(
          email: 'alice@axi.im',
          oldPassword: 'old-password',
          newPassword: 'new-password',
          idempotencyKey: 'request-id',
        ),
        throwsA(
          isA<EmailProvisioningApiRejectedException>()
              .having(
                (error) => error.code,
                'code',
                EmailProvisioningApiErrorCode.repairRequired,
              )
              .having((error) => error.isRecoverable, 'recoverable', false),
        ),
      );
    },
  );

  test('v1 429 responses map to rate_limited without retry', () async {
    final client = EmailProvisioningClient(
      baseUrl: Uri.parse('https://axi.im:8443'),
      publicToken: 'token',
      httpClient: MockClient((request) async {
        return http.Response(jsonEncode({'detail': 'Slow down.'}), 429);
      }),
    );

    await expectLater(
      client.resetPasswordWithRecovery(
        email: 'alice@axi.im',
        resetToken: 'reset-token',
        newPassword: 'new-password',
      ),
      throwsA(
        isA<EmailProvisioningApiRejectedException>()
            .having(
              (error) => error.code,
              'code',
              EmailProvisioningApiErrorCode.rateLimited,
            )
            .having((error) => error.debugMessage, 'detail', 'Slow down.')
            .having((error) => error.isRecoverable, 'recoverable', false),
      ),
    );
  });

  test(
    'v1 detail error codes classify xmpp service dependency failures',
    () async {
      final client = EmailProvisioningClient(
        baseUrl: Uri.parse('https://axi.im:8443'),
        publicToken: 'token',
        httpClient: MockClient((request) async {
          expect(request.url.path, '/v1/recovery/status');
          return http.Response(
            jsonEncode({'detail': 'xmpp_service_unavailable'}),
            503,
          );
        }),
      );

      await expectLater(
        client.recoveryStatus(email: 'alice@axi.im', password: 'password'),
        throwsA(
          isA<EmailProvisioningApiRejectedException>()
              .having(
                (error) => error.code,
                'code',
                EmailProvisioningApiErrorCode.xmppServiceUnavailable,
              )
              .having(
                (error) => error.debugMessage,
                'detail',
                'xmpp_service_unavailable',
              )
              .having((error) => error.isRecoverable, 'recoverable', true),
        ),
      );
    },
  );

  test('v1 requests do not send the placeholder public token', () async {
    final client = EmailProvisioningClient.fromEnvironment(
      httpClient: MockClient((request) async {
        expect(request.url.path, '/v1/recovery/status');
        expect(request.headers, isNot(contains('X-Client-Token')));
        expect(request.headers, isNot(contains('X-Auth-Token')));
        return http.Response(
          jsonEncode({
            'recovery_email': 'a***@example.com',
            'totp_configured': true,
          }),
          200,
        );
      }),
    );

    final status = await client.recoveryStatus(email: 'alice@axi.im');

    expect(status.recoveryEmailConfigured, isTrue);
    expect(status.maskedRecoveryEmail, 'a***@example.com');
    expect(status.totpConfigured, isTrue);
  });

  test(
    'public token is sent as client token on legacy and v1 requests',
    () async {
      final paths = <String>[];
      final client = EmailProvisioningClient(
        baseUrl: Uri.parse('https://axi.im:8443'),
        publicToken: 'token',
        httpClient: MockClient((request) async {
          paths.add(request.url.path);
          expect(request.headers, containsPair('X-Client-Token', 'token'));
          expect(request.headers, containsPair('X-Auth-Token', 'token'));
          if (request.url.path == '/signup') {
            return http.Response(jsonEncode({'email': 'alice@axi.im'}), 201);
          }
          return http.Response(
            jsonEncode({
              'recovery_email': 'a***@example.com',
              'totp_configured': true,
            }),
            200,
          );
        }),
      );

      await client.createAccount(localpart: 'alice', password: 'password');
      await client.recoveryStatus(email: 'alice@axi.im');

      expect(paths, ['/signup', '/v1/recovery/status']);
    },
  );
}
