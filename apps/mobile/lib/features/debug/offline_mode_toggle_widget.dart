import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/offline_mode_provider.dart';
import '../../core/config/offline_config.dart';

/// Debug widget for toggling offline mode during testing.
/// 
/// IMPORTANT: This should be disabled or removed in production builds.
/// Use --dart-define=ENABLE_OFFLINE_TOGGLE=false in production.
class OfflineModeToggleWidget extends ConsumerWidget {
  const OfflineModeToggleWidget({super.key});
  
  static const bool _enableToggle = bool.fromEnvironment(
    'ENABLE_OFFLINE_TOGGLE',
    defaultValue: true, // Enable by default for development
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Don't show in production builds
    if (!_enableToggle) {
      return const SizedBox.shrink();
    }
    
    final isOfflineMode = ref.watch(offlineModeToggleProvider);
    final offlineStatus = ref.watch(offlineStatusProvider);
    
    return Material(
      color: Colors.black87,
      elevation: 8,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getStatusIcon(offlineStatus),
                  color: _getStatusColor(offlineStatus),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  offlineStatus.statusDescription,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 12),
                Switch(
                  value: isOfflineMode,
                  onChanged: (_) {
                    ref.read(offlineModeToggleProvider.notifier).toggle();
                    
                    // Show snackbar
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isOfflineMode 
                            ? 'Switched to Online Mode'
                            : 'Switched to Offline Mode',
                        ),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  activeColor: Colors.orange,
                  activeTrackColor: Colors.orange.withAlpha(128),
                ),
                Text(
                  isOfflineMode ? 'OFFLINE' : 'AUTO',
                  style: TextStyle(
                    color: isOfflineMode ? Colors.orange : Colors.green,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (offlineStatus.pendingSyncCount > 0) ...[
              const SizedBox(height: 4),
              Text(
                '${offlineStatus.pendingSyncCount} operations pending',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                ),
              ),
            ],
            if (offlineStatus.hasErrors) ...[
              const SizedBox(height: 4),
              Text(
                '${offlineStatus.syncErrors.length} sync errors',
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  IconData _getStatusIcon(OfflineStatus status) {
    if (status.isSyncing) return Icons.sync;
    if (!status.isOnline) return Icons.cloud_off;
    if (status.hasErrors) return Icons.error_outline;
    if (status.needsSync) return Icons.cloud_upload;
    return Icons.cloud_done;
  }
  
  Color _getStatusColor(OfflineStatus status) {
    if (!status.isOnline) return Colors.orange;
    if (status.hasErrors) return Colors.red;
    if (status.needsSync) return Colors.yellow;
    return Colors.green;
  }
}

/// Floating action button style offline mode toggle
class OfflineModeFloatingToggle extends ConsumerWidget {
  const OfflineModeFloatingToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const enableToggle = bool.fromEnvironment(
      'ENABLE_OFFLINE_TOGGLE',
      defaultValue: true,
    );
    
    if (!enableToggle) {
      return const SizedBox.shrink();
    }
    
    final isOfflineMode = ref.watch(offlineModeToggleProvider);
    final offlineStatus = ref.watch(offlineStatusProvider);
    
    return FloatingActionButton.small(
      onPressed: () {
        ref.read(offlineModeToggleProvider.notifier).toggle();
      },
      backgroundColor: isOfflineMode ? Colors.orange : Colors.blue,
      child: Badge(
        label: offlineStatus.pendingSyncCount > 0 
            ? Text('${offlineStatus.pendingSyncCount}')
            : null,
        child: Icon(
          isOfflineMode ? Icons.cloud_off : Icons.cloud,
          color: Colors.white,
        ),
      ),
    );
  }
}
