import 'user_model.dart';
import 'auth_tokens.dart';

/// Status of authentication in the mobile client.
enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
}

/// Immutable state representation for the authentication lifecycle.
class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final AuthTokens? tokens;
  final String? errorMessage;

  const AuthState({
    required this.status,
    this.user,
    this.tokens,
    this.errorMessage,
  });

  const AuthState.initial()
      : status = AuthStatus.initial,
        user = null,
        tokens = null,
        errorMessage = null;

  const AuthState.loading()
      : status = AuthStatus.loading,
        user = null,
        tokens = null,
        errorMessage = null;

  const AuthState.authenticated({
    required this.user,
    required this.tokens,
  })  : status = AuthStatus.authenticated,
        errorMessage = null;

  const AuthState.unauthenticated()
      : status = AuthStatus.unauthenticated,
        user = null,
        tokens = null,
        errorMessage = null;

  const AuthState.error(String message)
      : status = AuthStatus.error,
        user = null,
        tokens = null,
        errorMessage = message;

  bool get isAuthenticated => status == AuthStatus.authenticated && user != null;
  bool get isLoading => status == AuthStatus.loading || status == AuthStatus.initial;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          user == other.user &&
          tokens == other.tokens &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode =>
      status.hashCode ^ user.hashCode ^ tokens.hashCode ^ errorMessage.hashCode;
}
