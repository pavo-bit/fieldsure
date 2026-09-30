import 'package:flutter_test/flutter_test.dart';
import 'package:fieldsure_mobile/core/models/user_model.dart';
import 'package:fieldsure_mobile/core/models/auth_tokens.dart';
import 'package:fieldsure_mobile/core/models/auth_state.dart';

void main() {
  group('UserModel', () {
    test('serializes and deserializes correctly from JSON', () {
      final json = {
        'id': 'user-123',
        'operatorId': 'OP-999',
        'name': 'Inspector Vikram',
        'email': 'vikram@police.gov.in',
        'role': 'SUPERVISOR',
        'isActive': true,
        'lastLoginAt': '2026-01-01T10:00:00Z',
        'createdAt': '2026-01-01T08:00:00Z',
      };

      final user = UserModel.fromJson(json);

      expect(user.id, 'user-123');
      expect(user.operatorId, 'OP-999');
      expect(user.name, 'Inspector Vikram');
      expect(user.email, 'vikram@police.gov.in');
      expect(user.role, UserRole.supervisor);
      expect(user.isActive, true);
      expect(user.lastLoginAt, '2026-01-01T10:00:00Z');

      final serialized = user.toJson();
      expect(serialized['id'], 'user-123');
      expect(serialized['role'], 'SUPERVISOR');
    });

    test('UserRole enum conversions and display names', () {
      expect(UserRole.fromString('ADMIN'), UserRole.admin);
      expect(UserRole.fromString('SUPERVISOR'), UserRole.supervisor);
      expect(UserRole.fromString('OPERATOR'), UserRole.operator);
      expect(UserRole.fromString('UNKNOWN'), UserRole.operator);

      expect(UserRole.admin.displayName, 'Administrator');
      expect(UserRole.supervisor.displayName, 'Supervisor');
      expect(UserRole.operator.displayName, 'Field Operator');
    });

    test('copyWith updates fields correctly', () {
      const user = UserModel(
        id: 'user-1',
        operatorId: 'OP-01',
        name: 'Officer A',
        email: 'a@police.gov.in',
        role: UserRole.operator,
      );

      final updated = user.copyWith(name: 'Officer B', role: UserRole.supervisor);
      expect(updated.name, 'Officer B');
      expect(updated.role, UserRole.supervisor);
      expect(updated.id, 'user-1');
    });
  });

  group('AuthTokens', () {
    test('serializes and deserializes tokens correctly', () {
      final json = {
        'accessToken': 'access.jwt.payload',
        'refreshToken': 'refresh-uuid-token',
      };

      final tokens = AuthTokens.fromJson(json);
      expect(tokens.accessToken, 'access.jwt.payload');
      expect(tokens.refreshToken, 'refresh-uuid-token');

      final serialized = tokens.toJson();
      expect(serialized['accessToken'], 'access.jwt.payload');
      expect(serialized['refreshToken'], 'refresh-uuid-token');
    });
  });

  group('AuthState', () {
    test('initial state flags', () {
      const state = AuthState.initial();
      expect(state.status, AuthStatus.initial);
      expect(state.isLoading, true);
      expect(state.isAuthenticated, false);
      expect(state.user, isNull);
    });

    test('loading state flags', () {
      const state = AuthState.loading();
      expect(state.status, AuthStatus.loading);
      expect(state.isLoading, true);
      expect(state.isAuthenticated, false);
    });

    test('authenticated state flags', () {
      const user = UserModel(
        id: 'u-1',
        operatorId: 'OP-1',
        name: 'Officer A',
        email: 'a@police.gov.in',
        role: UserRole.operator,
      );
      const tokens = AuthTokens(
        accessToken: 'access',
        refreshToken: 'refresh',
      );

      const state = AuthState.authenticated(user: user, tokens: tokens);
      expect(state.status, AuthStatus.authenticated);
      expect(state.isAuthenticated, true);
      expect(state.isLoading, false);
      expect(state.user?.name, 'Officer A');
      expect(state.tokens?.accessToken, 'access');
    });

    test('error state flags', () {
      const state = AuthState.error('Invalid credentials');
      expect(state.status, AuthStatus.error);
      expect(state.isAuthenticated, false);
      expect(state.isLoading, false);
      expect(state.errorMessage, 'Invalid credentials');
    });
  });
}
