import '../enums/event_status.dart';
import 'route_type.dart';

/// Modelo de evento
class AppEvent {
  final String id;
  final String name;
  final String? description;
  final String? routeTypeId;
  final String? locationName;
  final double? latitude;
  final double? longitude;
  final DateTime startDate;
  final DateTime endDate;
  final EventStatus status;
  final String? notes;
  final String sedeApp;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // Datos cargados por join/separado
  final RouteType? routeType;
  final List<EventMercaderista>? mercaderistas;

  const AppEvent({
    required this.id,
    required this.name,
    this.description,
    this.routeTypeId,
    this.locationName,
    this.latitude,
    this.longitude,
    required this.startDate,
    required this.endDate,
    required this.status,
    this.notes,
    required this.sedeApp,
    this.createdBy,
    required this.createdAt,
    this.updatedAt,
    this.routeType,
    this.mercaderistas,
  });

  factory AppEvent.fromJson(Map<String, dynamic> json) {
    return AppEvent(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      routeTypeId: json['route_type_id'] as String?,
      locationName: json['location_name'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      status: EventStatus.fromString(json['status'] as String? ?? 'planned'),
      notes: json['notes'] as String?,
      sedeApp: json['sede_app'] as String,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      routeType: json['route_types'] != null
          ? RouteType.fromJson(json['route_types'] as Map<String, dynamic>)
          : null,
      mercaderistas: json['event_mercaderistas'] != null
          ? (json['event_mercaderistas'] as List)
              .map((e) => EventMercaderista.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'route_type_id': routeTypeId,
      'location_name': locationName,
      'latitude': latitude,
      'longitude': longitude,
      'start_date': startDate.toIso8601String().split('T')[0],
      'end_date': endDate.toIso8601String().split('T')[0],
      'status': status.value,
      'notes': notes,
      'sede_app': sedeApp,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'name': name,
      'description': description,
      'route_type_id': routeTypeId,
      'location_name': locationName,
      'latitude': latitude,
      'longitude': longitude,
      'start_date': startDate.toIso8601String().split('T')[0],
      'end_date': endDate.toIso8601String().split('T')[0],
      'status': status.value,
      'notes': notes,
      'sede_app': sedeApp,
      'created_by': createdBy,
    };
  }

  AppEvent copyWith({
    String? id,
    String? name,
    String? description,
    String? routeTypeId,
    String? locationName,
    double? latitude,
    double? longitude,
    DateTime? startDate,
    DateTime? endDate,
    EventStatus? status,
    String? notes,
    String? sedeApp,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    RouteType? routeType,
    List<EventMercaderista>? mercaderistas,
  }) {
    return AppEvent(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      routeTypeId: routeTypeId ?? this.routeTypeId,
      locationName: locationName ?? this.locationName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      sedeApp: sedeApp ?? this.sedeApp,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      routeType: routeType ?? this.routeType,
      mercaderistas: mercaderistas ?? this.mercaderistas,
    );
  }

  /// Número total de días del evento
  int get totalDays => endDate.difference(startDate).inDays + 1;

  /// Día actual del evento (1-based), o null si no está en rango
  int? get currentDay {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    if (today.isBefore(start) || today.isAfter(end)) return null;
    return today.difference(start).inDays + 1;
  }

  /// Verifica si el evento incluye la fecha dada
  bool includesDate(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final s = DateTime(startDate.year, startDate.month, startDate.day);
    final e = DateTime(endDate.year, endDate.month, endDate.day);
    return !d.isBefore(s) && !d.isAfter(e);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppEvent && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'AppEvent(id: $id, name: $name, startDate: $startDate, endDate: $endDate, status: $status)';
}

/// Modelo para asignación de mercaderista a un evento
class EventMercaderista {
  final String id;
  final String eventId;
  final String mercaderistaId;
  final DateTime createdAt;

  // Datos del usuario (cargados por join)
  final String? mercaderistaName;
  final String? mercaderistaEmail;

  const EventMercaderista({
    required this.id,
    required this.eventId,
    required this.mercaderistaId,
    required this.createdAt,
    this.mercaderistaName,
    this.mercaderistaEmail,
  });

  factory EventMercaderista.fromJson(Map<String, dynamic> json) {
    // Handle join con users
    String? name;
    String? email;
    if (json['users'] != null && json['users'] is Map) {
      final u = json['users'] as Map<String, dynamic>;
      name = u['full_name'] as String?;
      email = u['email'] as String?;
    }

    return EventMercaderista(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      mercaderistaId: json['mercaderista_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      mercaderistaName: name,
      mercaderistaEmail: email,
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'event_id': eventId,
      'mercaderista_id': mercaderistaId,
    };
  }
}
