import 'dart:async';
import 'dart:math';
import 'package:drift/drift.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../network/api_client.dart';
import 'sync_operation.dart';
import 'sync_error_mapper.dart';

/// Enhanced sync engine with exponential backoff, ordered operations,
/// and conflict resolution.
class SyncEngine {
  final AppDatabase _db;
  final ApiClient _apiClient;
  final Ref _ref;

  bool _isSyncing = false;
  Timer? _scheduledSync;

  SyncEngine(this._db, this._apiClient, this._ref);

  /// Start background sync worker.
  void startPeriodicSync(Duration interval) {
    _scheduledSync?.cancel();
    _scheduledSync = Timer.periodic(interval, (_) => syncAll());
  }

  /// Stop background sync.
  void stopPeriodicSync() {
    _scheduledSync?.cancel();
    _scheduledSync = null;
  }

  /// Sync all pending operations with exponential backoff.
  Future<SyncResult> syncAll() async {
    if (_isSyncing) {
      return SyncResult(
        success: false,
        message: 'Sync already in progress',
      );
    }

    _isSyncing = true;
    int successCount = 0;
    int failureCount = 0;
    int conflictCount = 0;

    try {
      // Fetch pending operations ordered by creation time
      final pendingOps = await (_db.select(_db.syncQueue)
            ..where((q) => q.status.isIn(['PENDING', 'REQUIRES_RETRY']))
            ..orderBy([(q) => OrderingTerm(expression: q.createdAt)]))
          .get();

      if (pendingOps.isEmpty) {
        return SyncResult(success: true, message: 'Nothing to sync');
      }

      // Group operations by test ID to ensure ordering
      final operationsByTest = <String, List<SyncQueueData>>{};
      for (final op in pendingOps) {
        operationsByTest.putIfAbsent(op.testId, () => []).add(op);
      }

      // Process each test's operations in sequence
      for (final entry in operationsByTest.entries) {
        final testId = entry.key;
        final operations = entry.value;

        // Sort operations by dependency order
        operations.sort((a, b) => _operationPriority(a).compareTo(_operationPriority(b)));

        for (final op in operations) {
          final result = await _processOperationWithBackoff(op);
          
          if (result.success) {
            successCount++;
          } else if (result.isConflict) {
            conflictCount++;
          } else {
            failureCount++;
            
            // Stop processing this test's operations if one fails
            break;
          }
        }
      }

      return SyncResult(
        success: failureCount == 0 && conflictCount == 0,
        message: 'Synced: $successCount, Failed: $failureCount, Conflicts: $conflictCount',
        successCount: successCount,
        failureCount: failureCount,
        conflictCount: conflictCount,
      );
    } finally {
      _isSyncing = false;
    }
  }

  /// Get operation priority for ordering.
  int _operationPriority(SyncQueueData op) {
    switch (op.operationType) {
      case 'CREATE_TEST':
        return 1;
      case 'UPLOAD_IMAGE':
        return 2;
      case 'PROCESS_TEST':
        return 3;
      case 'UPDATE_STATUS':
        return 4;
      default:
        return 99;
    }
  }

  /// Process a single operation with exponential backoff.
  Future<OperationResult> _processOperationWithBackoff(SyncQueueData op) async {
    const maxRetries = 5;
    const baseDelay = Duration(seconds: 2);
    const maxDelay = Duration(minutes: 5);

    if (op.retryCount >= maxRetries) {
      await _markOperationFailed(op, 'Max retries exceeded');
      return OperationResult(success: false, message: 'Max retries exceeded');
    }

    // Mark as syncing
    await (_db.update(_db.syncQueue)..where((q) => q.id.equals(op.id)))
        .write(SyncQueueCompanion(
          status: const Value('SYNCING'),
          lastAttemptAt: Value(DateTime.now()),
        ));

    try {
      await _processOperation(op);
      
      // Mark as synced
      await (_db.update(_db.syncQueue)..where((q) => q.id.equals(op.id)))
          .write(const SyncQueueCompanion(
            status: Value('SYNCED'),
            lastError: Value(null),
          ));

      return OperationResult(success: true);
    } on DioException catch (e) {
      return await _handleDioError(op, e);
    } catch (e) {
      return await _handleGenericError(op, e);
    }
  }

  /// Process a single sync operation.
  Future<void> _processOperation(SyncQueueData op) async {
    final payload = SyncOperation.decodePayload(op.payload);

    switch (op.operationType) {
      case 'CREATE_TEST':
        await _syncCreateTest(op.testId, payload);
        break;
      
      case 'UPLOAD_IMAGE':
        await _syncUploadImage(op.testId, payload, op.fileReference);
        break;
      
      case 'PROCESS_TEST':
        await _syncProcessTest(op.testId, payload);
        break;
      
      case 'UPDATE_STATUS':
        await _syncUpdateStatus(op.testId, payload);
        break;
      
      default:
        throw UnimplementedError('Unknown operation type: ${op.operationType}');
    }
  }

  Future<void> _syncCreateTest(String testId, Map<String, dynamic> payload) async {
    final response = await _apiClient.dio.post('/tests', data: payload);
    final data = response.data['data'];
    
    // Update local test with server-assigned test number
    await (_db.update(_db.localTests)..where((t) => t.id.equals(testId)))
        .write(LocalTestsCompanion(
          testNumber: Value(data['testNumber']),
          needsSync: const Value(false),
        ));
  }

