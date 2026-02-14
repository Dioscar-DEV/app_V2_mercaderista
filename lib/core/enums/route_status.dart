/// Estados de una ruta
enum RouteStatus {
  planned('planned', 'Planificada', 'La ruta está planificada pero no ha iniciado'),
  inProgress('in_progress', 'En Progreso', 'La ruta está siendo ejecutada'),
  completed('completed', 'Completada', 'La ruta ha sido completada'),
  cancelled('cancelled', 'Cancelada', 'La ruta ha sido cancelada');

  const RouteStatus(this.value, this.displayName, this.description);

  final String value;
  final String displayName;
  final String description;

  /// Crea un RouteStatus desde un string
  static RouteStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'planned':
        return RouteStatus.planned;
      case 'in_progress':
      case 'inprogress':
        return RouteStatus.inProgress;
      case 'completed':
        return RouteStatus.completed;
      case 'cancelled':
        return RouteStatus.cancelled;
      default:
        throw ArgumentError('Invalid route status: $value');
    }
  }

  /// Verifica si la ruta está activa
  bool get isActive => this == RouteStatus.inProgress;

  /// Verifica si la ruta está completada
  bool get isCompleted => this == RouteStatus.completed;

  /// Verifica si la ruta está planificada
  bool get isPlanned => this == RouteStatus.planned;

  /// Verifica si la ruta está cancelada
  bool get isCancelled => this == RouteStatus.cancelled;

  /// Verifica si la ruta puede ser iniciada
  bool get canBeStarted => this == RouteStatus.planned;

  /// Verifica si la ruta puede ser editada
  bool get canBeEdited => this == RouteStatus.planned;

  @override
  String toString() => displayName;
}
