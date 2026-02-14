/// Roles de usuario en la aplicación
/// 
/// Jerarquía de permisos:
/// - Owner: Acceso total a todas las sedes (excepto crear rutas), puede crear usuarios
/// - Supervisor: Acceso total pero solo a su sede asignada
/// - Mercaderista: Solo acceso a su ruta y métricas personales
enum UserRole {
  owner('owner', 'Owner/Admin Master'),
  supervisor('supervisor', 'Supervisor'),
  mercaderista('mercaderista', 'Mercaderista');

  const UserRole(this.value, this.displayName);

  final String value;
  final String displayName;

  /// Crea un UserRole desde un string
  static UserRole fromString(String value) {
    switch (value.toLowerCase()) {
      case 'mercaderista':
        return UserRole.mercaderista;
      case 'supervisor':
        return UserRole.supervisor;
      case 'owner':
      case 'admin':
      case 'super_admin':
      case 'superadmin':
        return UserRole.owner;
      default:
        throw ArgumentError('Invalid user role: $value');
    }
  }

  /// Lista de todos los roles para selección en formularios
  static List<UserRole> get selectableRoles => [
    UserRole.owner,
    UserRole.supervisor,
    UserRole.mercaderista,
  ];

  /// Verifica si el rol puede gestionar usuarios
  bool get canManageUsers => this == UserRole.owner || this == UserRole.supervisor;

  /// Verifica si el rol puede ver todas las sedes
  bool get canViewAllSedes => this == UserRole.owner;

  /// Verifica si el rol puede crear rutas
  bool get canCreateRoutes => this == UserRole.supervisor;

  /// Verifica si el rol puede gestionar clientes
  bool get canManageClients => this == UserRole.owner || this == UserRole.supervisor;

  /// Verifica si el rol puede ver KPIs globales
  bool get canViewGlobalKPIs => this == UserRole.owner;

  /// Verifica si el rol es administrador (owner o supervisor)
  bool get isAdmin => this == UserRole.owner || this == UserRole.supervisor;

  /// Verifica si el rol es owner
  bool get isOwner => this == UserRole.owner;

  /// Verifica si el rol es supervisor
  bool get isSupervisor => this == UserRole.supervisor;

  /// Verifica si el rol es mercaderista
  bool get isMercaderista => this == UserRole.mercaderista;

  /// Obtiene los roles que este usuario puede crear
  List<UserRole> get creatableRoles {
    switch (this) {
      case UserRole.owner:
        return [UserRole.owner, UserRole.supervisor, UserRole.mercaderista];
      case UserRole.supervisor:
        return [UserRole.mercaderista];
      case UserRole.mercaderista:
        return [];
    }
  }

  @override
  String toString() => displayName;
}
