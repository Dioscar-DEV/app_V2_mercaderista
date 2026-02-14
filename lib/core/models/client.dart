import '../enums/sede.dart';

/// Modelo de cliente sincronizado con API externa
class Client {
  final String coCli; // Código único del cliente (PK)
  final int? apiSedecodigo; // Código de sede de la API
  
  // Datos básicos
  final String cliDes; // Nombre/descripción del cliente
  final String? tipCli; // Tipo de cliente (B2B, etc.)
  final String? rif;
  final String? ciudad;
  
  // Direcciones
  final String? direc1; // Dirección principal
  final String? dirEnt2; // Dirección de entrega
  
  // Contacto
  final String? telefonos;
  final String? email;
  final String? emailAlterno;
  final String? respons; // Responsable/contacto
  
  // Códigos internos
  final String? coZon; // Código zona
  final String? coVen; // Código vendedor
  final String? coSeg; // Código segmento
  
  // Días de visita
  final bool lunes;
  final bool martes;
  final bool miercoles;
  final bool jueves;
  final bool viernes;
  final bool sabado;
  final bool domingo;
  final int? frecuVist; // Frecuencia de visita en días
  
  // Estado
  final bool inactivo;
  final bool permanentlyClosed;
  final DateTime? closedAt;
  final String? closedReason;

  // Campos de nuestra app
  final String? sedeApp; // Sede mapeada (grupo_disbattery, etc.)
  final String? assignedMercaderistaId;
  final DateTime? lastVisitAt;
  final int visitCount;
  final String? notes;
  final double? latitude;
  final double? longitude;
  
  // Auditoría
  final DateTime? syncedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Client({
    required this.coCli,
    this.apiSedecodigo,
    required this.cliDes,
    this.tipCli,
    this.rif,
    this.ciudad,
    this.direc1,
    this.dirEnt2,
    this.telefonos,
    this.email,
    this.emailAlterno,
    this.respons,
    this.coZon,
    this.coVen,
    this.coSeg,
    this.lunes = false,
    this.martes = false,
    this.miercoles = false,
    this.jueves = false,
    this.viernes = false,
    this.sabado = false,
    this.domingo = false,
    this.frecuVist,
    this.inactivo = false,
    this.permanentlyClosed = false,
    this.closedAt,
    this.closedReason,
    this.sedeApp,
    this.assignedMercaderistaId,
    this.lastVisitAt,
    this.visitCount = 0,
    this.notes,
    this.latitude,
    this.longitude,
    this.syncedAt,
    this.createdAt,
    this.updatedAt,
  });

  /// Obtiene la sede como enum
  Sede? get sede => Sede.tryFromString(sedeApp);

  /// Verifica si el cliente está activo
  bool get isActive => !inactivo && !permanentlyClosed;

  /// Obtiene la dirección principal formateada
  String get direccionPrincipal => direc1?.trim() ?? 'Sin dirección';

  /// Obtiene la dirección de entrega formateada
  String get direccionEntrega => dirEnt2?.trim() ?? direccionPrincipal;

  /// Obtiene los días de visita como lista
  List<String> get diasVisita {
    final dias = <String>[];
    if (lunes) dias.add('Lunes');
    if (martes) dias.add('Martes');
    if (miercoles) dias.add('Miércoles');
    if (jueves) dias.add('Jueves');
    if (viernes) dias.add('Viernes');
    if (sabado) dias.add('Sábado');
    if (domingo) dias.add('Domingo');
    return dias;
  }

  /// Obtiene el teléfono formateado
  String get telefonoFormateado {
    if (telefonos == null || telefonos!.isEmpty) return 'Sin teléfono';
    return telefonos!.trim();
  }

  /// Verifica si tiene mercaderista asignado
  bool get hasMercaderistaAsignado => assignedMercaderistaId != null;

  /// Días desde la última visita
  int? get diasDesdeUltimaVisita {
    if (lastVisitAt == null) return null;
    return DateTime.now().difference(lastVisitAt!).inDays;
  }

  /// Verifica si el cliente tiene coordenadas GPS
  bool get hasGPS => latitude != null && longitude != null;

