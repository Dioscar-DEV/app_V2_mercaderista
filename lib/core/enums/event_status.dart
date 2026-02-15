/// Estados de un evento
enum EventStatus {
  planned('planned', 'Planificado', 'El evento está planificado'),
  inProgress('in_progress', 'En Progreso', 'El evento está activo'),
  completed('completed', 'Completado', 'El evento ha finalizado'),
  cancelled('cancelled', 'Cancelado', 'El evento fue cancelado');

  const EventStatus(this.value, this.displayName, this.description);

  final String value;
  final String displayName;
  final String description;

  /// Crea un EventStatus desde un string
  static EventStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'planned':
        return EventStatus.planned;
      case 'in_progress':
      case 'inprogress':
        return EventStatus.inProgress;
      case 'completed':
        return EventStatus.completed;
      case 'cancelled':
        return EventStatus.cancelled;
      default:
        throw ArgumentError('Invalid event status: $value');
    }
  }

  bool get isActive => this == EventStatus.inProgress;
  bool get isCompleted => this == EventStatus.completed;
  bool get isPlanned => this == EventStatus.planned;
  bool get isCancelled => this == EventStatus.cancelled;
  bool get canBeEdited => this == EventStatus.planned;

  @override
  String toString() => displayName;
}
