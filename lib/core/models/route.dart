import '../enums/route_status.dart';
import 'client.dart';
import 'route_type.dart';

/// Estados posibles de un cliente en una ruta
enum RouteClientStatus {
  pending,    // Pendiente de visitar
  inProgress, // Visita en progreso
  completed,  // Visita completada
  skipped,    // Saltado/omitido
  closedTemp, // Cerrado temporalmente (negocio cerrado ese día)
}

/// Extensión para RouteClientStatus
extension RouteClientStatusExtension on RouteClientStatus {
  String get displayName {
    switch (this) {
      case RouteClientStatus.pending:
        return 'Pendiente';
      case RouteClientStatus.inProgress:
        return 'En Progreso';
      case RouteClientStatus.completed:
        return 'Completado';
      case RouteClientStatus.skipped:
        return 'Omitido';
      case RouteClientStatus.closedTemp:
        return 'Cerrado';
    }
  }

  static RouteClientStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'pending':
        return RouteClientStatus.pending;
      case 'in_progress':
        return RouteClientStatus.inProgress;
      case 'completed':
        return RouteClientStatus.completed;
      case 'skipped':
        return RouteClientStatus.skipped;
      case 'closed_temp':
        return RouteClientStatus.closedTemp;
      default:
        return RouteClientStatus.pending;
    }
  }

  String toDbString() {
    switch (this) {
      case RouteClientStatus.pending:
        return 'pending';
      case RouteClientStatus.inProgress:
        return 'in_progress';
      case RouteClientStatus.completed:
        return 'completed';
      case RouteClientStatus.skipped:
        return 'skipped';
      case RouteClientStatus.closedTemp:
        return 'closed_temp';
    }
  }
}

/// Modelo de ruta
class AppRoute {
  final String id;
  final String mercaderistaId;
  final String name;
  final DateTime scheduledDate;
  final RouteStatus status;
  final int totalClients;
  final int completedClients;
  final Duration? estimatedDuration;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime? updatedAt;
  
  // Nuevos campos
  final String? templateId;
  final String? routeTypeId;
  final String? notes;
  final String? cancellationReason;
  final String sedeApp;
  final String? createdBy;

  // Marcas configuradas para la ruta (solo Impulso)
  final List<String>? brands;

  // Información adicional (no viene de la BD, se carga por separado)
  final String? mercaderistaName;
  final List<RouteClient>? clients;
  final RouteType? routeType;

  const AppRoute({
    required this.id,
    required this.mercaderistaId,
    required this.name,
    required this.scheduledDate,
    required this.status,
    this.totalClients = 0,
    this.completedClients = 0,
    this.estimatedDuration,
    this.startedAt,
    this.completedAt,
    required this.createdAt,
    this.updatedAt,
    this.templateId,
    this.routeTypeId,
    this.notes,
    this.cancellationReason,
    required this.sedeApp,
    this.createdBy,
    this.brands,
    this.mercaderistaName,
    this.clients,
    this.routeType,
  });

  /// Marcas disponibles para esta ruta (default: ambas)
  List<String> get availableBrands => brands ?? ['Shell', 'Qualid'];

