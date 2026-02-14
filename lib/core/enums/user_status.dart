/// Estados de un usuario
enum UserStatus {
  active('active', 'Activo', 'Usuario activo y puede usar la aplicación'),
  pending('pending', 'Pendiente', 'Usuario pendiente de aprobación'),
  rejected('rejected', 'Rechazado', 'Usuario rechazado por el administrador'),
  inactive('inactive', 'Inactivo', 'Usuario inactivo temporalmente');

  const UserStatus(this.value, this.displayName, this.description);

  final String value;
  final String displayName;
  final String description;

  /// Crea un UserStatus desde un string
  static UserStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'active':
        return UserStatus.active;
      case 'pending':
        return UserStatus.pending;
      case 'rejected':
        return UserStatus.rejected;
      case 'inactive':
        return UserStatus.inactive;
      default:
        throw ArgumentError('Invalid user status: $value');
    }
  }

  /// Verifica si el usuario está activo
  bool get isActive => this == UserStatus.active;

  /// Verifica si el usuario está pendiente
  bool get isPending => this == UserStatus.pending;

  /// Verifica si el usuario está rechazado
  bool get isRejected => this == UserStatus.rejected;

  /// Verifica si el usuario está inactivo
  bool get isInactive => this == UserStatus.inactive;

  /// Verifica si el usuario puede acceder a la aplicación
  bool get canAccess => this == UserStatus.active;

  @override
  String toString() => displayName;
}
