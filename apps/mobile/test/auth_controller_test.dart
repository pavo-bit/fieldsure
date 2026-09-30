import 'package:flutter_test/flutter_test.dart';
import 'package:fieldsure_mobile/core/models/user_model.dart';
import 'package:fieldsure_mobile/core/models/auth_tokens.dart';
import 'package:fieldsure_mobile/core/models/auth_state.dart';
import 'package:fieldsure_mobile/core/network/api_client.dart';
import 'package:fieldsure_mobile/core/storage/secure_storage_service.dart';
import 'package:fieldsure_mobile/features/auth/data/auth_repository.dart';
import 'package:fieldsure_mobile/features/auth/presentation/controllers/auth_controller.dart';

class FakeAuthRepository implements AuthRepository {
  bool shouldFail = false;
  String errorMessage = 'Invalid credentials';

  final UserModel mockUser = const UserModel(
    id: 'user-001',
    operatorId: 'OP-101',
    name: 'Inspector Vijay',
    email: 'vijay@police.gov.in',
    role: UserRole.operator,
  );

  final AuthTokens mockTokens = const AuthTokens(
    accessToken: 'access-token-123',
    refreshToken: 'refresh-token-456',
  );

  @override
  Future<({UserModel user, AuthTokens tokens})> login({
    required String email,
    required String password,
  }) async {
    if (shouldFail) {
      throw Exception(errorMessage);
    }
    return (user: mockUser, tokens: mockTokens);
  }

  @override
  Future<({UserModel user, AuthTokens tokens})> refreshToken(String refreshToken) async {
    if (shouldFail) {
      throw Exception('Refresh failed');
    }
    return (user: mockUser, tokens: mockTokens);
  }

  @override
  Future<void> logout() async {}

  @override
  Future<UserModel> getProfile() async => mockUser;
}

class FakeSecureStorageService implements SecureStorageService {
  AuthTokens? storedTokens;
  UserModel? storedUser;

  @override
  Future<void> saveTokens(AuthTokens tokens) async {
    storedTokens = tokens;
  }

  @override
  Future<AuthTokens?> getTokens() async => storedTokens;

  @override
  Future<String?> getAccessToken() async => storedTokens?.accessToken;

  @override
  Future<String?> getRefreshToken() async => storedTokens?.refreshToken;

  @override
  Future<void> saveUser(UserModel user) async {
    storedUser = user;
  }

  @override
  Future<UserModel?> getUser() async => storedUser;

  @override
  Future<void> clearAll() async {
    storedTokens = null;
    storedUser = null;
  }
}

void main() {
  late FakeAuthRepository fakeRepo;
  late FakeSecureStorageService fakeStorage;
  late ApiClient fakeApiClient;
  late AuthController controller;

  setUp(() {
    fakeRepo = FakeAuthRepository();
    fakeStorage = FakeSecureStorageService();
    fakeApiClient = ApiClient(
      baseUrl: 'http://localhost:3000/api/v1',
      storage: fakeStorage,
    );
  });

  test('checkAuthStatus transitions to unauthenticated when storage is empty', () async {
    controller = AuthController(
      repository: fakeRepo,
      storage: fakeStorage,
      apiClient: fakeApiClient,
    );

    await controller.checkAuthStatus();
    expect(controller.debugState.status, AuthStatus.unauthenticated);
    expect(controller.debugState.isAuthenticated, false);
  });

  test('checkAuthStatus restores session when tokens exist in storage', () async {
    fakeStorage.storedTokens = fakeRepo.mockTokens;
    fakeStorage.storedUser = fakeRepo.mockUser;

    controller = AuthController(
      repository: fakeRepo,
      storage: fakeStorage,
      apiClient: fakeApiClient,
    );

    await controller.checkAuthStatus();
    expect(controller.debugState.status, AuthStatus.authenticated);
    expect(controller.debugState.isAuthenticated, true);
    expect(controller.debugState.user?.name, 'Inspector Vijay');
  });

  test('login sets authenticated state and stores tokens on success', () async {
    controller = AuthController(
      repository: fakeRepo,
      storage: fakeStorage,
      apiClient: fakeApiClient,
    );

    final success = await controller.login(
      email: 'vijay@police.gov.in',
      password: 'ValidPassword123!',
    );

    expect(success, true);
    expect(controller.debugState.status, AuthStatus.authenticated);
    expect(controller.debugState.user?.email, 'vijay@police.gov.in');
    expect(fakeStorage.storedTokens?.accessToken, 'access-token-123');
    expect(fakeStorage.storedUser?.operatorId, 'OP-101');
  });

  test('login sets error state on failure', () async {
    fakeRepo.shouldFail = true;

    controller = AuthController(
      repository: fakeRepo,
      storage: fakeStorage,
      apiClient: fakeApiClient,
    );

    final success = await controller.login(
      email: 'vijay@police.gov.in',
      password: 'WrongPassword',
    );

    expect(success, false);
    expect(controller.debugState.status, AuthStatus.error);
    expect(controller.debugState.errorMessage, isNotNull);
    expect(fakeStorage.storedTokens, isNull);
  });

  test('logout purges storage and sets unauthenticated state', () async {
    fakeStorage.storedTokens = fakeRepo.mockTokens;
    fakeStorage.storedUser = fakeRepo.mockUser;

    controller = AuthController(
      repository: fakeRepo,
      storage: fakeStorage,
      apiClient: fakeApiClient,
    );

    await controller.checkAuthStatus();
    expect(controller.debugState.isAuthenticated, true);

    await controller.logout();
    expect(controller.debugState.status, AuthStatus.unauthenticated);
    expect(controller.debugState.isAuthenticated, false);
    expect(fakeStorage.storedTokens, isNull);
    expect(fakeStorage.storedUser, isNull);
  });
}
