import 'route_type.dart';

/// Plantilla de ruta reutilizable
class RouteTemplate {
  final String id;
  final String name;
  final String? description;
  final String? routeTypeId;
  final RouteType? routeType;
  final String? sedeApp;
  final String? createdBy;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<RouteTemplateClient> clients;

  const RouteTemplate({
    required this.id,
    required this.name,
    this.description,
    this.routeTypeId,
    this.routeType,
    this.sedeApp,
    this.createdBy,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.clients = const [],
  });

  factory RouteTemplate.fromJson(Map<String, dynamic> json) {
    return RouteTemplate(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      routeTypeId: json['route_type_id'] as String?,
      routeType: json['route_types'] != null 
          ? RouteType.fromJson(json['route_types'] as Map<String, dynamic>)
          : null,
      sedeApp: json['sede_app'] as String?,
      createdBy: json['created_by'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : null,
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String) 
          : null,
      clients: json['route_template_clients'] != null
          ? (json['route_template_clients'] as List)
              .map((e) => RouteTemplateClient.fromJson(e as Map<String, dynamic>))
              .toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'route_type_id': routeTypeId,
      'sede_app': sedeApp,
      'created_by': createdBy,
      'is_active': isActive,
    };
  }

  /// Para inserción en Supabase (sin id)
  Map<String, dynamic> toInsertJson() {
    return {
      'name': name,
      'description': description,
      'route_type_id': routeTypeId,
      'sede_app': sedeApp,
      'created_by': createdBy,
      'is_active': isActive,
    };
  }

  RouteTemplate copyWith({
    String? name,
    String? description,
    String? routeTypeId,
    String? sedeApp,
    bool? isActive,
    List<RouteTemplateClient>? clients,
  }) {
    return RouteTemplate(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      routeTypeId: routeTypeId ?? this.routeTypeId,
      routeType: routeType,
      sedeApp: sedeApp ?? this.sedeApp,
      createdBy: createdBy,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
      clients: clients ?? this.clients,
    );
  }
}

/// Cliente dentro de una plantilla de ruta
class RouteTemplateClient {
  final String id;
  final String templateId;
  final String clientCoCli;
  final int visitOrder;
  final int estimatedDurationMinutes;
  final String? notes;
  final DateTime? createdAt;
  
  // Datos del cliente (join)
  final String? clientName;
  final String? clientCity;
  final String? clientAddress;

  const RouteTemplateClient({
    required this.id,
    required this.templateId,
    required this.clientCoCli,
    this.visitOrder = 0,
    this.estimatedDurationMinutes = 30,
    this.notes,
    this.createdAt,
    this.clientName,
    this.clientCity,
    this.clientAddress,
  });

  /// Alias para compatibilidad con repositorio
  String get clientId => clientCoCli;
  
  /// Alias para compatibilidad con repositorio
  int get orderNumber => visitOrder;

  factory RouteTemplateClient.fromJson(Map<String, dynamic> json) {
    final client = json['clients'] as Map<String, dynamic>?;
    return RouteTemplateClient(
      id: json['id'] as String? ?? '',
      templateId: json['template_id'] as String? ?? '',
      clientCoCli: json['client_co_cli'] as String,
      visitOrder: json['order_number'] as int? ?? json['visit_order'] as int? ?? 0,
      estimatedDurationMinutes: json['estimated_duration_minutes'] as int? ?? 30,
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : null,
      clientName: client?['cli_des'] as String?,
      clientCity: client?['ciudad'] as String?,
      clientAddress: client?['direc1'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'template_id': templateId,
      'client_co_cli': clientCoCli,
      'order_number': visitOrder,
      'estimated_duration_minutes': estimatedDurationMinutes,
      'notes': notes,
    };
  }
}
