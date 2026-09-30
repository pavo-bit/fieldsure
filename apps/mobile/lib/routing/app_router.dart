import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/models/auth_state.dart';
import '../features/auth/presentation/controllers/auth_controller.dart';
import '../features/auth/presentation/screens/splash_screen.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../features/tests/presentation/screens/new_test_screen.dart';
import '../features/tests/presentation/screens/kit_selection_screen.dart';
import '../features/tests/presentation/screens/test_preparation_screen.dart';
import '../features/tests/presentation/screens/test_detail_screen.dart';
import '../features/camera/presentation/screens/camera_capture_screen.dart';
import '../features/camera/presentation/screens/camera_preview_screen.dart';
import '../features/tests/presentation/screens/processing_screen.dart';
import '../features/tests/presentation/screens/evidence_record_screen.dart';
import '../features/tests/presentation/screens/history_screen.dart';

/// Notifier to trigger GoRouter re-evaluation when AuthState changes.
class _AuthListenable extends ChangeNotifier {
  _AuthListenable(AuthState state) : _state = state;

  AuthState _state;

  AuthState get state => _state;

  set state(AuthState value) {
    if (_state != value) {
      _state = value;
      notifyListeners();
    }
  }
}

final _authListenableProvider = Provider<_AuthListenable>((ref) {
  final initial = ref.read(authControllerProvider);
  final listenable = _AuthListenable(initial);

  ref.listen<AuthState>(authControllerProvider, (prev, next) {
    listenable.state = next;
  });

  return listenable;
});

/// Provider for the application router with reactive auth guards.
final appRouterProvider = Provider<GoRouter>((ref) {
  final authListenable = ref.watch(_authListenableProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: authListenable,
    debugLogDiagnostics: false,
    redirect: (BuildContext context, GoRouterState state) {
      final auth = authListenable.state;
      final location = state.uri.path;

      final isSplash = location == '/splash';
      final isLogin = location == '/login';

      // 1. App launching: stay on splash until session status checked
      if (auth.status == AuthStatus.initial) {
        return isSplash ? null : '/splash';
      }

      // 2. Authenticated user
      if (auth.isAuthenticated) {
        // If on splash or login, forward to dashboard
        if (isSplash || isLogin) {
          return '/dashboard';
        }
        return null;
      }

      // 3. Unauthenticated / Error state
      if (!auth.isAuthenticated) {
        // If on protected screen, redirect to login
        if (!isLogin && !isSplash) {
          return '/login';
        }
        if (isSplash) {
          return '/login';
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        name: 'dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/history',
        name: 'history',
        builder: (context, state) => const HistoryScreen(),
      ),
      GoRoute(
        path: '/tests/new',
        name: 'new_test',
        builder: (context, state) => const NewTestScreen(),
      ),
      GoRoute(
        path: '/tests/new/kit',
        name: 'kit_selection',
        builder: (context, state) => const KitSelectionScreen(),
      ),
      GoRoute(
        path: '/tests/new/preparation',
        name: 'test_preparation',
        builder: (context, state) => const TestPreparationScreen(),
      ),
      GoRoute(
        path: '/tests/:id/capture',
        name: 'camera_capture',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return CameraCaptureScreen(testId: id);
        },
      ),
      GoRoute(
        path: '/tests/:id/preview',
        name: 'camera_preview',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final imagePath = state.extra as String;
          return CameraPreviewScreen(testId: id, imagePath: imagePath);
        },
      ),
      GoRoute(
        path: '/tests/:id/process',
        name: 'test_processing',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ProcessingScreen(testId: id);
        },
      ),
      GoRoute(
        path: '/tests/:id',
        name: 'test_detail',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return TestDetailScreen(testId: id);
        },
      ),
      GoRoute(
        path: '/tests/:id/evidence',
        name: 'evidence_record',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return EvidenceRecordScreen(testId: id);
        },
      ),
    ],
  );
});
