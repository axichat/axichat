import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:chat/main.dart';
import 'package:chat/src/xmpp/xmpp_service.dart';
import 'package:equatable/equatable.dart';
import 'package:logging/logging.dart';

part 'authentication_event.dart';
part 'authentication_state.dart';

class AuthenticationBloc
    extends Bloc<AuthenticationEvent, AuthenticationState> {
  AuthenticationBloc({
    required XmppService xmppService,
  })  : _xmppService = xmppService,
        super(
          xmppService.user != null
              ? AuthenticationComplete()
              : AuthenticationNone(),
        ) {
    on<AuthenticationLoginRequested>(
      _onLoginRequested,
      transformer: sequential(),
    );
    on<AuthenticationLogoutRequested>(
      _onLogoutRequested,
      transformer: sequential(),
    );
  }

  final XmppService _xmppService;

  final _log = Logger('AuthenticationBloc');

  void _onLoginRequested(
      AuthenticationLoginRequested event, Emitter emit) async {
    emit(AuthenticationInProgress());
    try {
      await _xmppService.login(
          event.username, event.password, event.rememberMe);
    } on XmppAuthenticationException catch (_) {
      emit(const AuthenticationFailure('Incorrect username or password'));
      return;
    } on Exception catch (e, s) {
      _log.severe('Login failure...', e, s);
      emit(const AuthenticationFailure(
          'Network error. Please try again later.'));
      return;
    } catch (e, s) {
      _log.severe('Login failure...', e, s);
      emit(
          const AuthenticationFailure('Unknown error. Please try again later'));
      rethrow;
    }
    emit(AuthenticationComplete());
  }

  void _onLogoutRequested(AuthenticationLogoutRequested event, Emitter emit) {
    switch (event.severity) {
      case LogoutSeverity.normal:
        _xmppService.logout();
      case LogoutSeverity.burn:
        _xmppService.logout(burn: true);
    }

    emit(AuthenticationNone());
  }
}