  /// Crea un AppRoute desde un mapa JSON
  factory AppRoute.fromJson(Map<String, dynamic> json) {
    return AppRoute(
      id: json['id'] as String,
      mercaderistaId: json['mercaderista_id'] as String,
      name: json['name'] as String,
      scheduledDate: DateTime.parse(json['scheduled_date'] as String),
      status: RouteStatus.fromString(json['status'] as String),
      totalClients: json['total_clients'] as int? ?? 0,
      completedClients: json['completed_clients'] as int? ?? 0,
      estimatedDuration: json['estimated_duration'] != null
          ? _parseDuration(json['estimated_duration'])
          : null,
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      templateId: json['template_id'] as String?,
      routeTypeId: json['route_type_id'] as String?,
      notes: json['notes'] as String?,
      cancellationReason: json['cancellation_reason'] as String?,
      sedeApp: json['sede_app'] as String? ?? 'grupo_disbattery',
      createdBy: json['created_by'] as String?,
      brands: json['brands'] != null ? List<String>.from(json['brands']) : null,
      mercaderistaName: json['mercaderista_name'] as String?,
      routeType: json['route_type'] != null
          ? RouteType.fromJson(json['route_type'] as Map<String, dynamic>)
          : null,
      clients: json['route_clients'] != null
          ? (json['route_clients'] as List)
              .map((e) => RouteClient.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
    );
  }

  /// Convierte el AppRoute a un mapa JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'mercaderista_id': mercaderistaId,
      'name': name,
      'scheduled_date': scheduledDate.toIso8601String().split('T')[0], // Solo la fecha
      'status': status.value,
      'total_clients': totalClients,
      'completed_clients': completedClients,
      'estimated_duration': estimatedDuration?.toString(),
      'started_at': startedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'template_id': templateId,
      'route_type_id': routeTypeId,
      'notes': notes,
      'cancellation_reason': cancellationReason,
      'sede_app': sedeApp,
      'created_by': createdBy,
      'brands': brands,
    };
  }

  /// Mapa JSON para insertar (sin id ni timestamps)
  Map<String, dynamic> toInsertJson() {
    return {
      'mercaderista_id': mercaderistaId,
      'name': name,
      'scheduled_date': scheduledDate.toIso8601String().split('T')[0],
      'status': status.value,
      'total_clients': totalClients,
      'completed_clients': completedClients,
      'template_id': templateId,
      'route_type_id': routeTypeId,
      'notes': notes,
      'sede_app': sedeApp,
      'created_by': createdBy,
      'brands': brands,
    };
  }

  /// Parse duration from PostgreSQL interval format
  static Duration? _parseDuration(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      // Format: "HH:MM:SS" or PostgreSQL interval
      final parts = value.split(':');
      if (parts.length >= 2) {
        return Duration(
          hours: int.tryParse(parts[0]) ?? 0,
          minutes: int.tryParse(parts[1]) ?? 0,
          seconds: parts.length > 2 ? (int.tryParse(parts[2]) ?? 0) : 0,
        );
      }
    }
    return null;
  }

  /// Crea una copia del AppRoute con los campos especificados actualizados
  AppRoute copyWith({
    String? id,
    String? mercaderistaId,
    String? name,
    DateTime? scheduledDate,
    RouteStatus? status,
    int? totalClients,
    int? completedClients,
    Duration? estimatedDuration,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? templateId,
    String? routeTypeId,
    String? notes,
    String? cancellationReason,
    String? sedeApp,
    String? createdBy,
    List<String>? brands,
    String? mercaderistaName,
    List<RouteClient>? clients,
    RouteType? routeType,
  }) {
    return AppRoute(
      id: id ?? this.id,
      mercaderistaId: mercaderistaId ?? this.mercaderistaId,
      name: name ?? this.name,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      status: status ?? this.status,
      totalClients: totalClients ?? this.totalClients,
      completedClients: completedClients ?? this.completedClients,
      estimatedDuration: estimatedDuration ?? this.estimatedDuration,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      templateId: templateId ?? this.templateId,
      routeTypeId: routeTypeId ?? this.routeTypeId,
      notes: notes ?? this.notes,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      sedeApp: sedeApp ?? this.sedeApp,
      createdBy: createdBy ?? this.createdBy,
      brands: brands ?? this.brands,
      mercaderistaName: mercaderistaName ?? this.mercaderistaName,
      clients: clients ?? this.clients,
      routeType: routeType ?? this.routeType,
    );
  }

  /// Calcula el progreso de la ruta (0.0 a 1.0)
  double get progress {
    if (totalClients == 0) return 0.0;
    return completedClients / totalClients;
  }

  /// Verifica si la ruta está completa
  bool get isComplete => status == RouteStatus.completed;

  /// Verifica si la ruta está en progreso
  bool get isInProgress => status == RouteStatus.inProgress;

  /// Verifica si la ruta está planificada
  bool get isPlanned => status == RouteStatus.planned;

  /// Verifica si la ruta está cancelada
  bool get isCancelled => status == RouteStatus.cancelled;

  /// Conteo de clientes por estado
  int get pendingClientsCount =>
      clients?.where((c) => c.isPending).length ?? 0;
  int get completedClientsCount =>
      clients?.where((c) => c.isCompleted).length ?? 0;
  int get skippedClientsCount =>
      clients?.where((c) => c.isSkipped).length ?? 0;
  int get closedTempClientsCount =>
      clients?.where((c) => c.isClosedTemp).length ?? 0;
  int get inProgressClientsCount =>
      clients?.where((c) => c.isInProgress).length ?? 0;

  @override
  String toString() {
    return 'AppRoute(id: $id, name: $name, scheduledDate: $scheduledDate, status: $status)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppRoute && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Modelo para cliente en una ruta
class RouteClient {
  final String id;
  final String routeId;
  final String clientId; // Este es client_co_cli en la DB
  final int orderNumber;
  final RouteClientStatus status;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final double? latitudeStart;
  final double? longitudeStart;
  final double? latitudeEnd;
  final double? longitudeEnd;
  final String? closureReason;
  final DateTime createdAt;

  // Información del cliente (cargada por join)
  final Client? client;

  const RouteClient({
    required this.id,
    required this.routeId,
    required this.clientId,
    required this.orderNumber,
    required this.status,
    this.startedAt,
    this.completedAt,
    this.latitudeStart,
    this.longitudeStart,
    this.latitudeEnd,
    this.longitudeEnd,
    this.closureReason,
    required this.createdAt,
    this.client,
  });

  factory RouteClient.fromJson(Map<String, dynamic> json) {
    return RouteClient(
      id: json['id'] as String,
      routeId: json['route_id'] as String,
      clientId: json['client_co_cli'] as String, // Usar client_co_cli de la DB
      orderNumber: json['order_number'] as int? ?? 0,
      status: RouteClientStatusExtension.fromString(json['status'] as String? ?? 'pending'),
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      latitudeStart: (json['latitude_start'] as num?)?.toDouble(),
      longitudeStart: (json['longitude_start'] as num?)?.toDouble(),
      latitudeEnd: (json['latitude_end'] as num?)?.toDouble(),
      longitudeEnd: (json['longitude_end'] as num?)?.toDouble(),
      closureReason: json['closure_reason'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      client: json['client'] != null
          ? Client.fromJson(json['client'] as Map<String, dynamic>)
          : (json['clients'] != null
              ? Client.fromJson(json['clients'] as Map<String, dynamic>)
              : null),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'route_id': routeId,
      'client_co_cli': clientId,
      'order_number': orderNumber,
      'status': status.toDbString(),
      'started_at': startedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'latitude_start': latitudeStart,
      'longitude_start': longitudeStart,
      'latitude_end': latitudeEnd,
      'longitude_end': longitudeEnd,
      'closure_reason': closureReason,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'route_id': routeId,
      'client_co_cli': clientId,
      'order_number': orderNumber,
      'status': status.toDbString(),
    };
  }

  RouteClient copyWith({
    String? id,
    String? routeId,
    String? clientId,
    int? orderNumber,
    RouteClientStatus? status,
    DateTime? startedAt,
    DateTime? completedAt,
    double? latitudeStart,
    double? longitudeStart,
    double? latitudeEnd,
    double? longitudeEnd,
    String? closureReason,
    DateTime? createdAt,
    Client? client,
  }) {
    return RouteClient(
      id: id ?? this.id,
      routeId: routeId ?? this.routeId,
      clientId: clientId ?? this.clientId,
      orderNumber: orderNumber ?? this.orderNumber,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      latitudeStart: latitudeStart ?? this.latitudeStart,
      longitudeStart: longitudeStart ?? this.longitudeStart,
      latitudeEnd: latitudeEnd ?? this.latitudeEnd,
      longitudeEnd: longitudeEnd ?? this.longitudeEnd,
      closureReason: closureReason ?? this.closureReason,
      createdAt: createdAt ?? this.createdAt,
      client: client ?? this.client,
    );
  }

  /// Indica si la visita está pendiente
  bool get isPending => status == RouteClientStatus.pending;

  /// Indica si la visita está en progreso
  bool get isInProgress => status == RouteClientStatus.inProgress;

  /// Indica si la visita fue completada
  bool get isCompleted => status == RouteClientStatus.completed;

  /// Indica si la visita fue omitida
  bool get isSkipped => status == RouteClientStatus.skipped;

  /// Indica si el negocio estaba cerrado temporalmente
  bool get isClosedTemp => status == RouteClientStatus.closedTemp;

  /// Indica si la visita necesita acción (pendiente o en progreso)
  bool get needsAction => isPending || isInProgress;
}
