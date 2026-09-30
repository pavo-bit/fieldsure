/// Roles supported in the FieldSure system.
enum UserRole {
  admin('ADMIN'),
  supervisor('SUPERVISOR'),
  operator('OPERATOR');

  final String value;
  const UserRole(this.value);

  static UserRole fromString(String val) {
    return UserRole.values.firstWhere(
      (r) => r.value.toUpperCase() == val.toUpperCase(),
      orElse: () => UserRole.operator,
    );
  }

  String get displayName {
    switch (this) {
      case UserRole.admin:
        return 'Administrator';
      case UserRole.supervisor:
        return 'Supervisor';
      case UserRole.operator:
        return 'Field Operator';
    }
  }
}

/// User model representing the authenticated officer/operator.
/// Does NOT contain passwords or sensitive backend hashes.
class UserModel {
  final String id;
  final String operatorId;
  final String name;
  final String email;
  final UserRole role;
  final bool isActive;
  final String? lastLoginAt;
  final String? createdAt;

  const UserModel({
    required this.id,
    required this.operatorId,
    required this.name,
    required this.email,
    required this.role,
    this.isActive = true,
    this.lastLoginAt,
    this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String? ?? '',
      operatorId: json['operatorId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: UserRole.fromString(json['role'] as String? ?? 'OPERATOR'),
      isActive: json['isActive'] as bool? ?? true,
      lastLoginAt: json['lastLoginAt'] as String?,
      createdAt: json['createdAt'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'operatorId': operatorId,
      'name': name,
      'email': email,
      'role': role.value,
      'isActive': isActive,
      'lastLoginAt': lastLoginAt,
      'createdAt': createdAt,
    };
  }

  UserModel copyWith({
    String? id,
    String? operatorId,
    String? name,
    String? email,
    UserRole? role,
    bool? isActive,
    String? lastLoginAt,
    String? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      operatorId: operatorId ?? this.operatorId,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          operatorId == other.operatorId &&
          email == other.email &&
          role == other.role;

  @override
  int get hashCode =>
      id.hashCode ^ operatorId.hashCode ^ email.hashCode ^ role.hashCode;
}
