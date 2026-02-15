import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/models/report_models.dart';

class ReportsRepository {
  final SupabaseClient _client;

  ReportsRepository(this._client);

  /// KPIs generales del dashboard
  Future<DashboardStats> getDashboardStats({
    required DateTime from,
    required DateTime to,
    String? sede,
  }) async {
    final fromStr = from.toIso8601String();
    final toStr = to.toIso8601String();

    // Rutas en rango
    var routesQuery = _client
        .from('routes')
        .select('id, status, total_clients, completed_clients')
        .gte('scheduled_date', fromStr.split('T')[0])
        .lte('scheduled_date', toStr.split('T')[0]);
    if (sede != null) routesQuery = routesQuery.eq('sede_app', sede);
    final List<dynamic> routesData = await routesQuery;

    final totalRoutes = routesData.length;
    final completedRoutes = routesData
        .where((r) => r['status'] == 'completed')
        .length;

    // Promedio clientes por ruta
    double avgClients = 0;
    if (totalRoutes > 0) {
      final totalClients = routesData.fold<int>(
          0, (sum, r) => sum + ((r['total_clients'] as int?) ?? 0));
      avgClients = totalClients / totalRoutes;
    }

    // Visitas en rango
    var visitsQuery = _client
        .from('route_visits')
        .select('id, client_co_cli')
        .gte('visited_at', fromStr)
        .lte('visited_at', toStr);
    final List<dynamic> visitsData = await visitsQuery;

    final totalVisits = visitsData.length;
    final uniqueClients = visitsData
        .map((v) => v['client_co_cli'] as String?)
        .where((c) => c != null)
        .toSet()
        .length;

    // Eventos en rango
    var eventsQuery = _client
        .from('events')
        .select('id')
        .gte('start_date', fromStr.split('T')[0])
        .lte('start_date', toStr.split('T')[0]);
    final List<dynamic> eventsData = await eventsQuery;
    final totalEvents = eventsData.length;

    // Check-ins en rango
    var checkInsQuery = _client
        .from('event_check_ins')
        .select('id')
        .gte('check_in_date', fromStr.split('T')[0])
        .lte('check_in_date', toStr.split('T')[0]);
    final List<dynamic> checkInsData = await checkInsQuery;
    final totalCheckIns = checkInsData.length;

    return DashboardStats(
      totalRoutes: totalRoutes,
      completedRoutes: completedRoutes,
      totalVisits: totalVisits,
      uniqueClientsVisited: uniqueClients,
      totalEvents: totalEvents,
      totalCheckIns: totalCheckIns,
      completionRate: totalRoutes > 0 ? completedRoutes / totalRoutes : 0,
      avgClientsPerRoute: avgClients,
    );
  }

  /// Tendencia diaria de rutas y visitas
  Future<List<DailyTrend>> getDailyTrends({
    required DateTime from,
    required DateTime to,
    String? sede,
  }) async {
    final fromStr = from.toIso8601String().split('T')[0];
    final toStr = to.toIso8601String().split('T')[0];

    // Rutas completadas por día
    var routesQuery = _client
        .from('routes')
        .select('scheduled_date, status')
        .eq('status', 'completed')
        .gte('scheduled_date', fromStr)
        .lte('scheduled_date', toStr);
    if (sede != null) routesQuery = routesQuery.eq('sede_app', sede);
    final List<dynamic> routesData = await routesQuery;

    // Visitas por día
    var visitsQuery = _client
        .from('route_visits')
        .select('visited_at')
        .gte('visited_at', from.toIso8601String())
        .lte('visited_at', to.toIso8601String());
    final List<dynamic> visitsData = await visitsQuery;

    // Construir mapa por día
    final Map<String, DailyTrend> trendMap = {};

    // Rellenar todos los días del rango
    var current = from;
    while (current.isBefore(to)) {
      final dateStr = '${current.year}-${current.month.toString().padLeft(2, '0')}-${current.day.toString().padLeft(2, '0')}';
      trendMap[dateStr] = DailyTrend(date: DateTime(current.year, current.month, current.day));
      current = current.add(const Duration(days: 1));
    }

    // Contar rutas
    for (final r in routesData) {
      final dateStr = r['scheduled_date'] as String;
      final existing = trendMap[dateStr];
      if (existing != null) {
        trendMap[dateStr] = DailyTrend(
          date: existing.date,
          routesCompleted: existing.routesCompleted + 1,
          visitsCompleted: existing.visitsCompleted,
        );
      }
    }

    // Contar visitas
    for (final v in visitsData) {
      final visitedAt = DateTime.parse(v['visited_at'] as String);
      final dateStr = '${visitedAt.year}-${visitedAt.month.toString().padLeft(2, '0')}-${visitedAt.day.toString().padLeft(2, '0')}';
      final existing = trendMap[dateStr];
      if (existing != null) {
        trendMap[dateStr] = DailyTrend(
          date: existing.date,
          routesCompleted: existing.routesCompleted,
          visitsCompleted: existing.visitsCompleted + 1,
        );
      }
    }

    final trends = trendMap.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return trends;
  }

