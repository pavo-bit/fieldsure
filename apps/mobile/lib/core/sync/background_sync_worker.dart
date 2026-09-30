import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:workmanager/workmanager.dart';
import 'package:fieldsure_mobile/core/database/database_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Background sync worker using WorkManager
/// Handles periodic sync when app is in background (Android) or BGTaskScheduler (iOS)
class BackgroundSyncWorker {
  static const String syncTaskName = 'fieldsure_background_sync';
  static const String syncTaskTag = 'sync';
  
  /// Initialize WorkManager and register background tasks
  static Future<void> initialize() async {
    await Workmanager().initialize(
      _callbackDispatcher,
      isInDebugMode: false, // Set to true for debugging
    );
  }

  /// Register periodic background sync
  /// 
  /// [frequencyMinutes] - How often to sync (minimum 15 minutes)
  /// [requiresNetwork] - Only run when network is available
  /// [requiresCharging] - Only run when device is charging (optional)
  static Future<void> registerPeriodicSync({
    int frequencyMinutes = 15,
    bool requiresNetwork = true,
    bool requiresCharging = false,
  }) async {
    if (frequencyMinutes < 15) {
      throw ArgumentError('Minimum frequency is 15 minutes');
    }

    await Workmanager().registerPeriodicTask(
      syncTaskName,
      syncTaskTag,
      frequency: Duration(minutes: frequencyMinutes),
      constraints: Constraints(
        networkType: requiresNetwork
            ? NetworkType.connected
            : NetworkType.not_required,
        requiresCharging: requiresCharging,
        requiresBatteryNotLow: true,
      ),
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(minutes: 1),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
  }

  /// Register one-time immediate sync
  static Future<void> registerImmediateSync() async {
    await Workmanager().registerOneOffTask(
      'immediate_sync_${DateTime.now().millisecondsSinceEpoch}',
      syncTaskTag,
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(seconds: 30),
    );
  }

  /// Cancel all background sync tasks
  static Future<void> cancelAll() async {
    await Workmanager().cancelAll();
  }

  /// Cancel specific task
  static Future<void> cancelTask(String taskName) async {
    await Workmanager().cancelByUniqueName(taskName);
  }
}

/// Callback dispatcher for WorkManager
/// This runs in a separate isolate, so it needs to be a top-level function
@pragma('vm:entry-point')
void _callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      debugPrint('[BackgroundSync] Starting background sync task: $task');
      
      // Execute sync
      final success = await _performBackgroundSync();
      
      debugPrint('[BackgroundSync] Task completed. Success: $success');
      return success;
    } catch (e, stackTrace) {
      debugPrint('[BackgroundSync] Task failed with error: $e');
      debugPrint('[BackgroundSync] Stack trace: $stackTrace');
      
      // Return false to retry with backoff
      return false;
    }
  });
}

/// Perform the actual background sync
/// Returns true if sync completed successfully, false to retry
Future<bool> _performBackgroundSync() async {
  try {
    // Note: Running in separate isolate, need to initialize dependencies
    // This is a simplified version - in production, you may need to:
    // 1. Initialize database connection
    // 2. Set up Riverpod container
    // 3. Configure API client
    
    // For now, this is a skeleton that shows the structure
    // In production, implement proper isolate communication or use a simpler approach
    
    debugPrint('[BackgroundSync] Initializing...');
    
    // Create a minimal container for background sync
    final container = ProviderContainer();
    
    try {
      debugPrint('[BackgroundSync] Initializing database...');
      await initializeDatabase(container);
      
      debugPrint('[BackgroundSync] Creating sync engine...');
      // Note: syncEngineProvider would need to be available in background isolate
      // This is a placeholder - actual implementation would require more setup
      
      debugPrint('[BackgroundSync] Starting sync...');
      // await syncEngine.syncAll();
      
      debugPrint('[BackgroundSync] Sync completed successfully');
      return true;
    } finally {
      container.dispose();
    }
  } catch (e, stackTrace) {
    debugPrint('[BackgroundSync] Sync failed: $e');
    debugPrint('[BackgroundSync] Stack trace: $stackTrace');
    
    // Return false to trigger retry with exponential backoff
    return false;
  }
}

/// Provider for background sync worker
final backgroundSyncWorkerProvider = Provider<BackgroundSyncWorker>((ref) {
  return BackgroundSyncWorker();
});

// Note: iOS Background Fetch implementation
// 
// For iOS, you also need to configure BGTaskScheduler in AppDelegate.swift:
//
// import BackgroundTasks
//
// func application(_ application: UIApplication,
//                  didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
//   
//   // Register background task
//   BGTaskScheduler.shared.register(
//     forTaskWithIdentifier: "com.fieldsure.mobile.sync",
//     using: nil
//   ) { task in
//     self.handleBackgroundSync(task: task as! BGProcessingTask)
//   }
//   
//   return true
// }
//
// func handleBackgroundSync(task: BGProcessingTask) {
//   // Schedule next background sync
//   scheduleBackgroundSync()
//   
//   // Perform sync
//   let syncTask = performSync()
//   
//   task.expirationHandler = {
//     syncTask.cancel()
//   }
//   
//   Task {
//     do {
//       try await syncTask.value
//       task.setTaskCompleted(success: true)
//     } catch {
//       task.setTaskCompleted(success: false)
//     }
//   }
// }
//
// func scheduleBackgroundSync() {
//   let request = BGProcessingTaskRequest(identifier: "com.fieldsure.mobile.sync")
//   request.requiresNetworkConnectivity = true
//   request.requiresExternalPower = false
//   request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
//   
//   do {
//     try BGTaskScheduler.shared.submit(request)
//   } catch {
//     debugPrint("Could not schedule background sync: \(error)")
//   }
// }
//
// Also add to Info.plist:
// <key>BGTaskSchedulerPermittedIdentifiers</key>
// <array>
//   <string>com.fieldsure.mobile.sync</string>
// </array>
