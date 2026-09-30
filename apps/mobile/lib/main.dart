import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import 'core/theme/app_theme.dart';
import 'core/config/environment.dart';
import 'core/database/database_provider.dart';
import 'core/database/app_database.dart';
import 'routing/app_router.dart';
import 'core/network/sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Validate environment configuration
  try {
    EnvironmentConfig.current.validate();
  } catch (e) {
    // In production, this will crash the app if HTTPS is not used
    debugPrint('Environment validation error: $e');
    if (Environment.current.isProduction) {
      // Crash in production for security violations
      rethrow;
    }
  }

  // Initialize encrypted database
  final container = ProviderContainer();
  late final AppDatabase database;
  
  try {
    database = await initializeDatabase(container);
  } catch (e) {
    debugPrint('Failed to initialize database: $e');
    
    // Show error screen
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Database initialization failed',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('Error: $e'),
              ],
            ),
          ),
        ),
      ),
    );
    return;
  }

  // Lock orientation to portrait for consistency
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
      ],
      child: const FieldSureApp(),
    ),
  );
}

/// Root application widget for FieldSure.
class FieldSureApp extends ConsumerWidget {
  const FieldSureApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Eagerly initialize SyncService so the connectivity listener starts
    ref.read(syncServiceProvider);
    
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'FieldSure',
      debugShowCheckedModeBanner: Environment.current.isDev,
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}

