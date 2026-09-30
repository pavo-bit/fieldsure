import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'api_client.dart';
import '../database/app_database.dart';
import '../database/database_provider.dart';

final syncServiceProvider = Provider<SyncService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final api = ref.watch(apiClientProvider);
  return SyncService(db, api);
});

class SyncService {
  final AppDatabase _db;
  final ApiClient _apiClient;
  bool _isSyncing = false;

  SyncService(this._db, this._apiClient) {
    _listenToConnectivity();
  }

  void _listenToConnectivity() {
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (!results.contains(ConnectivityResult.none)) {
        syncPendingOperations();
      }
    });
  }

  Future<void> enqueueOperation({
    required String testId,
    required String operationType,
    required Map<String, dynamic> payload,
    required String idempotencyKey,
    String? fileReference,
  }) async {
    final companion = SyncQueueCompanion.insert(
      id: DateTime.now().millisecondsSinceEpoch.toString(), // or UUID
      testId: testId,
      operationType: operationType,
      payload: jsonEncode(payload),
      fileReference: Value(fileReference),
      idempotencyKey: idempotencyKey,
      createdAt: DateTime.now(),
    );
    await _db.into(_db.syncQueue).insert(companion);
    syncPendingOperations();
  }

  Future<void> syncPendingOperations() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      // checkConnectivity() removed to prevent race conditions when network is just restored.

      final pendingOps = await (_db.select(_db.syncQueue)
            ..where((q) => q.status.isIn(['PENDING', 'REQUIRES_RETRY']))
            ..orderBy([(q) => OrderingTerm(expression: q.createdAt, mode: OrderingMode.asc)]))
          .get();

      for (final op in pendingOps) {
        await _processOperation(op);
      }
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _processOperation(SyncQueueData op) async {
    await (_db.update(_db.syncQueue)..where((q) => q.id.equals(op.id)))
        .write(const SyncQueueCompanion(status: Value('SYNCING'), lastAttemptAt: Value(null)));

    try {
      final payload = jsonDecode(op.payload) as Map<String, dynamic>;

      final options = Options(headers: {'x-idempotency-key': op.idempotencyKey});

      if (op.operationType == 'CREATE_TEST') {
        final response = await _apiClient.dio.post('/tests', data: payload, options: options);
        final data = response.data['data'];
        
        // Update local test with server assigned testNumber
        await (_db.update(_db.localTests)..where((t) => t.id.equals(op.testId)))
            .write(LocalTestsCompanion(
              testNumber: Value(data['testNumber']),
              needsSync: const Value(false),
            ));
      } else if (op.operationType == 'UPLOAD_IMAGE') {
        // Mock image upload until backend S3 is implemented
        await Future.delayed(const Duration(seconds: 1));
        
        await (_db.update(_db.localEvidence)..where((e) => e.testId.equals(op.testId)))
            .write(const LocalEvidenceCompanion(
              status: Value('SYNCED'),
              needsSync: Value(false),
            ));
      } else if (op.operationType == 'UPDATE_STATUS') {
         await _apiClient.dio.patch('/tests/${op.testId}/status', data: payload, options: options);
      } else if (op.operationType == 'PROCESS_TEST') {
         final response = await _apiClient.dio.post('/tests/${op.testId}/process', data: payload, options: options);
         final data = response.data['data'];
         
         if (data['status'] == 'completed' && data['classification'] != null) {
           await (_db.update(_db.localTests)..where((t) => t.id.equals(op.testId)))
               .write(LocalTestsCompanion(
                 status: const Value('COMPLETED'),
                 result: Value(data['classification']['result']),
                 needsSync: const Value(false),
               ));
         } else if (data['status'] == 'failed') {
           await (_db.update(_db.localTests)..where((t) => t.id.equals(op.testId)))
               .write(const LocalTestsCompanion(
                 status: Value('FAILED'),
                 needsSync: Value(false),
               ));
         }
      }

      // Mark success
      await (_db.update(_db.syncQueue)..where((q) => q.id.equals(op.id)))
          .write(const SyncQueueCompanion(
            status: Value('SYNCED'),
            lastError: Value(null),
          ));

    } catch (e) {
      String? errorMessage;
      String nextStatus = 'REQUIRES_RETRY';
      
      if (e is DioException) {
        if (e.response?.statusCode == 409) {
          nextStatus = 'CONFLICT'; // Might need manual resolution
        }
        errorMessage = e.message;
      } else {
        errorMessage = e.toString();
      }

      await (_db.update(_db.syncQueue)..where((q) => q.id.equals(op.id)))
          .write(SyncQueueCompanion(
            status: Value(nextStatus),
            retryCount: Value(op.retryCount + 1),
            lastAttemptAt: Value(DateTime.now()),
            lastError: Value(errorMessage),
          ));
    }
  }

  Future<int> getPendingCount() async {
    final pending = await (_db.select(_db.syncQueue)..where((q) => q.status.isIn(['PENDING', 'REQUIRES_RETRY']))).get();
    return pending.length;
  }

  Stream<int> watchPendingCount() {
    return (_db.select(_db.syncQueue)..where((q) => q.status.isIn(['PENDING', 'REQUIRES_RETRY', 'SYNCING']))).watch().map((list) => list.length);
  }
}

final pendingSyncCountProvider = StreamProvider.autoDispose<int>((ref) {
  final service = ref.watch(syncServiceProvider);
  return service.watchPendingCount();
});
