import '../enums/user_role.dart';
import '../enums/user_status.dart';
import '../enums/sede.dart';

/// Modelo de usuario de la aplicación
class AppUser {
  final String id;
  final String email;
  final String fullName;
  final UserRole role;
  final Sede? sede;
  final String? phone;
  final UserStatus status;
  final String? avatarUrl;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? createdBy; // ID del usuario que creó este usuario

  const AppUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.sede,
    this.phone,
    required this.status,
    this.avatarUrl,
    required this.createdAt,
    this.updatedAt,
    this.createdBy,
  });

  /// Obtiene la región basada en la sede
  Region? get region => sede?.region;

  /// Crea un AppUser desde un mapa JSON
  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String,
      role: UserRole.fromString(json['role'] as String),
      sede: Sede.tryFromString(json['sede'] as String?),
      phone: json['phone'] as String?,
      status: UserStatus.fromString(json['status'] as String? ?? 'pending'),
      avatarUrl: json['avatar_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      createdBy: json['created_by'] as String?,
    );
  }

  /// Convierte el AppUser a un mapa JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'role': role.value,
      'sede': sede?.value,
      'region': region?.value,
      'phone': phone,
      'status': status.value,
      'avatar_url': avatarUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'created_by': createdBy,
    };
  }

  /// Crea una copia del AppUser con los campos especificados actualizados
  AppUser copyWith({
    String? id,
    String? email,
    String? fullName,
    UserRole? role,
    Sede? sede,
    String? phone,
    UserStatus? status,
    String? avatarUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      sede: sede ?? this.sede,
      phone: phone ?? this.phone,
      status: status ?? this.status,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  /// Verifica si el usuario es mercaderista
  bool get isMercaderista => role.isMercaderista;

  /// Verifica si el usuario es administrador (owner o supervisor)
  bool get isAdmin => role.isAdmin;

  /// Verifica si el usuario es owner
  bool get isOwner => role.isOwner;

  /// Verifica si el usuario es supervisor
  bool get isSupervisor => role.isSupervisor;

  /// Verifica si el usuario puede acceder a la aplicación
  bool get canAccess => status.canAccess;

  /// Verifica si este usuario puede gestionar a otro usuario
  bool canManageUser(AppUser other) {
    // Owner puede gestionar a todos
    if (role.isOwner) return true;
    
    // Supervisor solo puede gestionar usuarios de su misma sede
    if (role.isSupervisor) {
      return other.sede == sede && !other.role.isOwner;
    }
    
    return false;
  }

  /// Verifica si este usuario puede crear usuarios con el rol especificado
  bool canCreateUserWithRole(UserRole targetRole) {
    return role.creatableRoles.contains(targetRole);
  }

  /// Obtiene las iniciales del nombre
  String get initials {
    final names = fullName.trim().split(' ');
    if (names.isEmpty) return '';
    if (names.length == 1) return names[0][0].toUpperCase();
    return '${names[0][0]}${names[names.length - 1][0]}'.toUpperCase();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUser &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          email == other.email &&
          fullName == other.fullName &&
          role == other.role &&
          sede == other.sede &&
          phone == other.phone &&
          status == other.status &&
          avatarUrl == other.avatarUrl;

  @override
  int get hashCode =>
      id.hashCode ^
      email.hashCode ^
      fullName.hashCode ^
      role.hashCode ^
      sede.hashCode ^
      phone.hashCode ^
      status.hashCode ^
      avatarUrl.hashCode;

  @override
  String toString() {
    return 'AppUser(id: $id, email: $email, fullName: $fullName, role: $role, sede: $sede, status: $status)';
  }
}
