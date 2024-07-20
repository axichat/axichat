import 'package:bloc/bloc.dart';
import 'package:chat/src/xmpp/xmpp_service.dart';

part 'authentication_state.dart';

enum LogoutSeverity {
  normal,
  burn;

  bool get isNormal => this == normal;
  bool get isBurn => this == burn;

  String get asString => switch (this) {
        LogoutSeverity.normal => 'Normal',
        LogoutSeverity.burn => 'Burn',
      };
}

class AuthenticationCubit extends Cubit<AuthenticationState> {
  AuthenticationCubit({
    required XmppService xmppService,
  })  : _xmppService = xmppService,
        super(
          xmppService.user != null
              ? AuthenticationComplete()
              : AuthenticationNone(),
        );

  final XmppService _xmppService;

  Future<void> login({
    String? username,
    String? password,
    String domain = 'draugr.de',
    bool rememberMe = false,
  }) async {
    emit(AuthenticationInProgress());
    if (username == null) {
      try {
        await _xmppService.authenticateAndConnect(
          null,
          null,
          true,
        );
      } on XmppUserNotFoundException catch (_) {
        emit(AuthenticationNone());
        return;
      } on Exception catch (_) {
        emit(const AuthenticationFailure(
            'Network error. Please try again later.'));
        return;
      }
    } else {
      try {
        await _xmppService.authenticateAndConnect(
          '$username@$domain',
          password,
          rememberMe,
        );
      } on XmppAuthenticationException catch (_) {
        emit(const AuthenticationFailure('Incorrect username or password'));
        return;
      } on Exception catch (_) {
        emit(const AuthenticationFailure(
            'Network error. Please try again later.'));
        return;
      }
    }
    emit(AuthenticationComplete());
  }

  Future<void> signup({
    required String username,
    required String password,
    required bool rememberMe,
    required bool agreeToTerms,
  }) async {
    // TODO: In-band registration.
  }

  Future<void> logout({LogoutSeverity severity = LogoutSeverity.normal}) async {
    switch (severity) {
      case LogoutSeverity.normal:
        await _xmppService.disconnect();
      case LogoutSeverity.burn:
        await _xmppService.disconnect(burn: true);
    }

    emit(AuthenticationNone());
  }
}
