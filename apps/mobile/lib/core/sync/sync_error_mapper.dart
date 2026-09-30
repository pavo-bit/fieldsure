import 'package:dio/dio.dart';

/// Maps backend error codes to user-friendly localized messages.
class SyncErrorMapper {
  /// Get user-friendly error message from Dio exception.
  static String getErrorMessage(DioException error) {
    final statusCode = error.response?.statusCode;
    final data = error.response?.data;
    
    // Try to extract error code from response
    String? errorCode;
    if (data is Map && data.containsKey('error')) {
      if (data['error'] is Map && data['error'].containsKey('code')) {
        errorCode = data['error']['code'];
      } else if (data['error'] is String) {
        errorCode = data['error'];
      }
    }

    // Map error code to message
    if (errorCode != null) {
      return _getMessageForErrorCode(errorCode);
    }

    // Fallback to HTTP status code
    return _getMessageForStatusCode(statusCode);
  }

  static String _getMessageForErrorCode(String code) {
    // TODO: Integrate with localization system
    switch (code) {
      case 'AUTH_SESSION_EXPIRED':
      case 'AUTH_INVALID_CREDENTIALS':
        return 'Session expired. Please login again.';
      
      case 'AUTH_TOKEN_FAMILY_COMPROMISED':
        return 'Security issue detected. Please login again.';
      
      case 'TEST_NOT_FOUND':
        return 'Test not found.';
      
      case 'TEST_TRANSITION_NOT_ALLOWED_BY_CLIENT':
        return 'This status change is not allowed.';
      
      case 'IMAGE_HASH_MISMATCH':
        return 'Image verification failed. Please recapture.';
      
      case 'IMAGE_TOO_LARGE':
        return 'Image file is too large.';
      
      case 'KIT_REAGENT_EXPIRED':
        return 'Test kit reagent has expired.';
      
      case 'READING_WINDOW_VIOLATION':
        return 'Image captured outside the recommended reading window.';
      
      case 'SYNC_CONFLICT':
      case 'CONFLICT':
        return 'Sync conflict detected. Manual resolution required.';
      
      case 'RATE_LIMITED':
        return 'Too many requests. Please wait and try again.';
      
      case 'NETWORK_ERROR':
        return 'Network error. Please check your connection.';
      
      default:
        return 'An error occurred: $code';
    }
  }

  static String _getMessageForStatusCode(int? statusCode) {
    if (statusCode == null) {
      return 'Network error. Please check your connection.';
    }

    switch (statusCode) {
      case 400:
        return 'Invalid request. Please try again.';
      case 401:
        return 'Session expired. Please login again.';
      case 403:
        return 'You don\'t have permission for this action.';
      case 404:
        return 'Resource not found.';
      case 409:
        return 'Conflict detected. Manual resolution required.';
      case 413:
        return 'File is too large.';
      case 422:
        return 'Validation error. Please check your input.';
      case 426:
        return 'App update required. Please update to continue.';
      case 429:
        return 'Too many requests. Please wait and try again.';
      case 500:
      case 502:
      case 503:
      case 504:
        return 'Server error. Please try again later.';
      default:
        return 'An error occurred (HTTP $statusCode).';
    }
  }

  /// Determine if error should trigger retry.
  static bool shouldRetry(DioException error) {
    final statusCode = error.response?.statusCode;
    
    // Don't retry client errors (except 408, 429)
    if (statusCode != null && statusCode >= 400 && statusCode < 500) {
      return statusCode == 408 || statusCode == 429;
    }

    // Retry server errors and network errors
    return true;
  }
}
