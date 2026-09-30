import 'dart:async';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../database/database_provider.dart';
import '../network/api_client.dart';
import 'package:drift/drift.dart' as drift;

/// Simplified sync engine with exponential backoff and conflict detection.
/// 
/// This version focuses on core sync functionality without complex Drift queries.
/// In production, enhance with proper ordering and batch processing.
class SimpleSyncEngine {
  final AppDatabase _db;
  final ApiClient _apiClient;

  bool _isSyncing = false;

  SimpleSyncEngine(this._db, this._apiClient);

  /// Sync all pending operations.
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
      // Get all pending operations
      // Note: In production, add proper ordering and batching
      final pendingOps = await _db.select(_db.syncQueue).get();
      
      final pendingOnly = pendingOps.where((op) => 
        op.status == 'PENDING' || op.status == 'REQUIRES_RETRY'
      ).toList();

      if (pendingOnly.isEmpty) {
        return SyncResult(success: true, message: 'Nothing to sync');
      }

      for (final op in pendingOnly) {
        try {
          await _processOperation(op);
          successCount++;
        } on DioException catch (e) {
          if (e.response?.statusCode == 409) {
            // Conflict detected
            await _markAsConflict(op.id, e.response?.data.toString());
            conflictCount++;
          } else {
            // Other error - retry with backoff
            await _incrementRetry(op.id);
            failureCount++;
          }
        } catch (e) {
          await _incrementRetry(op.id);
          failureCount++;
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

  Future<void> _processOperation(SyncQueueData op) async {
    // Calculate backoff delay
    if (op.retryCount > 0) {
      final delay = _calculateBackoffDelay(op.retryCount);
      await Future.delayed(delay);
    }

    // Process based on operation type
    switch (op.operationType) {
      case 'CREATE_TEST':
        await _apiClient.dio.post('/tests', data: op.payload);
        break;
      case 'UPDATE_TEST':
        await _apiClient.dio.put('/tests/${op.testId}', data: op.payload);
        break;
      case 'UPLOAD_IMAGE':
        // Handle image upload
        break;
      default:
        throw UnimplementedError('Operation type ${op.operationType} not implemented');
    }

    // Mark as completed
    await _markAsCompleted(op.id);
  }

  Duration _calculateBackoffDelay(int retryCount) {
    const baseDelay = Duration(seconds: 2);
    const maxDelay = Duration(minutes: 5);
    const jitterPercent = 0.2; // ±20% jitter

    // Exponential: 2^retryCount * baseDelay
    final exponentialSeconds = pow(2, retryCount) * baseDelay.inSeconds;
    final cappedSeconds = min(exponentialSeconds.toInt(), maxDelay.inSeconds);

    // Add jitter
    final random = Random();
    final jitter = (random.nextDouble() - 0.5) * 2 * jitterPercent;
    final delayWithJitter = cappedSeconds * (1 + jitter);

    return Duration(seconds: delayWithJitter.round());
  }

  Future<void> _markAsCompleted(String opId) async {
    await _db.update(_db.syncQueue).write(
      SyncQueueCompanion(
        status: drift.Value('COMPLETED'),
      ),
    );
  }

  Future<void> _markAsConflict(String opId, String? error) async {
    await _db.update(_db.syncQueue).write(
      SyncQueueCompanion(
        status: drift.Value('CONFLICT'),
        lastError: drift.Value(error),
      ),
    );
  }

  Future<void> _incrementRetry(String opId) async {
    final op = await (_db.select(_db.syncQueue)..where((q) => q.id.equals(opId))).getSingle();
    
    await _db.update(_db.syncQueue).write(
      SyncQueueCompanion(
        retryCount: drift.Value(op.retryCount + 1),
        lastAttemptAt: drift.Value(DateTime.now()),
        status: drift.Value('REQUIRES_RETRY'),
      ),
    );
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

/// Provider for sync engine
final simpleSyncEngineProvider = Provider<SimpleSyncEngine>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final apiClient = ref.watch(apiClientProvider);
  return SimpleSyncEngine(db, apiClient);
});
