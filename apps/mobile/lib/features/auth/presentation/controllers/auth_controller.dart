import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/auth_state.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../data/auth_repository.dart';

/// Provider managing the global authentication state.
final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  final storage = ref.watch(secureStorageServiceProvider);
  final apiClient = ref.watch(apiClientProvider);

  final controller = AuthController(
    repository: repository,
    storage: storage,
    apiClient: apiClient,
  );

  // Configure session expiry callback to transition to unauthenticated
  apiClient.onSessionExpired = () {
    controller.handleSessionExpired();
  };

  return controller;
});

/// Controller handling login, logout, and session restoration.
class AuthController extends StateNotifier<AuthState> {
  final AuthRepository repository;
  final SecureStorageService storage;

  AuthController({
    required this.repository,
    required this.storage,
    required ApiClient apiClient,
  }) : super(const AuthState.initial()) {
    checkAuthStatus();
  }

  /// Public read-only access to the current state (for testing).
  @override
  AuthState get debugState => state;

  /// Verifies active session on app launch (splash).
  Future<void> checkAuthStatus() async {
    try {
      final tokens = await storage.getTokens();
      final user = await storage.getUser();

      if (tokens != null && user != null) {
        // Fast startup: set authenticated state with cached profile
        state = AuthState.authenticated(user: user, tokens: tokens);

        // Background session verification (non-blocking)
        try {
          final refreshed = await repository.refreshToken(tokens.refreshToken);
          await storage.saveTokens(refreshed.tokens);
          await storage.saveUser(refreshed.user);
          state = AuthState.authenticated(
            user: refreshed.user,
            tokens: refreshed.tokens,
          );
        } catch (_) {
          // If offline or refresh failed, check if access token is present
          // For field operations, cached session is retained if offline
        }
      } else {
        state = const AuthState.unauthenticated();
      }
    } catch (_) {
      state = const AuthState.unauthenticated();
    }
  }

  /// Perform login with credentials.
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    state = const AuthState.loading();

    try {
      final result = await repository.login(
        email: email,
        password: password,
      );

      // Persist in secure hardware-backed storage
      await storage.saveTokens(result.tokens);
      await storage.saveUser(result.user);

      state = AuthState.authenticated(
        user: result.user,
        tokens: result.tokens,
      );
      return true;
    } catch (e) {
      final message = ApiClient.formatErrorMessage(e);
      state = AuthState.error(message);
      return false;
    }
  }

  /// Perform logout and purge local credentials.
  Future<void> logout() async {
    state = const AuthState.loading();

    try {
      await repository.logout();
    } catch (_) {
      // Best-effort remote revocation
    } finally {
      await storage.clearAll();
      state = const AuthState.unauthenticated();
    }
  }

  /// Handler for automatic session expiry from 401 interceptor.
  void handleSessionExpired() {
    state = const AuthState.unauthenticated();
  }

  /// Reset error state without changing authentication status.
  void clearError() {
    if (state.status == AuthStatus.error) {
      state = const AuthState.unauthenticated();
    }
  }
}