  /// Rendimiento por mercaderista
  Future<List<MercaderistaPerformance>> getMercaderistasPerformance({
    required DateTime from,
    required DateTime to,
    String? sede,
  }) async {
    final fromStr = from.toIso8601String().split('T')[0];
    final toStr = to.toIso8601String().split('T')[0];

    // Mercaderistas activos
    var mercQuery = _client
        .from('users')
        .select('id, full_name')
        .eq('role', 'mercaderista')
        .eq('status', 'active');
    if (sede != null) mercQuery = mercQuery.eq('sede', sede);
    final List<dynamic> mercData = await mercQuery;

    // Todas las rutas del rango
    var routesQuery = _client
        .from('routes')
        .select('id, mercaderista_id, status, total_clients, completed_clients')
        .gte('scheduled_date', fromStr)
        .lte('scheduled_date', toStr);
    if (sede != null) routesQuery = routesQuery.eq('sede_app', sede);
    final List<dynamic> routesData = await routesQuery;

    // Visitas del rango (para contar clientes únicos)
    var visitsQuery = _client
        .from('route_visits')
        .select('mercaderista_id, client_co_cli')
        .gte('visited_at', from.toIso8601String())
        .lte('visited_at', to.toIso8601String());
    final List<dynamic> visitsData = await visitsQuery;

    final result = <MercaderistaPerformance>[];

    for (final merc in mercData) {
      final mercId = merc['id'] as String;
      final mercName = merc['full_name'] as String? ?? 'Sin nombre';

      final mercRoutes = routesData.where((r) => r['mercaderista_id'] == mercId);
      final assigned = mercRoutes.length;
      final completed = mercRoutes.where((r) => r['status'] == 'completed').length;

      final mercVisits = visitsData.where((v) => v['mercaderista_id'] == mercId);
      final clientsVisited = mercVisits
          .map((v) => v['client_co_cli'] as String?)
          .where((c) => c != null)
          .toSet()
          .length;

      result.add(MercaderistaPerformance(
        id: mercId,
        name: mercName,
        routesAssigned: assigned,
        routesCompleted: completed,
        clientsVisited: clientsVisited,
        completionRate: assigned > 0 ? completed / assigned : 0,
      ));
    }

    result.sort((a, b) => b.completionRate.compareTo(a.completionRate));
    return result;
  }