  /// Crea un Client desde un mapa JSON (Supabase)
  factory Client.fromJson(Map<String, dynamic> json) {
    return Client(
      coCli: (json['co_cli'] as String).trim(),
      apiSedecodigo: json['api_sede_codigo'] as int?,
      cliDes: json['cli_des'] as String,
      tipCli: json['tip_cli'] as String?,
      rif: json['rif'] as String?,
      ciudad: json['ciudad'] as String?,
      direc1: json['direc1'] as String?,
      dirEnt2: json['dir_ent2'] as String?,
      telefonos: json['telefonos'] as String?,
      email: json['email'] as String?,
      emailAlterno: json['email_alterno'] as String?,
      respons: json['respons'] as String?,
      coZon: json['co_zon'] as String?,
      coVen: json['co_ven'] as String?,
      coSeg: json['co_seg'] as String?,
      lunes: json['lunes'] as bool? ?? false,
      martes: json['martes'] as bool? ?? false,
      miercoles: json['miercoles'] as bool? ?? false,
      jueves: json['jueves'] as bool? ?? false,
      viernes: json['viernes'] as bool? ?? false,
      sabado: json['sabado'] as bool? ?? false,
      domingo: json['domingo'] as bool? ?? false,
      frecuVist: json['frecu_vist'] as int?,
      inactivo: json['inactivo'] as bool? ?? false,
      permanentlyClosed: json['permanently_closed'] as bool? ?? false,
      closedAt: json['closed_at'] != null
          ? DateTime.parse(json['closed_at'] as String)
          : null,
      closedReason: json['closed_reason'] as String?,
      sedeApp: json['sede_app'] as String?,
      assignedMercaderistaId: json['assigned_mercaderista_id'] as String?,
      lastVisitAt: json['last_visit_at'] != null
          ? DateTime.parse(json['last_visit_at'] as String)
          : null,
      visitCount: json['visit_count'] as int? ?? 0,
      notes: json['notes'] as String?,
      latitude: json['latitude'] != null
          ? (json['latitude'] as num).toDouble()
          : null,
      longitude: json['longitude'] != null
          ? (json['longitude'] as num).toDouble()
          : null,
      syncedAt: json['synced_at'] != null
          ? DateTime.parse(json['synced_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  /// Crea un Client desde la respuesta de la API externa
  factory Client.fromExternalApi(Map<String, dynamic> json, int sedeCode, String sedeApp) {
    return Client(
      coCli: (json['co_cli'] as String).trim(),
      apiSedecodigo: sedeCode,
      cliDes: json['cli_des'] as String? ?? 'Sin nombre',
      tipCli: (json['tip_cli'] as String?)?.trim(),
      rif: json['rif'] as String?,
      ciudad: json['ciudad'] as String?,
      direc1: json['direc1'] as String?,
      dirEnt2: json['dir_ent2'] as String?,
      telefonos: json['telefonos'] as String?,
      email: json['email'] as String?,
      emailAlterno: json['email_alterno'] as String?,
      respons: json['respons'] as String?,
      coZon: (json['co_zon'] as String?)?.trim(),
      coVen: (json['co_ven'] as String?)?.trim(),
      coSeg: (json['co_seg'] as String?)?.trim(),
      lunes: (json['lunes'] as int?) == 1,
      martes: (json['martes'] as int?) == 1,
      miercoles: (json['miercoles'] as int?) == 1,
      jueves: (json['jueves'] as int?) == 1,
      viernes: (json['viernes'] as int?) == 1,
      sabado: (json['sabado'] as int?) == 1,
      domingo: (json['domingo'] as int?) == 1,
      frecuVist: json['frecu_vist'] as int?,
      inactivo: (json['inactivo'] as int?) == 1,
      sedeApp: sedeApp,
    );
  }

  /// Convierte el Client a un mapa JSON para Supabase
  Map<String, dynamic> toJson() {
    return {
      'co_cli': coCli,
      'api_sede_codigo': apiSedecodigo,
      'cli_des': cliDes,
      'tip_cli': tipCli,
      'rif': rif,
      'ciudad': ciudad,
      'direc1': direc1,
      'dir_ent2': dirEnt2,
      'telefonos': telefonos,
      'email': email,
      'email_alterno': emailAlterno,
      'respons': respons,
      'co_zon': coZon,
      'co_ven': coVen,
      'co_seg': coSeg,
      'lunes': lunes,
      'martes': martes,
      'miercoles': miercoles,
      'jueves': jueves,
      'viernes': viernes,
      'sabado': sabado,
      'domingo': domingo,
      'frecu_vist': frecuVist,
      'inactivo': inactivo,
      'sede_app': sedeApp,
      'assigned_mercaderista_id': assignedMercaderistaId,
      'last_visit_at': lastVisitAt?.toIso8601String(),
      'visit_count': visitCount,
      'notes': notes,
      'latitude': latitude,
      'longitude': longitude,
      'synced_at': syncedAt?.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  /// Crea una copia del Client con los campos especificados actualizados
  Client copyWith({
    String? coCli,
    int? apiSedecodigo,
    String? cliDes,
    String? tipCli,
    String? rif,
    String? ciudad,
    String? direc1,
    String? dirEnt2,
    String? telefonos,
    String? email,
    String? emailAlterno,
    String? respons,
    String? coZon,
    String? coVen,
    String? coSeg,
    bool? lunes,
    bool? martes,
    bool? miercoles,
    bool? jueves,
    bool? viernes,
    bool? sabado,
    bool? domingo,
    int? frecuVist,
    bool? inactivo,
    String? sedeApp,
    String? assignedMercaderistaId,
    DateTime? lastVisitAt,
    int? visitCount,
    String? notes,
    double? latitude,
    double? longitude,
    DateTime? syncedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Client(
      coCli: coCli ?? this.coCli,
      apiSedecodigo: apiSedecodigo ?? this.apiSedecodigo,
      cliDes: cliDes ?? this.cliDes,
      tipCli: tipCli ?? this.tipCli,
      rif: rif ?? this.rif,
      ciudad: ciudad ?? this.ciudad,
      direc1: direc1 ?? this.direc1,
      dirEnt2: dirEnt2 ?? this.dirEnt2,
      telefonos: telefonos ?? this.telefonos,
      email: email ?? this.email,
      emailAlterno: emailAlterno ?? this.emailAlterno,
      respons: respons ?? this.respons,
      coZon: coZon ?? this.coZon,
      coVen: coVen ?? this.coVen,
      coSeg: coSeg ?? this.coSeg,
      lunes: lunes ?? this.lunes,
      martes: martes ?? this.martes,
      miercoles: miercoles ?? this.miercoles,
      jueves: jueves ?? this.jueves,
      viernes: viernes ?? this.viernes,
      sabado: sabado ?? this.sabado,
      domingo: domingo ?? this.domingo,
      frecuVist: frecuVist ?? this.frecuVist,
      inactivo: inactivo ?? this.inactivo,
      sedeApp: sedeApp ?? this.sedeApp,
      assignedMercaderistaId: assignedMercaderistaId ?? this.assignedMercaderistaId,
      lastVisitAt: lastVisitAt ?? this.lastVisitAt,
      visitCount: visitCount ?? this.visitCount,
      notes: notes ?? this.notes,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      syncedAt: syncedAt ?? this.syncedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => 'Client(coCli: $coCli, cliDes: $cliDes, ciudad: $ciudad)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Client && runtimeType == other.runtimeType && coCli == other.coCli;

  @override
  int get hashCode => coCli.hashCode;
}

/// Modelo de sede de la API externa
class ApiSede {
  final int codigo;
  final String nombre;
  final String sedeApp;
  final int totalClientes;
  final DateTime? updatedAt;

  const ApiSede({
    required this.codigo,
    required this.nombre,
    required this.sedeApp,
    this.totalClientes = 0,
    this.updatedAt,
  });

  /// Obtiene la sede como enum
  Sede? get sede => Sede.tryFromString(sedeApp);

  factory ApiSede.fromJson(Map<String, dynamic> json) {
    return ApiSede(
      codigo: json['codigo'] as int,
      nombre: json['nombre'] as String,
      sedeApp: json['sede_app'] as String,
      totalClientes: json['total_clientes'] as int? ?? 0,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  /// Crea desde la respuesta de la API externa
  factory ApiSede.fromExternalApi(Map<String, dynamic> json, String sedeApp) {
    return ApiSede(
      codigo: json['codigo'] as int,
      nombre: json['nombre'] as String,
      sedeApp: sedeApp,
      totalClientes: json['total_clientes'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'codigo': codigo,
      'nombre': nombre,
      'sede_app': sedeApp,
      'total_clientes': totalClientes,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

/// Modelo de visita a cliente
class ClientVisit {
  final String id;
  final String clientCoCli;
  final String mercaderistaId;
  final DateTime visitedAt;
  final double? latitude;
  final double? longitude;
  final String? notes;
  final List<String>? photos;
  final DateTime createdAt;

  const ClientVisit({
    required this.id,
    required this.clientCoCli,
    required this.mercaderistaId,
    required this.visitedAt,
    this.latitude,
    this.longitude,
    this.notes,
    this.photos,
    required this.createdAt,
  });

  factory ClientVisit.fromJson(Map<String, dynamic> json) {
    return ClientVisit(
      id: json['id'] as String,
      clientCoCli: json['client_co_cli'] as String,
      mercaderistaId: json['mercaderista_id'] as String,
      visitedAt: DateTime.parse(json['visited_at'] as String),
      latitude: json['latitude'] != null
          ? (json['latitude'] as num).toDouble()
          : null,
      longitude: json['longitude'] != null
          ? (json['longitude'] as num).toDouble()
          : null,
      notes: json['notes'] as String?,
      photos: json['photos'] != null
          ? List<String>.from(json['photos'] as List)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'client_co_cli': clientCoCli,
      'mercaderista_id': mercaderistaId,
      'visited_at': visitedAt.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'notes': notes,
      'photos': photos,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
