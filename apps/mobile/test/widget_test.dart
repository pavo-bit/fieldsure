import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fieldsure_mobile/core/constants/app_constants.dart';
import 'package:fieldsure_mobile/core/models/user_model.dart';
import 'package:fieldsure_mobile/core/models/auth_tokens.dart';
import 'package:fieldsure_mobile/core/models/auth_state.dart';
import 'package:fieldsure_mobile/core/theme/app_theme.dart';
import 'package:fieldsure_mobile/features/auth/presentation/screens/splash_screen.dart';
import 'package:fieldsure_mobile/features/auth/presentation/screens/login_screen.dart';
import 'package:fieldsure_mobile/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:fieldsure_mobile/features/auth/presentation/controllers/auth_controller.dart';
import 'package:fieldsure_mobile/features/auth/data/auth_repository.dart';
import 'package:fieldsure_mobile/core/storage/secure_storage_service.dart';
import 'package:fieldsure_mobile/core/network/api_client.dart';

class MockAuthRepo implements AuthRepository {
  @override
  Future<({UserModel user, AuthTokens tokens})> login({
    required String email,
    required String password,
  }) async {
    return (
      user: const UserModel(
        id: 'u-1',
        operatorId: 'OP-001',
        name: 'Inspector Vikram',
        email: 'vikram@police.gov.in',
        role: UserRole.operator,
      ),
      tokens: const AuthTokens(
        accessToken: 'access',
        refreshToken: 'refresh',
      ),
    );
  }

  @override
  Future<({UserModel user, AuthTokens tokens})> refreshToken(String refreshToken) async {
    return (
      user: const UserModel(
        id: 'u-1',
        operatorId: 'OP-001',
        name: 'Inspector Vikram',
        email: 'vikram@police.gov.in',
        role: UserRole.operator,
      ),
      tokens: const AuthTokens(
        accessToken: 'access',
        refreshToken: 'refresh',
      ),
    );
  }

  @override
  Future<void> logout() async {}

  @override
  Future<UserModel> getProfile() async => const UserModel(
        id: 'u-1',
        operatorId: 'OP-001',
        name: 'Inspector Vikram',
        email: 'vikram@police.gov.in',
        role: UserRole.operator,
      );
}

class MockStorage implements SecureStorageService {
  @override
  Future<void> saveTokens(AuthTokens tokens) async {}
  @override
  Future<AuthTokens?> getTokens() async => null;
  @override
  Future<String?> getAccessToken() async => null;
  @override
  Future<String?> getRefreshToken() async => null;
  @override
  Future<void> saveUser(UserModel user) async {}
  @override
  Future<UserModel?> getUser() async => null;
  @override
  Future<void> clearAll() async {}
}

class TestAuthController extends AuthController {
  TestAuthController({
    required super.repository,
    required super.storage,
    required super.apiClient,
    AuthState initialState = const AuthState.unauthenticated(),
  }) {
    state = initialState;
  }

  @override
  Future<void> checkAuthStatus() async {
    // No-op for controlled UI test state
  }
}

void main() {
  test('App name is FieldSure', () {
    expect(AppConstants.appName, 'FieldSure');
  });

  test('Disclaimer text is present', () {
    expect(
      AppConstants.disclaimer,
      'Presumptive field-test result. Laboratory confirmation is required.',
    );
  });

  test('Primary button height meets spec (56-60dp)', () {
    expect(AppConstants.primaryButtonHeight, greaterThanOrEqualTo(56.0));
    expect(AppConstants.primaryButtonHeight, lessThanOrEqualTo(60.0));
  });

  test('Minimum touch target meets spec (>=44dp)', () {
    expect(AppConstants.minTouchTarget, greaterThanOrEqualTo(44.0));
  });

  testWidgets('SplashScreen renders app branding and disclaimer', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const SplashScreen(),
      ),
    );

    expect(find.text('FieldSure'), findsOneWidget);
    expect(find.text(AppConstants.tagline), findsOneWidget);
    expect(find.text(AppConstants.brandConcept), findsOneWidget);
    expect(find.text(AppConstants.disclaimer), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('LoginScreen renders form inputs and handles validation', (tester) async {
    final mockRepo = MockAuthRepo();
    final mockStorage = MockStorage();
    final mockApiClient = ApiClient(
      baseUrl: 'http://localhost:3000/api/v1',
      storage: mockStorage,
    );
    final testController = TestAuthController(
      repository: mockRepo,
      storage: mockStorage,
      apiClient: mockApiClient,
      initialState: const AuthState.unauthenticated(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((ref) => testController),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const LoginScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify UI components
    expect(find.text('FieldSure'), findsOneWidget);
    expect(find.text('Operator Authentication'), findsOneWidget);
    expect(find.byKey(const Key('login_email_input')), findsOneWidget);
    expect(find.byKey(const Key('login_password_input')), findsOneWidget);
    expect(find.byKey(const Key('login_submit_button')), findsOneWidget);
    expect(find.text(AppConstants.disclaimer), findsOneWidget);

    // Tap submit with empty form to trigger validation
    await tester.tap(find.byKey(const Key('login_submit_button')));
    await tester.pumpAndSettle();

    expect(find.text('Please enter your email or operator badge ID'), findsOneWidget);
  });

  testWidgets('DashboardScreen displays user details and role badge', (tester) async {
    final mockStorage = MockStorage();
    final mockApiClient = ApiClient(
      baseUrl: 'http://localhost:3000/api/v1',
      storage: mockStorage,
    );
    final testController = TestAuthController(
      repository: MockAuthRepo(),
      storage: mockStorage,
      apiClient: mockApiClient,
      initialState: const AuthState.authenticated(
        user: UserModel(
          id: 'u-1',
          operatorId: 'OP-404',
          name: 'Senior Inspector Deshmukh',
          email: 'deshmukh@police.gov.in',
          role: UserRole.supervisor,
        ),
        tokens: AuthTokens(accessToken: 'a', refreshToken: 'r'),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((ref) => testController),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const DashboardScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('FieldSure Dashboard'), findsOneWidget);
    expect(find.text('Senior Inspector Deshmukh'), findsOneWidget);
    expect(find.text('Badge: OP-404'), findsOneWidget);
    expect(find.text('SUPERVISOR'), findsOneWidget);
    expect(find.text('New Field Test'), findsOneWidget);
    expect(find.text('Test Records & Evidence Vault'), findsOneWidget);
    expect(find.text('Verification & Audit Logs'), findsOneWidget);
    expect(find.text(AppConstants.disclaimer), findsOneWidget);
  });
}
