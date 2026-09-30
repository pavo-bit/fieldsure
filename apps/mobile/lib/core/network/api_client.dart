import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';
import '../storage/secure_storage_service.dart';
import '../models/auth_tokens.dart';

/// Provider for the configured Dio ApiClient.
final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.watch(secureStorageServiceProvider);
  return ApiClient(
    baseUrl: AppConstants.apiBaseUrl,
    storage: storage,
  );
});

/// Centralized API Client built on Dio.
/// Handles headers, Bearer tokens, token refresh on 401, timeouts, and error normalization.
class ApiClient {
  final String baseUrl;
  final SecureStorageService storage;
  late final Dio dio;

  /// Callback triggered when refresh fails, requiring user re-authentication.
  void Function()? onSessionExpired;

  ApiClient({
    required this.baseUrl,
    required this.storage,
    this.onSessionExpired,
  }) {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _setupInterceptors();
  }

  void _setupInterceptors() {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Do not attach token for public auth endpoints
          final path = options.path;
          if (!path.contains('/auth/login') && !path.contains('/auth/refresh')) {
            final token = await storage.getAccessToken();
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          // If 401 Unauthorized received on a non-auth endpoint, attempt token refresh
          if (error.response?.statusCode == 401 &&
              !error.requestOptions.path.contains('/auth/login') &&
              !error.requestOptions.path.contains('/auth/refresh')) {
            final refreshed = await _attemptTokenRefresh();
            if (refreshed) {
              // Retry the original request with new access token
              final newAccessToken = await storage.getAccessToken();
              final opts = error.requestOptions;
              opts.headers['Authorization'] = 'Bearer $newAccessToken';
              try {
                final response = await dio.fetch(opts);
                return handler.resolve(response);
              } catch (retryError) {
                if (retryError is DioException) {
                  return handler.reject(retryError);
                }
              }
            } else {
              // Refresh failed or revoked — clear local credentials & trigger session expiry
              await storage.clearAll();
              onSessionExpired?.call();
            }
          }
          return handler.next(error);
        },
      ),
    );
  }

  /// Attempts to exchange stored refresh token for a new access token.
  Future<bool> _attemptTokenRefresh() async {
    try {
      final tokens = await storage.getTokens();
      if (tokens == null || tokens.refreshToken.isEmpty) return false;

      // Make raw request directly to avoid circular interceptor recursion
      final response = await Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      ).post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': tokens.refreshToken},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final envelope = response.data;
        final data = (envelope is Map<String, dynamic>) ? envelope['data'] as Map<String, dynamic>? : null;
        if (data != null && data['accessToken'] != null) {
          final newTokens = AuthTokens(
            accessToken: data['accessToken'] as String,
            refreshToken: (data['refreshToken'] as String?) ?? tokens.refreshToken,
          );
          await storage.saveTokens(newTokens);
          return true;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Formats user-friendly error message from DioException.
  static String formatErrorMessage(Object error) {
    if (error is DioException) {
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        return 'Connection timed out. Please check your network connection.';
      }
      if (error.type == DioExceptionType.connectionError) {
        return 'Unable to reach the FieldSure server. Please check your connection.';
      }
      final responseData = error.response?.data;
      if (responseData is Map<String, dynamic>) {
        final message = responseData['message'];
        if (message is String) return message;
        if (message is List && message.isNotEmpty) return message.first.toString();
      }
      if (error.response?.statusCode == 401) {
        return 'Invalid badge ID, email, or password.';
      }
      if (error.response?.statusCode == 403) {
        return 'Access denied. Your account is deactivated or unauthorized.';
      }
      if (error.response?.statusCode == 429) {
        return 'Too many login attempts. Please wait a moment and try again.';
      }
    }
    return error.toString();
  }
}
