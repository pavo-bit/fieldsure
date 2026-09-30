import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'offline_config.dart';

/// Provider for offline mode configuration
final offlineModeConfigProvider = StateProvider<OfflineConfig>((ref) {
  // Default to production config with auto mode
  return OfflineConfig.production;
});

/// Provider that tracks current network connectivity
final connectivityProvider = StreamProvider<List<ConnectivityResult>>((ref) {
  return Connectivity().onConnectivityChanged;
});

/// Provider that determines if device is online
final isOnlineProvider = Provider<bool>((ref) {
  final config = ref.watch(offlineModeConfigProvider);
  
  // If force offline mode, always return false
  if (config.isForceOffline) {
    return false;
  }
  
  // If online only mode or auto mode, check actual connectivity
  final connectivityAsync = ref.watch(connectivityProvider);
  
  return connectivityAsync.when(
    data: (results) => !results.contains(ConnectivityResult.none),
    loading: () => false, // Assume offline while loading
    error: (_, __) => false,
  );
});

/// Provider for offline status information
final offlineStatusProvider = Provider<OfflineStatus>((ref) {
  final isOnline = ref.watch(isOnlineProvider);
  final pendingSyncCount = ref.watch(pendingSyncCountProvider);
  final lastSyncTime = ref.watch(lastSyncTimeProvider);
  final syncErrors = ref.watch(syncErrorsProvider);
  final isSyncing = ref.watch(isSyncingProvider);
  
  final now = DateTime.now();
  final timeSinceLastSync = lastSyncTime != null 
      ? now.difference(lastSyncTime)
      : null;
  
  return OfflineStatus(
    isOnline: isOnline,
    pendingSyncCount: pendingSyncCount,
    lastSyncAt: lastSyncTime,
    timeSinceLastSync: timeSinceLastSync,
    syncErrors: syncErrors,
    isSyncing: isSyncing,
  );
});

/// Provider for pending sync operation count
final pendingSyncCountProvider = StateProvider<int>((ref) => 0);

/// Provider for last sync time
final lastSyncTimeProvider = StateProvider<DateTime?>((ref) => null);

/// Provider for sync errors
final syncErrorsProvider = StateProvider<List<String>>((ref) => []);

/// Provider for sync in progress flag
final isSyncingProvider = StateProvider<bool>((ref) => false);

/// Provider for offline mode toggle (dev/testing only)
/// In production, this should be removed or hidden
final offlineModeToggleProvider = StateNotifierProvider<OfflineModeToggle, bool>((ref) {
  return OfflineModeToggle(ref);
});

class OfflineModeToggle extends StateNotifier<bool> {
  final Ref _ref;
  
  OfflineModeToggle(this._ref) : super(false);
  
  void toggle() {
    state = !state;
    
    // Update offline config based on toggle
    if (state) {
      // Force offline
      _ref.read(offlineModeConfigProvider.notifier).state = 
          const OfflineConfig(mode: OfflineMode.forceOffline);
    } else {
      // Auto mode
      _ref.read(offlineModeConfigProvider.notifier).state = 
          OfflineConfig.production;
    }
  }
  
  void setMode(OfflineMode mode) {
    state = mode == OfflineMode.forceOffline;
    _ref.read(offlineModeConfigProvider.notifier).state = 
        OfflineConfig(mode: mode);
  }
}

/// Extension methods for OfflineStatus
extension OfflineStatusX on OfflineStatus {
  /// Get a color representing the status
  String get statusColor {
    if (!isOnline) return '#FFA500'; // Orange for offline
    if (hasErrors) return '#FF0000'; // Red for errors
    if (needsSync) return '#FFFF00'; // Yellow for pending
    return '#00FF00'; // Green for healthy
  }
  
  /// Get an icon name representing the status
  String get statusIcon {
    if (isSyncing) return 'sync';
    if (!isOnline) return 'cloud_off';
    if (hasErrors) return 'error';
    if (needsSync) return 'cloud_upload';
    return 'cloud_done';
  }
}