  /// Cobertura de clientes
  Future<ClientCoverageStats> getClientCoverage({String? sede}) async {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7)).toIso8601String();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30)).toIso8601String();

    // Total activos
    var totalQuery = _client
        .from('clients')
        .select('co_cli, last_visit_at, sede_app')
        .eq('inactivo', false);
    if (sede != null) totalQuery = totalQuery.eq('sede_app', sede);
    final List<dynamic> allClients = await totalQuery;

    final totalActive = allClients.length;
    int visitedLast7 = 0;
    int visitedLast30 = 0;
    int neverVisited = 0;

    // Agrupar por sede
    final Map<String, List<dynamic>> clientsBySede = {};

    for (final c in allClients) {
      final lastVisit = c['last_visit_at'] as String?;
      final clientSede = c['sede_app'] as String? ?? 'Sin sede';

      clientsBySede.putIfAbsent(clientSede, () => []).add(c);

      if (lastVisit == null) {
        neverVisited++;
      } else {
        if (lastVisit.compareTo(sevenDaysAgo) >= 0) visitedLast7++;
        if (lastVisit.compareTo(thirtyDaysAgo) >= 0) visitedLast30++;
      }
    }

    // Cobertura por sede
    final sedeCoverage = <SedeCoverage>[];
    for (final entry in clientsBySede.entries) {
      final visited = entry.value
          .where((c) => c['last_visit_at'] != null &&
              (c['last_visit_at'] as String).compareTo(thirtyDaysAgo) >= 0)
          .length;
      sedeCoverage.add(SedeCoverage(
        sede: entry.key,
        totalClients: entry.value.length,
        visitedClients: visited,
      ));
    }
    sedeCoverage.sort((a, b) => b.totalClients.compareTo(a.totalClients));

    return ClientCoverageStats(
      totalActive: totalActive,
      visitedLast7Days: visitedLast7,
      visitedLast30Days: visitedLast30,
      neverVisited: neverVisited,
      bySede: sedeCoverage,
    );
  }

  /// Clientes sin visitar (>N días)
  Future<List<UnvisitedClient>> getUnvisitedClients({
    int days = 30,
    String? sede,
    int limit = 50,
  }) async {
    final cutoff = DateTime.now().subtract(Duration(days: days)).toIso8601String();

    // Clientes nunca visitados
    var neverQuery = _client
        .from('clients')
        .select('co_cli, cli_des, sede_app, last_visit_at')
        .eq('inactivo', false)
        .isFilter('last_visit_at', null)
        .limit(limit);
    if (sede != null) neverQuery = neverQuery.eq('sede_app', sede);
    final List<dynamic> neverData = await neverQuery;

    // Clientes con visita antigua
    var oldQuery = _client
        .from('clients')
        .select('co_cli, cli_des, sede_app, last_visit_at')
        .eq('inactivo', false)
        .not('last_visit_at', 'is', null)
        .lt('last_visit_at', cutoff)
        .order('last_visit_at', ascending: true)
        .limit(limit);
    if (sede != null) oldQuery = oldQuery.eq('sede_app', sede);
    final List<dynamic> oldData = await oldQuery;

    final now = DateTime.now();
    final result = <UnvisitedClient>[];

    for (final c in neverData) {
      result.add(UnvisitedClient(
        coCli: c['co_cli'] as String,
        name: c['cli_des'] as String? ?? 'Sin nombre',
        sede: c['sede_app'] as String? ?? 'Sin sede',
        lastVisitAt: null,
        daysSinceVisit: 9999,
      ));
    }

    for (final c in oldData) {
      final lastVisit = DateTime.parse(c['last_visit_at'] as String);
      result.add(UnvisitedClient(
        coCli: c['co_cli'] as String,
        name: c['cli_des'] as String? ?? 'Sin nombre',
        sede: c['sede_app'] as String? ?? 'Sin sede',
        lastVisitAt: lastVisit,
        daysSinceVisit: now.difference(lastVisit).inDays,
      ));
    }

    result.sort((a, b) => b.daysSinceVisit.compareTo(a.daysSinceVisit));
    return result.take(limit).toList();
  }

  /// Distribución de rutas por tipo y estado
  Future<RouteTypeBreakdown> getRouteBreakdown({
    required DateTime from,
    required DateTime to,
    String? sede,
  }) async {
    final fromStr = from.toIso8601String().split('T')[0];
    final toStr = to.toIso8601String().split('T')[0];

    // Rutas con tipo
    var routesQuery = _client
        .from('routes')
        .select('id, status, route_type_id, route_types(name, color)')
        .gte('scheduled_date', fromStr)
        .lte('scheduled_date', toStr);
    if (sede != null) routesQuery = routesQuery.eq('sede_app', sede);
    final List<dynamic> routesData = await routesQuery;

    // Agrupar por tipo
    final Map<String, Map<String, dynamic>> typeMap = {};
    for (final r in routesData) {
      final typeData = r['route_types'] as Map<String, dynamic>?;
      final typeName = typeData?['name'] as String? ?? 'Sin tipo';
      final typeColor = typeData?['color'] as String? ?? '#9E9E9E';
      final status = r['status'] as String;

      typeMap.putIfAbsent(typeName, () => {
        'color': typeColor,
        'total': 0,
        'completed': 0,
        'cancelled': 0,
      });

      typeMap[typeName]!['total'] = (typeMap[typeName]!['total'] as int) + 1;
      if (status == 'completed') {
        typeMap[typeName]!['completed'] = (typeMap[typeName]!['completed'] as int) + 1;
      }
      if (status == 'cancelled') {
        typeMap[typeName]!['cancelled'] = (typeMap[typeName]!['cancelled'] as int) + 1;
      }
    }

    final byType = typeMap.entries.map((e) => RouteTypeStat(
      typeName: e.key,
      color: e.value['color'] as String,
      total: e.value['total'] as int,
      completed: e.value['completed'] as int,
      cancelled: e.value['cancelled'] as int,
    )).toList();

    byType.sort((a, b) => b.total.compareTo(a.total));
    return RouteTypeBreakdown(byType: byType);
  }

  /// Historial de rutas con detalle
  Future<List<RouteHistoryItem>> getRouteHistory({
    required DateTime from,
    required DateTime to,
    String? sede,
    String? routeTypeId,
  }) async {
    final fromStr = from.toIso8601String().split('T')[0];
    final toStr = to.toIso8601String().split('T')[0];

    var query = _client
        .from('routes')
        .select('id, name, status, scheduled_date, total_clients, completed_clients, mercaderista_id, users(full_name), route_types(name, color)')
        .gte('scheduled_date', fromStr)
        .lte('scheduled_date', toStr)
        .order('scheduled_date', ascending: false);
    if (sede != null) query = query.eq('sede_app', sede);
    if (routeTypeId != null) query = query.eq('route_type_id', routeTypeId);
    final List<dynamic> data = await query;

    return data.map((r) {
      final userData = r['users'] as Map<String, dynamic>?;
      final typeData = r['route_types'] as Map<String, dynamic>?;

      return RouteHistoryItem(
        id: r['id'] as String,
        name: r['name'] as String? ?? 'Sin nombre',
        mercaderistaName: userData?['full_name'] as String? ?? 'Sin asignar',
        routeTypeName: typeData?['name'] as String? ?? 'Sin tipo',
        routeTypeColor: typeData?['color'] as String? ?? '#9E9E9E',
        status: r['status'] as String,
        scheduledDate: DateTime.parse(r['scheduled_date'] as String),
        totalClients: (r['total_clients'] as int?) ?? 0,
        completedClients: (r['completed_clients'] as int?) ?? 0,
      );
    }).toList();
  }

  /// Estadísticas de eventos
  Future<EventsStats> getEventsStats({
    required DateTime from,
    required DateTime to,
  }) async {
    final fromStr = from.toIso8601String().split('T')[0];
    final toStr = to.toIso8601String().split('T')[0];

    // Eventos en rango
    final List<dynamic> eventsData = await _client
        .from('events')
        .select('id, name, start_date, end_date, status')
        .gte('start_date', fromStr)
        .lte('start_date', toStr)
        .order('start_date', ascending: false);

    final eventIds = eventsData.map((e) => e['id'] as String).toList();

    if (eventIds.isEmpty) {
      return const EventsStats();
    }

    // Mercaderistas asignados
    final List<dynamic> assignedData = await _client
        .from('event_mercaderistas')
        .select('event_id, mercaderista_id')
        .inFilter('event_id', eventIds);

    // Check-ins
    final List<dynamic> checkInsData = await _client
        .from('event_check_ins')
        .select('event_id, mercaderista_id')
        .inFilter('event_id', eventIds);

    // Agrupar por evento
    final Map<String, int> assignedByEvent = {};
    for (final a in assignedData) {
      final eid = a['event_id'] as String;
      assignedByEvent[eid] = (assignedByEvent[eid] ?? 0) + 1;
    }

    final Map<String, int> checkInsByEvent = {};
    for (final ci in checkInsData) {
      final eid = ci['event_id'] as String;
      checkInsByEvent[eid] = (checkInsByEvent[eid] ?? 0) + 1;
    }

    final totalAssigned = assignedData.length;
    final totalCheckIns = checkInsData.length;

    final events = eventsData.map((e) {
      final eid = e['id'] as String;
      return EventReportDetail(
        id: eid,
        name: e['name'] as String,
        startDate: DateTime.parse(e['start_date'] as String),
        endDate: DateTime.parse(e['end_date'] as String),
        assignedCount: assignedByEvent[eid] ?? 0,
        checkInCount: checkInsByEvent[eid] ?? 0,
        status: e['status'] as String? ?? 'planned',
      );
    }).toList();

    return EventsStats(
      totalEvents: eventsData.length,
      totalCheckIns: totalCheckIns,
      totalAssigned: totalAssigned,
      attendanceRate: totalAssigned > 0 ? totalCheckIns / totalAssigned : 0,
      events: events,
    );
  }
}
