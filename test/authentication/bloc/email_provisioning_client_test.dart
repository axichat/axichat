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
          expect(jsonDecode(request.body), {
            'email': 'alice@axi.im',
            'password': 'password',
          });
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

    final status = await client.recoveryStatus(
      email: 'alice@axi.im',
      password: 'password',
    );

    expect(status.recoveryEmailConfigured, isTrue);
    expect(status.recoveryEmail, isNull);
    expect(status.maskedRecoveryEmail, 'a***@example.com');
    expect(status.totpConfigured, isTrue);
  });

  test('recovery status separates actual and masked recovery emails', () async {
    final client = EmailProvisioningClient.fromEnvironment(
      httpClient: MockClient((request) async {
        expect(request.url.path, '/v1/recovery/status');
        return http.Response(
          jsonEncode({
            'recovery_email': 'recovery@example.com',
            'masked_recovery_email': 'r***@example.com',
          }),
          200,
        );
      }),
    );

    final status = await client.recoveryStatus(
      email: 'alice@axi.im',
      password: 'password',
    );

    expect(status.recoveryEmailConfigured, isTrue);
    expect(status.recoveryEmail, 'recovery@example.com');
    expect(status.maskedRecoveryEmail, 'r***@example.com');
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
      await client.recoveryStatus(email: 'alice@axi.im', password: 'password');

      expect(paths, ['/signup', '/v1/recovery/status']);
    },
  );

  test('recovery email setup reads and sends challenge id', () async {
    var requestCount = 0;
    final client = EmailProvisioningClient(
      baseUrl: Uri.parse('https://axi.im:8443'),
      publicToken: 'token',
      httpClient: MockClient((request) async {
        requestCount++;
        if (request.url.path == '/v1/recovery/email/start') {
          expect(jsonDecode(request.body), {
            'username': 'alice',
            'password': 'password',
            'recovery_email': 'recovery@example.com',
          });
          return http.Response(
            jsonEncode({
              'challenge_id': 'challenge-id',
              'expires_in_seconds': 900,
              'email_masked': 'r***@example.com',
            }),
            200,
          );
        }
        expect(request.url.path, '/v1/recovery/email/confirm');
        expect(jsonDecode(request.body), {
          'username': 'alice',
          'password': 'password',
          'challenge_id': 'challenge-id',
          'code': '123456',
        });
        return http.Response('{}', 200);
      }),
    );

    final setup = await client.startRecoveryEmailSetup(
      email: ' alice@axi.im ',
      password: 'password',
      recoveryEmail: ' recovery@example.com ',
    );
    await client.confirmRecoveryEmailSetup(
      email: ' alice@axi.im ',
      password: 'password',
      challenge: setup.challenge,
      code: ' 123456 ',
    );

    expect(setup.challenge, 'challenge-id');
    expect(requestCount, 2);
  });

  test('recovery authenticator confirmation sends challenge id', () async {
    final client = EmailProvisioningClient(
      baseUrl: Uri.parse('https://axi.im:8443'),
      publicToken: 'token',
      httpClient: MockClient((request) async {
        expect(request.url.path, '/v1/recovery/totp/confirm');
        expect(jsonDecode(request.body), {
          'username': 'alice',
          'password': 'password',
          'challenge_id': 'challenge-id',
          'code': '123456',
        });
        return http.Response('{}', 200);
      }),
    );

    await client.confirmRecoveryTotpSetup(
      email: ' alice@axi.im ',
      password: 'password',
      challenge: ' challenge-id ',
      code: ' 123456 ',
    );
  });

  test('recovery email reset reads and sends challenge id', () async {
    var requestCount = 0;
    final client = EmailProvisioningClient(
      baseUrl: Uri.parse('https://axi.im:8443'),
      publicToken: 'token',
      httpClient: MockClient((request) async {
        requestCount++;
        if (request.url.path == '/v1/recovery/email/start-reset') {
          expect(jsonDecode(request.body), {
            'username': 'alice',
            'recovery_email': 'recovery@example.com',
          });
          return http.Response(
            jsonEncode({'challenge_id': 'challenge-id'}),
            200,
          );
        }
        expect(request.url.path, '/v1/recovery/email/verify');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body, isNot(contains('recovery_email')));
        expect(body, {
          'username': 'alice',
          'challenge_id': 'challenge-id',
          'code': '123456',
        });
        return http.Response(jsonEncode({'reset_token': 'reset-token'}), 200);
      }),
    );

    final challenge = await client.startRecoveryEmailReset(
      email: ' alice@axi.im ',
      recoveryEmail: ' recovery@example.com ',
    );
    final token = await client.verifyRecoveryEmailReset(
      email: ' alice@axi.im ',
      challenge: challenge.challenge,
      code: ' 123456 ',
    );

    expect(challenge.challenge, 'challenge-id');
    expect(token.resetToken, 'reset-token');
    expect(requestCount, 2);
  });

  test('recovery authenticator reset verification sends username', () async {
    final client = EmailProvisioningClient(
      baseUrl: Uri.parse('https://axi.im:8443'),
      publicToken: 'token',
      httpClient: MockClient((request) async {
        expect(request.url.path, '/v1/recovery/totp/verify');
        expect(jsonDecode(request.body), {
          'username': 'alice',
          'code': '123456',
        });
        return http.Response(jsonEncode({'reset_token': 'reset-token'}), 200);
      }),
    );

    final token = await client.verifyRecoveryTotpReset(
      email: ' alice@axi.im ',
      code: ' 123456 ',
    );

    expect(token.resetToken, 'reset-token');
  });

  test('recovery password reset sends username', () async {
    final client = EmailProvisioningClient(
      baseUrl: Uri.parse('https://axi.im:8443'),
      publicToken: 'token',
      httpClient: MockClient((request) async {
        expect(request.url.path, '/v1/recovery/password/reset');
        expect(jsonDecode(request.body), {
          'username': 'alice',
          'reset_token': 'reset-token',
          'new_password': 'new-password',
        });
        return http.Response('{}', 200);
      }),
    );

    await client.resetPasswordWithRecovery(
      email: ' alice@axi.im ',
      resetToken: ' reset-token ',
      newPassword: 'new-password',
    );
  });
}
