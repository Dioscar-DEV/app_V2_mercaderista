import 'dart:async';
import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/models/route.dart';
import '../../core/models/client.dart';
import '../../core/models/route_visit.dart';
import '../../core/models/route_form_question.dart';
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
      version: 3,
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
        created_at TEXT
      )
    ''');

    // Índices para mejorar performance
    await db.execute('CREATE INDEX idx_routes_mercaderista ON routes(mercaderista_id)');
    await db.execute('CREATE INDEX idx_routes_date ON routes(scheduled_date)');
    await db.execute('CREATE INDEX idx_route_clients_route ON route_clients(route_id)');
    await db.execute('CREATE INDEX idx_pending_visits_synced ON pending_visits(is_synced)');
    await db.execute('CREATE INDEX idx_pending_sync_table ON pending_sync(table_name)');
    await db.execute('CREATE INDEX idx_questions_route_type ON route_form_questions(route_type_id)');
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
      routeTypeId: map['route_type_id'] as String?,
      notes: map['notes'] as String?,
      sedeApp: map['sede_app'] as String,
      createdBy: map['created_by'] as String?,
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
  // PREGUNTAS DEL FORMULARIO
  // ========================

  /// Guarda preguntas del formulario para un tipo de ruta
  Future<void> saveFormQuestions(List<RouteFormQuestion> questions) async {
    final db = await database;
    
    for (final question in questions) {
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

}

