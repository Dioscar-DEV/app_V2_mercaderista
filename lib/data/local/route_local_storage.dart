import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/models/route.dart';
import '../../core/models/route_visit.dart';
import '../../core/models/route_form_question.dart';

/// Servicio de almacenamiento local para rutas
/// Permite almacenar datos de rutas para funcionamiento offline
class RouteLocalStorage {
  static const String _routesKey = 'offline_routes';
  static const String _pendingVisitsKey = 'pending_visits';
  static const String _questionsKey = 'route_questions_';

  // ========================
  // RUTAS OFFLINE
  // ========================

  /// Guarda una ruta completa para uso offline
  Future<void> saveRouteOffline(AppRoute route, List<RouteFormQuestion> questions) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Guardar la ruta
    final routesJson = prefs.getString(_routesKey);
    final routes = routesJson != null 
        ? Map<String, dynamic>.from(jsonDecode(routesJson))
        : <String, dynamic>{};
    
    routes[route.id] = route.toJson();
    await prefs.setString(_routesKey, jsonEncode(routes));

    // Guardar las preguntas del formulario
    if (questions.isNotEmpty) {
      await prefs.setString(
        '$_questionsKey${route.id}',
        jsonEncode(questions.map((q) => q.toJson()).toList()),
      );
    }
  }

  /// Obtiene una ruta guardada offline
  Future<Map<String, dynamic>?> getRouteOffline(String routeId) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Obtener la ruta
    final routesJson = prefs.getString(_routesKey);
    if (routesJson == null) return null;
    
    final routes = Map<String, dynamic>.from(jsonDecode(routesJson));
    final routeJson = routes[routeId];
    if (routeJson == null) return null;

    final route = AppRoute.fromJson(Map<String, dynamic>.from(routeJson));

    // Obtener las preguntas
    final questionsJson = prefs.getString('$_questionsKey$routeId');
    List<RouteFormQuestion> questions = [];
    if (questionsJson != null) {
      final questionsList = jsonDecode(questionsJson) as List;
      questions = questionsList
          .map((q) => RouteFormQuestion.fromJson(Map<String, dynamic>.from(q)))
          .toList();
    }

    return {
      'route': route,
      'questions': questions,
    };
  }

  /// Obtiene todas las rutas guardadas offline
  Future<List<AppRoute>> getAllOfflineRoutes() async {
    final prefs = await SharedPreferences.getInstance();
    final routesJson = prefs.getString(_routesKey);
    
    if (routesJson == null) return [];

    final routes = Map<String, dynamic>.from(jsonDecode(routesJson));
    return routes.values
        .map((r) => AppRoute.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  /// Actualiza el estado de un cliente en una ruta offline
  Future<void> updateRouteClientOffline(
    String routeId,
    String clientId,
    RouteClientStatus status, {
    DateTime? startedAt,
    DateTime? completedAt,
    double? latitudeStart,
    double? longitudeStart,
    double? latitudeEnd,
    double? longitudeEnd,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    final routesJson = prefs.getString(_routesKey);
    if (routesJson == null) return;
    
    final routes = Map<String, dynamic>.from(jsonDecode(routesJson));
    final routeJson = routes[routeId];
    if (routeJson == null) return;

    final routeData = Map<String, dynamic>.from(routeJson);
    final clients = routeData['route_clients'] as List?;
    if (clients == null) return;

    // Encontrar y actualizar el cliente
    for (int i = 0; i < clients.length; i++) {
      final client = Map<String, dynamic>.from(clients[i]);
      if (client['client_id'] == clientId || client['id'] == clientId) {
        client['status'] = status.toDbString();
        if (startedAt != null) client['started_at'] = startedAt.toIso8601String();
        if (completedAt != null) client['completed_at'] = completedAt.toIso8601String();
        if (latitudeStart != null) client['latitude_start'] = latitudeStart;
        if (longitudeStart != null) client['longitude_start'] = longitudeStart;
        if (latitudeEnd != null) client['latitude_end'] = latitudeEnd;
        if (longitudeEnd != null) client['longitude_end'] = longitudeEnd;
        clients[i] = client;
        break;
      }
    }

    routeData['route_clients'] = clients;
    
    // Actualizar contador de completados
    int completedCount = 0;
    for (final c in clients) {
      if (c['status'] == 'completed') completedCount++;
    }
    routeData['completed_clients'] = completedCount;

    routes[routeId] = routeData;
    await prefs.setString(_routesKey, jsonEncode(routes));
  }

  /// Elimina una ruta del almacenamiento offline
  Future<void> removeRouteOffline(String routeId) async {
    final prefs = await SharedPreferences.getInstance();
    
    final routesJson = prefs.getString(_routesKey);
    if (routesJson != null) {
      final routes = Map<String, dynamic>.from(jsonDecode(routesJson));
      routes.remove(routeId);
      await prefs.setString(_routesKey, jsonEncode(routes));
    }

    // Eliminar también las preguntas
    await prefs.remove('$_questionsKey$routeId');
  }

  // ========================
  // VISITAS PENDIENTES
  // ========================

  /// Guarda una visita pendiente de sincronización
  Future<void> savePendingVisit(RouteVisit visit) async {
    final prefs = await SharedPreferences.getInstance();
    
    final visitsJson = prefs.getString(_pendingVisitsKey);
    final visits = visitsJson != null 
        ? (jsonDecode(visitsJson) as List).cast<Map<String, dynamic>>()
        : <Map<String, dynamic>>[];

    visits.add(visit.toLocalJson());
    await prefs.setString(_pendingVisitsKey, jsonEncode(visits));
  }

  /// Obtiene todas las visitas pendientes de sincronización
  Future<List<RouteVisit>> getPendingVisits() async {
    final prefs = await SharedPreferences.getInstance();
    final visitsJson = prefs.getString(_pendingVisitsKey);
    
    if (visitsJson == null) return [];

    return (jsonDecode(visitsJson) as List)
        .map((v) => RouteVisit.fromJson(Map<String, dynamic>.from(v)))
        .toList();
  }

  /// Elimina visitas pendientes ya sincronizadas
  Future<void> removeSyncedVisits(List<String> visitIds) async {
    final prefs = await SharedPreferences.getInstance();
    
    final visitsJson = prefs.getString(_pendingVisitsKey);
    if (visitsJson == null) return;

    final visits = (jsonDecode(visitsJson) as List)
        .cast<Map<String, dynamic>>()
        .where((v) => !visitIds.contains(v['id']))
        .toList();

    await prefs.setString(_pendingVisitsKey, jsonEncode(visits));
  }

  /// Limpia todas las visitas pendientes
  Future<void> clearPendingVisits() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingVisitsKey);
  }

  // ========================
  // UTILIDADES
  // ========================

  /// Limpia todo el almacenamiento offline de rutas
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Limpiar rutas
    await prefs.remove(_routesKey);
    
    // Limpiar visitas pendientes
    await prefs.remove(_pendingVisitsKey);
    
    // Limpiar preguntas (buscar todas las keys que empiecen con el prefijo)
    final keys = prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith(_questionsKey)) {
        await prefs.remove(key);
      }
    }
  }

  /// Obtiene la cantidad de datos offline almacenados
  Future<Map<String, int>> getOfflineStats() async {
    final prefs = await SharedPreferences.getInstance();
    
    int routesCount = 0;
    final routesJson = prefs.getString(_routesKey);
    if (routesJson != null) {
      final routes = Map<String, dynamic>.from(jsonDecode(routesJson));
      routesCount = routes.length;
    }

    int pendingVisitsCount = 0;
    final visitsJson = prefs.getString(_pendingVisitsKey);
    if (visitsJson != null) {
      final visits = jsonDecode(visitsJson) as List;
      pendingVisitsCount = visits.length;
    }

    return {
      'routes': routesCount,
      'pendingVisits': pendingVisitsCount,
    };
  }
}
