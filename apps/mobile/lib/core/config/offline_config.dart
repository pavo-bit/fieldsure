/// Offline mode configuration for FieldSure mobile app.
///
/// Enables operation without network connectivity by:
/// 1. Using local Drift database for all data storage
/// 2. Queuing sync operations for later
/// 3. Caching API responses
/// 4. Deferring image uploads to presigned URLs

enum OfflineMode {
  /// Normal mode: sync immediately when network available
  auto,
  
  /// Force offline: never attempt network operations
  forceOffline,
  
  /// Online only: fail if network unavailable
  onlineOnly,
}

class OfflineConfig {
  /// Current offline mode
  final OfflineMode mode;
  
  /// Maximum number of pending sync operations before alerting user
  final int maxPendingSyncOps;
  
  /// Maximum age of cached data before requiring refresh
  final Duration maxCacheAge;
  
  /// Enable optimistic local updates (update UI before server confirms)
  final bool enableOptimisticUpdates;
  
  /// Maximum size of local database before pruning
  final int maxLocalDbSizeMb;
  
  /// Retry strategy for failed sync operations
  final OfflineRetryStrategy retryStrategy;

  const OfflineConfig({
    this.mode = OfflineMode.auto,
    this.maxPendingSyncOps = 100,
    this.maxCacheAge = const Duration(days: 7),
    this.enableOptimisticUpdates = true,
    this.maxLocalDbSizeMb = 500,
    this.retryStrategy = const OfflineRetryStrategy(),
  });

  /// Production configuration
  static const production = OfflineConfig(
    mode: OfflineMode.auto,
    maxPendingSyncOps: 50,
    maxCacheAge: Duration(days: 3),
    enableOptimisticUpdates: true,
    maxLocalDbSizeMb: 200,
  );

  /// Development configuration (more permissive)
  static const development = OfflineConfig(
    mode: OfflineMode.auto,
    maxPendingSyncOps: 1000,
    maxCacheAge: Duration(days: 30),
    enableOptimisticUpdates: true,
    maxLocalDbSizeMb: 1000,
  );

  /// Force offline for testing
  static const testing = OfflineConfig(
    mode: OfflineMode.forceOffline,
    maxPendingSyncOps: 1000,
    enableOptimisticUpdates: true,
  );

  bool get isOnlineOnly => mode == OfflineMode.onlineOnly;
  bool get canWorkOffline => mode != OfflineMode.onlineOnly;
  bool get isForceOffline => mode == OfflineMode.forceOffline;
}

class OfflineRetryStrategy {
  /// Initial retry delay
  final Duration initialDelay;
  
  /// Maximum retry delay (exponential backoff cap)
  final Duration maxDelay;
  
  /// Maximum number of retry attempts
  final int maxAttempts;
  
  /// Exponential backoff multiplier
  final double backoffMultiplier;

  const OfflineRetryStrategy({
    this.initialDelay = const Duration(seconds: 5),
    this.maxDelay = const Duration(minutes: 30),
    this.maxAttempts = 10,
    this.backoffMultiplier = 2.0,
  });

  /// Calculate delay for retry attempt (0-indexed)
  Duration delayForAttempt(int attempt) {
    if (attempt >= maxAttempts) {
      throw StateError('Exceeded maximum retry attempts');
    }

    final delay = initialDelay * (backoffMultiplier * attempt);
    return delay > maxDelay ? maxDelay : delay;
  }
}

/// Sync operation types that can be queued for offline processing
enum SyncOperationType {
  createTest,
  updateTest,
  uploadImage,
  createEvidence,
  updateOperatorInterpretation,
  submitForReview,
}

/// Represents a pending sync operation
class PendingSyncOperation {
  final String id;
  final SyncOperationType type;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int retryCount;
  final DateTime? nextRetryAt;
  final String? errorMessage;

  const PendingSyncOperation({
    required this.id,
    required this.type,
    required this.payload,
    required this.createdAt,
    this.retryCount = 0,
    this.nextRetryAt,
    this.errorMessage,
  });

  bool get canRetry => retryCount < 10;
  bool get isRetryDue {
    if (nextRetryAt == null) return true;
    return DateTime.now().isAfter(nextRetryAt!);
  }

  PendingSyncOperation withRetry(Duration nextDelay, String error) {
    return PendingSyncOperation(
      id: id,
      type: type,
      payload: payload,
      createdAt: createdAt,
      retryCount: retryCount + 1,
      nextRetryAt: DateTime.now().add(nextDelay),
      errorMessage: error,
    );
  }
}

/// Offline status information
class OfflineStatus {
  final bool isOnline;
  final int pendingSyncCount;
  final DateTime? lastSyncAt;
  final Duration? timeSinceLastSync;
  final List<String> syncErrors;
  final bool isSyncing;

  const OfflineStatus({
    required this.isOnline,
    required this.pendingSyncCount,
    this.lastSyncAt,
    this.timeSinceLastSync,
    this.syncErrors = const [],
    this.isSyncing = false,
  });

  bool get needsSync => pendingSyncCount > 0;
  bool get hasErrors => syncErrors.isNotEmpty;
  bool get isHealthy => isOnline && !needsSync && !hasErrors;

  String get statusDescription {
    if (isSyncing) return 'Syncing...';
    if (!isOnline) return 'Offline';
    if (hasErrors) return 'Sync errors';
    if (needsSync) return '$pendingSyncCount pending';
    return 'Up to date';
  }
}
