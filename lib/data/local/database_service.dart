import 'dart:async';
import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/models/route.dart';
import '../../core/models/route_type.dart';
import '../../core/models/client.dart';
import '../../core/models/route_visit.dart';
import '../../core/models/route_form_question.dart';
import '../../core/models/prospect.dart';
import '../../core/enums/route_status.dart';

/// Servicio de base de datos SQLite para almacenamiento offline
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;
  
  factory DatabaseService() => _instance;
  
  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'disbattery_offline.db');
    
    return await openDatabase(
      path,
      version: 8,
      onCreate: _createDb,
      onUpgrade: _upgradeDb,
    );
  }

  Future<void> _createDb(Database db, int version) async {
    // Tabla de rutas locales
    await db.execute('''
      CREATE TABLE routes (
        id TEXT PRIMARY KEY,
        mercaderista_id TEXT NOT NULL,
        name TEXT NOT NULL,
        scheduled_date TEXT NOT NULL,
        status TEXT NOT NULL,
        total_clients INTEGER DEFAULT 0,
        completed_clients INTEGER DEFAULT 0,
        estimated_duration TEXT,
        started_at TEXT,
        completed_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        template_id TEXT,
        route_type_id TEXT,
        notes TEXT,
        sede_app TEXT NOT NULL,
        created_by TEXT,
        route_type_name TEXT,
        route_type_color TEXT,
        brands_json TEXT,
        is_synced INTEGER DEFAULT 1,
        last_synced_at TEXT
      )
    ''');

    // Tabla de clientes en rutas
    await db.execute('''
      CREATE TABLE route_clients (
        id TEXT PRIMARY KEY,
        route_id TEXT NOT NULL,
        client_co_cli TEXT NOT NULL,
        order_number INTEGER NOT NULL,
        status TEXT DEFAULT 'pending',
        started_at TEXT,
        completed_at TEXT,
        latitude_start REAL,
        longitude_start REAL,
        latitude_end REAL,
        longitude_end REAL,
        created_at TEXT NOT NULL,
        client_name TEXT,
        client_address TEXT,
        client_phone TEXT,
        closure_reason TEXT,
        closure_photo_url TEXT,
        is_synced INTEGER DEFAULT 1,
        FOREIGN KEY (route_id) REFERENCES routes(id) ON DELETE CASCADE
      )
    ''');

    // Tabla de visitas locales (pendientes de sincronización)
    await db.execute('''
      CREATE TABLE pending_visits (
        id TEXT PRIMARY KEY,
        route_id TEXT NOT NULL,
        route_client_id TEXT NOT NULL,
        client_co_cli TEXT NOT NULL,
        mercaderista_id TEXT NOT NULL,
        latitude_start REAL,
        longitude_start REAL,
        latitude_end REAL,
        longitude_end REAL,
        started_at TEXT,
        completed_at TEXT,
        notes TEXT,
        photos_json TEXT,
        answers_json TEXT,
        created_at TEXT NOT NULL,
        is_synced INTEGER DEFAULT 0
      )
    ''');

    // Tabla de cambios pendientes de sincronización
    await db.execute('''
      CREATE TABLE pending_sync (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,
        record_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        data_json TEXT NOT NULL,
        created_at TEXT NOT NULL,
        retry_count INTEGER DEFAULT 0,
        last_error TEXT
      )
    ''');

    // Tabla de preguntas del formulario
    await db.execute('''
      CREATE TABLE route_form_questions (
        id TEXT PRIMARY KEY,
        route_type_id TEXT NOT NULL,
        question_text TEXT NOT NULL,
        question_type TEXT NOT NULL,
        options_json TEXT,
        is_required INTEGER DEFAULT 0,
        display_order INTEGER DEFAULT 0,
        is_active INTEGER DEFAULT 1,
        created_at TEXT,
        section TEXT,
        depends_on TEXT,
        depends_value TEXT,
        metadata_json TEXT
      )
    ''');

    // Tabla de eventos
    await db.execute('''
      CREATE TABLE events (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        route_type_id TEXT,
        location_name TEXT,
        latitude REAL,
        longitude REAL,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'planned',
        notes TEXT,
        sede_app TEXT NOT NULL,
        created_by TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        is_synced INTEGER DEFAULT 1
      )
    ''');

    // Tabla de mercaderistas asignados a eventos
    await db.execute('''
      CREATE TABLE event_mercaderistas (
        id TEXT PRIMARY KEY,
        event_id TEXT NOT NULL,
        mercaderista_id TEXT NOT NULL,
        mercaderista_name TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE
      )
    ''');

    // Tabla de check-ins de eventos
    await db.execute('''
      CREATE TABLE event_check_ins (
        id TEXT PRIMARY KEY,
        event_id TEXT NOT NULL,
        mercaderista_id TEXT NOT NULL,
        check_in_date TEXT NOT NULL,
        started_at TEXT,
        completed_at TEXT,
        latitude REAL,
        longitude REAL,
        observations TEXT,
        answers_json TEXT,
        created_at TEXT NOT NULL,
        is_synced INTEGER DEFAULT 1,
        FOREIGN KEY (event_id) REFERENCES events(id)
      )
    ''');

    // Tabla de prospectos (offline-first)
    await db.execute('''
      CREATE TABLE prospects (
        id TEXT PRIMARY KEY,
        mercaderista_id TEXT NOT NULL,
        name TEXT NOT NULL,
        rif TEXT,
        address TEXT NOT NULL,
        phone TEXT,
        contact_person TEXT,
        latitude REAL,
        longitude REAL,
        photo_url TEXT,
        in_situ INTEGER DEFAULT 1,
        sede_app TEXT NOT NULL,
        notes TEXT,
        status TEXT DEFAULT 'pending',
        created_at TEXT NOT NULL,
        is_synced INTEGER DEFAULT 0
      )
    ''');

    // Índices para mejorar performance
    await db.execute('CREATE INDEX idx_routes_mercaderista ON routes(mercaderista_id)');
    await db.execute('CREATE INDEX idx_routes_date ON routes(scheduled_date)');
    await db.execute('CREATE INDEX idx_route_clients_route ON route_clients(route_id)');
    await db.execute('CREATE INDEX idx_pending_visits_synced ON pending_visits(is_synced)');
    await db.execute('CREATE INDEX idx_pending_sync_table ON pending_sync(table_name)');
    await db.execute('CREATE INDEX idx_questions_route_type ON route_form_questions(route_type_id)');
    await db.execute('CREATE INDEX idx_events_date ON events(start_date)');
    await db.execute('CREATE INDEX idx_event_merc_event ON event_mercaderistas(event_id)');
    await db.execute('CREATE INDEX idx_event_checkin_event ON event_check_ins(event_id)');
    await db.execute('CREATE INDEX idx_prospects_mercaderista ON prospects(mercaderista_id)');
    await db.execute('CREATE INDEX idx_prospects_synced ON prospects(is_synced)');
  }

  Future<void> _upgradeDb(Database db, int oldVersion, int newVersion) async {
    // Migración de v1 a v2: Agregar tabla de preguntas
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS route_form_questions (
          id TEXT PRIMARY KEY,
          route_type_id TEXT NOT NULL,
          question_text TEXT NOT NULL,
          question_type TEXT NOT NULL,
          options_json TEXT,
          is_required INTEGER DEFAULT 0,
          display_order INTEGER DEFAULT 0,
          is_active INTEGER DEFAULT 1,
          created_at TEXT
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_questions_route_type ON route_form_questions(route_type_id)');
    }

    // Migración de v2 a v3: Agregar closure_reason a route_clients
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE route_clients ADD COLUMN closure_reason TEXT');
    }

    // Migración de v3 a v4: Tablas de eventos
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS events (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          description TEXT,
          route_type_id TEXT,
          location_name TEXT,
          latitude REAL,
          longitude REAL,
          start_date TEXT NOT NULL,
          end_date TEXT NOT NULL,
          status TEXT NOT NULL DEFAULT 'planned',
          notes TEXT,
          sede_app TEXT NOT NULL,
          created_by TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT,
          is_synced INTEGER DEFAULT 1
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS event_mercaderistas (
          id TEXT PRIMARY KEY,
          event_id TEXT NOT NULL,
          mercaderista_id TEXT NOT NULL,
          mercaderista_name TEXT,
          created_at TEXT NOT NULL,
          FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS event_check_ins (
          id TEXT PRIMARY KEY,
          event_id TEXT NOT NULL,
          mercaderista_id TEXT NOT NULL,
          check_in_date TEXT NOT NULL,
          started_at TEXT,
          completed_at TEXT,
          latitude REAL,
          longitude REAL,
          observations TEXT,
          answers_json TEXT,
          created_at TEXT NOT NULL,
          is_synced INTEGER DEFAULT 1,
          FOREIGN KEY (event_id) REFERENCES events(id)
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_events_date ON events(start_date)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_event_merc_event ON event_mercaderistas(event_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_event_checkin_event ON event_check_ins(event_id)');
    }

    // Migración de v4 a v5: Columnas para secciones y condicionales en preguntas
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE route_form_questions ADD COLUMN section TEXT');
      await db.execute('ALTER TABLE route_form_questions ADD COLUMN depends_on TEXT');
      await db.execute('ALTER TABLE route_form_questions ADD COLUMN depends_value TEXT');
      await db.execute('ALTER TABLE route_form_questions ADD COLUMN metadata_json TEXT');
      // Forzar re-descarga de preguntas actualizadas
      await db.execute('DELETE FROM route_form_questions');
    }

    // Migración de v5 a v6: Agregar columna brands_json a routes
    if (oldVersion < 6) {
      await db.execute('ALTER TABLE routes ADD COLUMN brands_json TEXT');
    }

    // Migración de v6 a v7: Agregar closure_photo_url a route_clients
    if (oldVersion < 7) {
      await db.execute('ALTER TABLE route_clients ADD COLUMN closure_photo_url TEXT');
    }

    // Migración de v7 a v8: Tabla de prospectos
    if (oldVersion < 8) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS prospects (
          id TEXT PRIMARY KEY,
          mercaderista_id TEXT NOT NULL,
          name TEXT NOT NULL,
          rif TEXT,
          address TEXT NOT NULL,
          phone TEXT,
          contact_person TEXT,
          latitude REAL,
          longitude REAL,
          photo_url TEXT,
          in_situ INTEGER DEFAULT 1,
          sede_app TEXT NOT NULL,
          notes TEXT,
          status TEXT DEFAULT 'pending',
          created_at TEXT NOT NULL,
          is_synced INTEGER DEFAULT 0
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_prospects_mercaderista ON prospects(mercaderista_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_prospects_synced ON prospects(is_synced)');
    }
  }

  // ========================
  // OPERACIONES DE RUTAS
  // ========================

  /// Guarda o actualiza una ruta localmente
  Future<void> saveRoute(AppRoute route, {bool isSynced = true}) async {
    final db = await database;
    
    await db.insert(
      'routes',
      {
        'id': route.id,
        'mercaderista_id': route.mercaderistaId,
        'name': route.name,
        'scheduled_date': route.scheduledDate.toIso8601String().split('T')[0],
        'status': route.status.value,
        'total_clients': route.totalClients,
        'completed_clients': route.completedClients,
        'estimated_duration': route.estimatedDuration?.toString(),
        'started_at': route.startedAt?.toIso8601String(),
        'completed_at': route.completedAt?.toIso8601String(),
        'created_at': route.createdAt.toIso8601String(),
        'updated_at': route.updatedAt?.toIso8601String(),
        'template_id': route.templateId,
        'route_type_id': route.routeTypeId,
        'notes': route.notes,
        'sede_app': route.sedeApp,
        'created_by': route.createdBy,
        'route_type_name': route.routeType?.name,
        'route_type_color': route.routeType?.color,
        'brands_json': route.brands != null ? jsonEncode(route.brands) : null,
        'is_synced': isSynced ? 1 : 0,
        'last_synced_at': isSynced ? DateTime.now().toIso8601String() : null,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Guardar clientes de la ruta si existen
    if (route.clients != null) {
      for (final client in route.clients!) {
        await saveRouteClient(client, isSynced: isSynced);
      }
    }
  }

  /// Guarda o actualiza un cliente de ruta localmente
  Future<void> saveRouteClient(RouteClient client, {bool isSynced = true}) async {
    final db = await database;
    
    await db.insert(
      'route_clients',
      {
        'id': client.id,
        'route_id': client.routeId,
        'client_co_cli': client.clientId,
        'order_number': client.orderNumber,
        'status': client.status.toDbString(),
        'started_at': client.startedAt?.toIso8601String(),
        'completed_at': client.completedAt?.toIso8601String(),
        'latitude_start': client.latitudeStart,
        'longitude_start': client.longitudeStart,
        'latitude_end': client.latitudeEnd,
        'longitude_end': client.longitudeEnd,
        'created_at': client.createdAt.toIso8601String(),
        'client_name': client.client?.cliDes,
        'client_address': client.client?.direc1,
        'client_phone': client.client?.telefonos,
        'closure_reason': client.closureReason,
        'closure_photo_url': client.closurePhotoUrl,
        'is_synced': isSynced ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Obtiene todas las rutas locales para un mercaderista y fecha
  Future<List<AppRoute>> getRoutesForDate(String mercaderistaId, DateTime date) async {
    final db = await database;
    final dateStr = date.toIso8601String().split('T')[0];
    
    final routeMaps = await db.query(
      'routes',
      where: 'mercaderista_id = ? AND scheduled_date = ?',
      whereArgs: [mercaderistaId, dateStr],
      orderBy: 'created_at ASC',
    );

    final routes = <AppRoute>[];
    for (final routeMap in routeMaps) {
      final clients = await _getClientsForRoute(routeMap['id'] as String);
      routes.add(_mapToRoute(routeMap, clients));
    }
    
    return routes;
  }

  /// Obtiene una ruta por ID
  Future<AppRoute?> getRouteById(String routeId) async {
    final db = await database;
    
    final routeMaps = await db.query(
      'routes',
      where: 'id = ?',
      whereArgs: [routeId],
    );

    if (routeMaps.isEmpty) return null;
    
    final clients = await _getClientsForRoute(routeId);
    return _mapToRoute(routeMaps.first, clients);
  }

  Future<List<RouteClient>> _getClientsForRoute(String routeId) async {
    final db = await database;
    
    final clientMaps = await db.query(
      'route_clients',
      where: 'route_id = ?',
      whereArgs: [routeId],
      orderBy: 'order_number ASC',
    );

    return clientMaps.map(_mapToRouteClient).toList();
  }

  AppRoute _mapToRoute(Map<String, dynamic> map, List<RouteClient> clients) {
    // Reconstruir RouteType desde campos cached en SQLite
    RouteType? routeType;
    final routeTypeId = map['route_type_id'] as String?;
    final routeTypeName = map['route_type_name'] as String?;
    if (routeTypeId != null && routeTypeName != null) {
      routeType = RouteType(
        id: routeTypeId,
        name: routeTypeName,
        color: (map['route_type_color'] as String?) ?? '#2196F3',
      );
    }

    // Parsear brands desde JSON
    List<String>? brands;
    final brandsJson = map['brands_json'] as String?;
    if (brandsJson != null && brandsJson.isNotEmpty) {
      try {
        brands = List<String>.from(jsonDecode(brandsJson) as List);
      } catch (_) {
        brands = null;
      }
    }

    return AppRoute(
      id: map['id'] as String,
      mercaderistaId: map['mercaderista_id'] as String,
      name: map['name'] as String,
      scheduledDate: DateTime.parse(map['scheduled_date'] as String),
      status: RouteStatus.fromString(map['status'] as String),
      totalClients: map['total_clients'] as int? ?? 0,
      completedClients: map['completed_clients'] as int? ?? 0,
      estimatedDuration: map['estimated_duration'] != null
          ? _parseDuration(map['estimated_duration'] as String)
          : null,
      startedAt: map['started_at'] != null
          ? DateTime.parse(map['started_at'] as String)
          : null,
      completedAt: map['completed_at'] != null
          ? DateTime.parse(map['completed_at'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
      templateId: map['template_id'] as String?,
      routeTypeId: routeTypeId,
      routeType: routeType,
      notes: map['notes'] as String?,
      sedeApp: map['sede_app'] as String,
      createdBy: map['created_by'] as String?,
      brands: brands,
      clients: clients,
    );
  }

  RouteClient _mapToRouteClient(Map<String, dynamic> map) {
    // Crear un Client mínimo desde los datos almacenados localmente
    final clientName = map['client_name'] as String?;
    Client? minimalClient;
    if (clientName != null) {
      minimalClient = Client(
        coCli: map['client_co_cli'] as String,
        cliDes: clientName,
        direc1: map['client_address'] as String?,
        telefonos: map['client_phone'] as String?,
      );
    }

    return RouteClient(
      id: map['id'] as String,
      routeId: map['route_id'] as String,
      clientId: map['client_co_cli'] as String,
      orderNumber: map['order_number'] as int,
      status: RouteClientStatusExtension.fromString(map['status'] as String),
      startedAt: map['started_at'] != null
          ? DateTime.parse(map['started_at'] as String)
          : null,
      completedAt: map['completed_at'] != null
          ? DateTime.parse(map['completed_at'] as String)
          : null,
      latitudeStart: map['latitude_start'] as double?,
      longitudeStart: map['longitude_start'] as double?,
      latitudeEnd: map['latitude_end'] as double?,
      longitudeEnd: map['longitude_end'] as double?,
      closureReason: map['closure_reason'] as String?,
      closurePhotoUrl: map['closure_photo_url'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      client: minimalClient,
    );
  }

  Duration? _parseDuration(String value) {
    final parts = value.split(':');
    if (parts.length >= 2) {
      return Duration(
        hours: int.tryParse(parts[0]) ?? 0,
        minutes: int.tryParse(parts[1]) ?? 0,
      );
    }
    return null;
  }

  // ========================
  // OPERACIONES DE SINCRONIZACIÓN
  // ========================

  /// Actualiza el estado de un cliente de ruta (offline)
  Future<void> updateRouteClientStatus({
    required String routeClientId,
    required RouteClientStatus status,
    DateTime? startedAt,
    DateTime? completedAt,
    double? latitudeStart,
    double? longitudeStart,
    double? latitudeEnd,
    double? longitudeEnd,
    String? closureReason,
    String? closurePhotoUrl,
  }) async {
    final db = await database;

    final updates = <String, dynamic>{
      'status': status.toDbString(),
      'is_synced': 0,
    };

    if (startedAt != null) updates['started_at'] = startedAt.toIso8601String();
    if (completedAt != null) updates['completed_at'] = completedAt.toIso8601String();
    if (latitudeStart != null) updates['latitude_start'] = latitudeStart;
    if (longitudeStart != null) updates['longitude_start'] = longitudeStart;
    if (latitudeEnd != null) updates['latitude_end'] = latitudeEnd;
    if (longitudeEnd != null) updates['longitude_end'] = longitudeEnd;
    if (closureReason != null) updates['closure_reason'] = closureReason;
    if (closurePhotoUrl != null) updates['closure_photo_url'] = closurePhotoUrl;

    await db.update(
      'route_clients',
      updates,
      where: 'id = ?',
      whereArgs: [routeClientId],
    );

    // Actualizar contador de completados en la ruta
    final client = await db.query(
      'route_clients',
      where: 'id = ?',
      whereArgs: [routeClientId],
    );
    
    if (client.isNotEmpty) {
      final routeId = client.first['route_id'] as String;
      await _updateRouteCompletedCount(routeId);
    }
  }

  Future<void> _updateRouteCompletedCount(String routeId) async {
    final db = await database;
    
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count FROM route_clients 
      WHERE route_id = ? AND status = 'completed'
    ''', [routeId]);
    
    final completedCount = result.first['count'] as int;
    
    await db.update(
      'routes',
      {'completed_clients': completedCount, 'is_synced': 0},
      where: 'id = ?',
      whereArgs: [routeId],
    );
  }

  /// Actualiza el estado de una ruta
  Future<void> updateRouteStatus(String routeId, RouteStatus status) async {
    final db = await database;
    
    final updates = <String, dynamic>{
      'status': status.value,
      'is_synced': 0,
    };
    
    if (status == RouteStatus.inProgress) {
      updates['started_at'] = DateTime.now().toIso8601String();
    } else if (status == RouteStatus.completed) {
      updates['completed_at'] = DateTime.now().toIso8601String();
    }

    await db.update(
      'routes',
      updates,
      where: 'id = ?',
      whereArgs: [routeId],
    );
  }

  /// Obtiene registros no sincronizados
  Future<List<Map<String, dynamic>>> getUnsyncedRoutes() async {
    final db = await database;
    return db.query('routes', where: 'is_synced = 0');
  }

  Future<List<Map<String, dynamic>>> getUnsyncedRouteClients() async {
    final db = await database;
    return db.query('route_clients', where: 'is_synced = 0');
  }

  /// Marca registros como sincronizados
  Future<void> markRouteSynced(String routeId) async {
    final db = await database;
    await db.update(
      'routes',
      {'is_synced': 1, 'last_synced_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [routeId],
    );
  }

  Future<void> markRouteClientSynced(String clientId) async {
    final db = await database;
    await db.update(
      'route_clients',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [clientId],
    );
  }

  /// Guarda operación pendiente de sincronización
  Future<void> savePendingSync({
    required String tableName,
    required String recordId,
    required String operation,
    required Map<String, dynamic> data,
  }) async {
    final db = await database;
    
    await db.insert('pending_sync', {
      'table_name': tableName,
      'record_id': recordId,
      'operation': operation,
      'data_json': jsonEncode(data),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Obtiene operaciones pendientes de sincronización
  Future<List<Map<String, dynamic>>> getPendingSyncOperations() async {
    final db = await database;
    return db.query('pending_sync', orderBy: 'created_at ASC');
  }

  /// Elimina operación sincronizada
  Future<void> removePendingSync(int id) async {
    final db = await database;
    await db.delete('pending_sync', where: 'id = ?', whereArgs: [id]);
  }

  /// Limpia todos los datos locales
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('pending_sync');
    await db.delete('pending_visits');
    await db.delete('prospects');
    await db.delete('event_check_ins');
    await db.delete('event_mercaderistas');
    await db.delete('events');
    await db.delete('route_clients');
    await db.delete('routes');
  }

  /// Elimina rutas antiguas (más de 30 días)
  Future<void> cleanOldRoutes() async {
    final db = await database;
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

    await db.delete(
      'routes',
      where: 'scheduled_date < ? AND is_synced = 1',
      whereArgs: [thirtyDaysAgo.toIso8601String().split('T')[0]],
    );
  }

  // ========================
  // PENDING VISITS
  // ========================

  /// Guarda una visita pendiente en SQLite (para sobrevivir app kills)
  Future<void> insertPendingVisit(RouteVisit visit) async {
    final db = await database;
    final id = visit.id.isNotEmpty
        ? visit.id
        : '${visit.routeClientId}_${DateTime.now().millisecondsSinceEpoch}';
    await db.insert(
      'pending_visits',
      {
        'id': id,
        'route_id': visit.routeId ?? '',
        'route_client_id': visit.routeClientId,
        'client_co_cli': visit.clientCoCli ?? '',
        'mercaderista_id': visit.mercaderistaId ?? '',
        'latitude_end': visit.latitude,
        'longitude_end': visit.longitude,
        'completed_at': visit.visitedAt.toIso8601String(),
        'notes': visit.notes,
        'photos_json': jsonEncode(visit.photos ?? []),
        'answers_json':
            jsonEncode(visit.answers?.map((a) => a.toJson()).toList() ?? []),
        'created_at': visit.createdAt.toIso8601String(),
        'is_synced': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Obtiene visitas pendientes de sincronización por rutaId
  Future<List<RouteVisit>> getPendingVisitsByRoute(String routeId) async {
    final db = await database;
    final rows = await db.query(
      'pending_visits',
      where: 'route_id = ? AND is_synced = 0',
      whereArgs: [routeId],
    );
    return rows.map((row) {
      final photosJson = row['photos_json'] as String?;
      final answersJson = row['answers_json'] as String?;
      return RouteVisit(
        id: row['id'] as String,
        routeClientId: row['route_client_id'] as String,
        routeId: row['route_id'] as String?,
        clientCoCli: row['client_co_cli'] as String?,
        mercaderistaId: row['mercaderista_id'] as String?,
        visitedAt: DateTime.parse(row['completed_at'] as String),
        latitude: row['latitude_end'] != null
            ? (row['latitude_end'] as num).toDouble()
            : null,
        longitude: row['longitude_end'] != null
            ? (row['longitude_end'] as num).toDouble()
            : null,
        notes: row['notes'] as String?,
        photos: photosJson != null
            ? List<String>.from(jsonDecode(photosJson) as List)
            : null,
        createdAt: DateTime.parse(row['created_at'] as String),
        answers: answersJson != null
            ? (jsonDecode(answersJson) as List)
                .map((e) =>
                    RouteVisitAnswer.fromJson(e as Map<String, dynamic>))
                .toList()
            : null,
      );
    }).toList();
  }

  /// Obtiene TODAS las visitas pendientes sin sincronizar (de cualquier ruta)
  Future<List<RouteVisit>> getAllUnsyncedPendingVisits() async {
    final db = await database;
    final rows = await db.query(
      'pending_visits',
      where: 'is_synced = 0',
    );
    return rows.map((row) {
      final photosJson = row['photos_json'] as String?;
      final answersJson = row['answers_json'] as String?;
      return RouteVisit(
        id: row['id'] as String,
        routeClientId: row['route_client_id'] as String,
        routeId: row['route_id'] as String?,
        clientCoCli: row['client_co_cli'] as String?,
        mercaderistaId: row['mercaderista_id'] as String?,
        visitedAt: DateTime.parse(row['completed_at'] as String),
        latitude: row['latitude_end'] != null
            ? (row['latitude_end'] as num).toDouble()
            : null,
        longitude: row['longitude_end'] != null
            ? (row['longitude_end'] as num).toDouble()
            : null,
        notes: row['notes'] as String?,
        photos: photosJson != null
            ? List<String>.from(jsonDecode(photosJson) as List)
            : null,
        createdAt: DateTime.parse(row['created_at'] as String),
        answers: answersJson != null
            ? (jsonDecode(answersJson) as List)
                .map((e) =>
                    RouteVisitAnswer.fromJson(e as Map<String, dynamic>))
                .toList()
            : null,
      );
    }).toList();
  }

  /// Marca una visita pendiente como sincronizada
  Future<void> markPendingVisitSynced(String visitId) async {
    final db = await database;
    await db.update(
      'pending_visits',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [visitId],
    );
  }

  /// Elimina visitas pendientes de una ruta (tras sync exitoso)
  Future<void> deletePendingVisitsByRoute(String routeId) async {
    final db = await database;
    await db.delete('pending_visits',
        where: 'route_id = ?', whereArgs: [routeId]);
  }

  // ========================
  // PREGUNTAS DEL FORMULARIO
  // ========================

  /// Guarda preguntas del formulario para un tipo de ruta
  Future<void> saveFormQuestions(List<RouteFormQuestion> questions) async {
    final db = await database;

    for (final question in questions) {
      String? metadataStr;
      if (question.metadata != null && question.metadata!.isNotEmpty) {
        metadataStr = jsonEncode(question.metadata);
      }

      await db.insert(
        'route_form_questions',
        {
          'id': question.id,
          'route_type_id': question.routeTypeId,
          'question_text': question.questionText,
          'question_type': question.questionType.value,
          'options_json': question.options?.join('|||'),
          'is_required': question.isRequired ? 1 : 0,
          'display_order': question.displayOrder,
          'is_active': question.isActive ? 1 : 0,
          'created_at': question.createdAt?.toIso8601String(),
          'section': question.section,
          'depends_on': question.dependsOn,
          'depends_value': question.dependsValue,
          'metadata_json': metadataStr,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  /// Obtiene preguntas del formulario por tipo de ruta
  Future<List<RouteFormQuestion>> getFormQuestionsByRouteType(String routeTypeId) async {
    final db = await database;

    final questionMaps = await db.query(
      'route_form_questions',
      where: 'route_type_id = ? AND is_active = 1',
      whereArgs: [routeTypeId],
      orderBy: 'display_order ASC',
    );

    return questionMaps.map((map) {
      final optionsStr = map['options_json'] as String?;
      List<String>? options;
      if (optionsStr != null && optionsStr.isNotEmpty) {
        options = optionsStr.split('|||');
      }

      // Parsear metadata_json
      Map<String, dynamic>? metadata;
      final metadataStr = map['metadata_json'] as String?;
      if (metadataStr != null && metadataStr.isNotEmpty) {
        try {
          metadata = Map<String, dynamic>.from(jsonDecode(metadataStr) as Map);
        } catch (_) {
          metadata = null;
        }
      }

      return RouteFormQuestion(
        id: map['id'] as String,
        routeTypeId: map['route_type_id'] as String,
        questionText: map['question_text'] as String,
        questionType: QuestionType.fromString(map['question_type'] as String),
        options: options,
        isRequired: (map['is_required'] as int) == 1,
        displayOrder: map['display_order'] as int? ?? 0,
        isActive: (map['is_active'] as int) == 1,
        createdAt: map['created_at'] != null
            ? DateTime.parse(map['created_at'] as String)
            : null,
        section: map['section'] as String?,
        dependsOn: map['depends_on'] as String?,
        dependsValue: map['depends_value'] as String?,
        metadata: metadata,
      );
    }).toList();
  }


  /// Verifica si hay preguntas guardadas para un tipo de ruta
  Future<bool> hasQuestionsForRouteType(String routeTypeId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count FROM route_form_questions
      WHERE route_type_id = ? AND is_active = 1
    ''', [routeTypeId]);
    return (result.first['count'] as int) > 0;
  }

  // ========================
  // OPERACIONES DE EVENTOS
  // ========================

  /// Guarda un evento localmente
  Future<void> saveEvent(Map<String, dynamic> eventJson) async {
    final db = await database;
    await db.insert(
      'events',
      {
        'id': eventJson['id'],
        'name': eventJson['name'],
        'description': eventJson['description'],
        'route_type_id': eventJson['route_type_id'],
        'location_name': eventJson['location_name'],
        'latitude': eventJson['latitude'],
        'longitude': eventJson['longitude'],
        'start_date': eventJson['start_date'],
        'end_date': eventJson['end_date'],
        'status': eventJson['status'] ?? 'planned',
        'notes': eventJson['notes'],
        'sede_app': eventJson['sede_app'],
        'created_by': eventJson['created_by'],
        'created_at': eventJson['created_at'] ?? DateTime.now().toIso8601String(),
        'updated_at': eventJson['updated_at'],
        'is_synced': 1,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Guarda un mercaderista asignado a un evento
  Future<void> saveEventMercaderista(Map<String, dynamic> json) async {
    final db = await database;
    await db.insert(
      'event_mercaderistas',
      {
        'id': json['id'],
        'event_id': json['event_id'],
        'mercaderista_id': json['mercaderista_id'],
        'mercaderista_name': json['mercaderista_name'],
        'created_at': json['created_at'] ?? DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Obtiene eventos para un mercaderista en una fecha
  Future<List<Map<String, dynamic>>> getEventsForDate(
      String mercaderistaId, String date) async {
    final db = await database;
    final events = await db.rawQuery('''
      SELECT e.* FROM events e
      INNER JOIN event_mercaderistas em ON em.event_id = e.id
      WHERE em.mercaderista_id = ?
        AND e.start_date <= ?
        AND e.end_date >= ?
        AND e.status != 'cancelled'
      ORDER BY e.start_date ASC
    ''', [mercaderistaId, date, date]);
    return events;
  }

  /// Obtiene mercaderistas de un evento
  Future<List<Map<String, dynamic>>> getEventMercaderistas(String eventId) async {
    final db = await database;
    return db.query(
      'event_mercaderistas',
      where: 'event_id = ?',
      whereArgs: [eventId],
    );
  }

  /// Guarda un check-in de evento localmente
  Future<void> saveEventCheckIn(Map<String, dynamic> checkInJson) async {
    final db = await database;
    await db.insert(
      'event_check_ins',
      {
        'id': checkInJson['id'],
        'event_id': checkInJson['event_id'],
        'mercaderista_id': checkInJson['mercaderista_id'],
        'check_in_date': checkInJson['check_in_date'],
        'started_at': checkInJson['started_at'],
        'completed_at': checkInJson['completed_at'],
        'latitude': checkInJson['latitude'],
        'longitude': checkInJson['longitude'],
        'observations': checkInJson['observations'],
        'answers_json': checkInJson['answers_json'],
        'created_at': checkInJson['created_at'] ?? DateTime.now().toIso8601String(),
        'is_synced': checkInJson['is_synced'] ?? 1,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Obtiene check-ins de un evento para un mercaderista
  Future<List<Map<String, dynamic>>> getEventCheckIns(
      String eventId, String mercaderistaId) async {
    final db = await database;
    return db.query(
      'event_check_ins',
      where: 'event_id = ? AND mercaderista_id = ?',
      whereArgs: [eventId, mercaderistaId],
      orderBy: 'check_in_date DESC',
    );
  }

  // ========================
  // PROSPECTOS
  // ========================

  /// Guarda un prospecto localmente
  Future<void> saveProspect(Prospect prospect) async {
    final db = await database;
    await db.insert(
      'prospects',
      prospect.toSqlite(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Obtiene prospectos no sincronizados
  Future<List<Prospect>> getUnsyncedProspects() async {
    final db = await database;
    final rows = await db.query('prospects', where: 'is_synced = 0');
    return rows.map((row) => Prospect.fromJson(row)).toList();
  }

  /// Obtiene prospectos de un mercaderista
  Future<List<Prospect>> getProspectsByMercaderista(String mercaderistaId) async {
    final db = await database;
    final rows = await db.query(
      'prospects',
      where: 'mercaderista_id = ?',
      whereArgs: [mercaderistaId],
      orderBy: 'created_at DESC',
    );
    return rows.map((row) => Prospect.fromJson(row)).toList();
  }

  /// Marca un prospecto como sincronizado
  Future<void> markProspectSynced(String prospectId) async {
    final db = await database;
    await db.update(
      'prospects',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [prospectId],
    );
  }

  /// Actualiza la URL de foto de un prospecto (tras sync)
  Future<void> updateProspectPhotoUrl(String prospectId, String photoUrl) async {
    final db = await database;
    await db.update(
      'prospects',
      {'photo_url': photoUrl},
      where: 'id = ?',
      whereArgs: [prospectId],
    );
  }
}