  Future<void> _syncUploadImage(
    String testId,
    Map<String, dynamic> payload,
    String? fileReference,
  ) async {
    if (fileReference == null) {
      throw StateError('File reference required for image upload');
    }

    // TODO: Implement resumable multipart upload with progress tracking
    // For now, use simple upload
    final formData = FormData.fromMap({
      'image': await MultipartFile.fromFile(fileReference),
      'clientHash': payload['clientHash'],
      'captureMetadata': payload['captureMetadata'],
    });

    await _apiClient.dio.post(
      '/tests/$testId/image',
      data: formData,
      options: Options(
        headers: {'Content-Type': 'multipart/form-data'},
      ),
    );

    await (_db.update(_db.localEvidence)..where((e) => e.testId.equals(testId)))
        .write(const LocalEvidenceCompanion(
          status: Value('SYNCED'),
          needsSync: Value(false),
        ));
  }

  Future<void> _syncProcessTest(String testId, Map<String, dynamic> payload) async {
    final response = await _apiClient.dio.post(
      '/tests/$testId/process',
      data: payload,
    );
    
    final data = response.data['data'];
    
    if (data['classification'] != null) {
      await (_db.update(_db.localTests)..where((t) => t.id.equals(testId)))
          .write(LocalTestsCompanion(
            status: Value(data['status'] ?? 'COMPLETED'),
            result: Value(data['classification']['result']),
            needsSync: const Value(false),
          ));
    }
  }

  Future<void> _syncUpdateStatus(String testId, Map<String, dynamic> payload) async {
    await _apiClient.dio.patch('/tests/$testId/status', data: payload);
    
    await (_db.update(_db.localTests)..where((t) => t.id.equals(testId)))
        .write(LocalTestsCompanion(
          status: Value(payload['status']),
          needsSync: const Value(false),
        ));
  }

  Future<OperationResult> _handleDioError(SyncQueueData op, DioException error) async {
    final statusCode = error.response?.statusCode;
    
    // Conflict - requires manual resolution
    if (statusCode == 409) {
      await (_db.update(_db.syncQueue)..where((q) => q.id.equals(op.id)))
          .write(SyncQueueCompanion(
            status: const Value('CONFLICT'),
            lastError: Value(SyncErrorMapper.getErrorMessage(error)),
          ));
      
      return OperationResult(success: false, isConflict: true);
    }

    // Rate limited - honor Retry-After header
    if (statusCode == 429) {
      final retryAfter = error.response?.headers.value('retry-after');
      final delay = retryAfter != null 
          ? Duration(seconds: int.tryParse(retryAfter) ?? 60)
          : _calculateBackoffDelay(op.retryCount);
      
      await (_db.update(_db.syncQueue)..where((q) => q.id.equals(op.id)))
          .write(SyncQueueCompanion(
            status: const Value('REQUIRES_RETRY'),
            retryCount: Value(op.retryCount + 1),
            lastAttemptAt: Value(DateTime.now().add(delay)),
            lastError: Value('Rate limited. Retry after ${delay.inSeconds}s'),
          ));
      
      return OperationResult(success: false, message: 'Rate limited');
    }

    // Client errors (4xx) - likely won't succeed on retry
    if (statusCode != null && statusCode >= 400 && statusCode < 500) {
      await _markOperationFailed(op, SyncErrorMapper.getErrorMessage(error));
      return OperationResult(success: false);
    }

    // Server errors (5xx) or network errors - retry with backoff
    // delay = _calculateBackoffDelay(op.retryCount);
    await (_db.update(_db.syncQueue)..where((q) => q.id.equals(op.id)))
        .write(SyncQueueCompanion(
          status: const Value('REQUIRES_RETRY'),
          retryCount: Value(op.retryCount + 1),
          lastAttemptAt: Value(DateTime.now()),
          lastError: Value(SyncErrorMapper.getErrorMessage(error)),
        ));
    
    return OperationResult(success: false);
  }

  Future<OperationResult> _handleGenericError(SyncQueueData op, Object error) async {
    await (_db.update(_db.syncQueue)..where((q) => q.id.equals(op.id)))
        .write(SyncQueueCompanion(
          status: const Value('REQUIRES_RETRY'),
          retryCount: Value(op.retryCount + 1),
          lastAttemptAt: Value(DateTime.now()),
          lastError: Value(error.toString()),
        ));
    
    return OperationResult(success: false, message: error.toString());
  }

  Future<void> _markOperationFailed(SyncQueueData op, String error) async {
    await (_db.update(_db.syncQueue)..where((q) => q.id.equals(op.id)))
        .write(SyncQueueCompanion(
          status: const Value('FAILED'),
          lastError: Value(error),
        ));
  }

  /// Calculate exponential backoff delay with jitter.
  Duration _calculateBackoffDelay(int retryCount) {
    const baseSeconds = 2;
    const maxSeconds = 300; // 5 minutes
    
    final exponentialDelay = baseSeconds * pow(2, retryCount).toInt();
    final cappedDelay = min(exponentialDelay, maxSeconds);
    
    // Add jitter (±20%)
    final random = Random();
    final jitter = cappedDelay * (0.8 + random.nextDouble() * 0.4);
    
    return Duration(seconds: jitter.toInt());
  }

  void dispose() {
    stopPeriodicSync();
  }
}

class SyncResult {
  final bool success;
  final String message;
  final int successCount;
  final int failureCount;
  final int conflictCount;

  SyncResult({
    required this.success,
    required this.message,
    this.successCount = 0,
    this.failureCount = 0,
    this.conflictCount = 0,
  });
}

class OperationResult {
  final bool success;
  final bool isConflict;
  final String? message;

  OperationResult({
    required this.success,
    this.isConflict = false,
    this.message,
  });
}
