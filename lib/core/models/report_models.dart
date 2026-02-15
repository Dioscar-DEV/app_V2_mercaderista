/// Modelos de datos para el módulo de reportes

class ReportsFilter {
  final DateTime from;
  final DateTime to;
  final String? sede;

  const ReportsFilter({required this.from, required this.to, this.sede});

  factory ReportsFilter.today() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    return ReportsFilter(from: start, to: end);
  }

  factory ReportsFilter.last7Days() {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    final start = end.subtract(const Duration(days: 7));
    return ReportsFilter(from: start, to: end);
  }

  factory ReportsFilter.last30Days() {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    final start = end.subtract(const Duration(days: 30));
    return ReportsFilter(from: start, to: end);
  }

  factory ReportsFilter.thisMonth() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 1);
    return ReportsFilter(from: start, to: end);
  }

  ReportsFilter copyWith({DateTime? from, DateTime? to, String? sede, bool clearSede = false}) {
    return ReportsFilter(
      from: from ?? this.from,
      to: to ?? this.to,
      sede: clearSede ? null : (sede ?? this.sede),
    );
  }

  String get label {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final diff = to.difference(from).inDays;

    if (from == todayStart && diff == 1) return 'Hoy';
    if (diff == 7) return '7 días';
    if (diff == 30) return '30 días';
    if (from.day == 1 && to == DateTime(from.year, from.month + 1, 1)) {
      return 'Este mes';
    }
    return '${from.day}/${from.month} - ${to.day}/${to.month}';
  }
}

class DashboardStats {
  final int totalRoutes;
  final int completedRoutes;
  final int totalVisits;
  final int uniqueClientsVisited;
  final int totalEvents;
  final int totalCheckIns;
  final double completionRate;
  final double avgClientsPerRoute;

  const DashboardStats({
    this.totalRoutes = 0,
    this.completedRoutes = 0,
    this.totalVisits = 0,
    this.uniqueClientsVisited = 0,
    this.totalEvents = 0,
    this.totalCheckIns = 0,
    this.completionRate = 0,
    this.avgClientsPerRoute = 0,
  });
}

class DailyTrend {
  final DateTime date;
  final int routesCompleted;
  final int visitsCompleted;

  const DailyTrend({
    required this.date,
    this.routesCompleted = 0,
    this.visitsCompleted = 0,
  });
}

class MercaderistaPerformance {
  final String id;
  final String name;
  final int routesAssigned;
  final int routesCompleted;
  final int clientsVisited;
  final double completionRate;

  const MercaderistaPerformance({
    required this.id,
    required this.name,
    this.routesAssigned = 0,
    this.routesCompleted = 0,
    this.clientsVisited = 0,
    this.completionRate = 0,
  });
}

class ClientCoverageStats {
  final int totalActive;
  final int visitedLast7Days;
  final int visitedLast30Days;
  final int neverVisited;
  final List<SedeCoverage> bySede;

  const ClientCoverageStats({
    this.totalActive = 0,
    this.visitedLast7Days = 0,
    this.visitedLast30Days = 0,
    this.neverVisited = 0,
    this.bySede = const [],
  });
}

class SedeCoverage {
  final String sede;
  final int totalClients;
  final int visitedClients;

  const SedeCoverage({
    required this.sede,
    this.totalClients = 0,
    this.visitedClients = 0,
  });

  double get coverageRate =>
      totalClients > 0 ? visitedClients / totalClients : 0;
}

class UnvisitedClient {
  final String coCli;
  final String name;
  final String sede;
  final DateTime? lastVisitAt;
  final int daysSinceVisit;

  const UnvisitedClient({
    required this.coCli,
    required this.name,
    required this.sede,
    this.lastVisitAt,
    this.daysSinceVisit = 0,
  });
}

class RouteTypeBreakdown {
  final List<RouteTypeStat> byType;

  const RouteTypeBreakdown({this.byType = const []});
}

class RouteTypeStat {
  final String typeName;
  final String color;
  final int total;
  final int completed;
  final int cancelled;

  const RouteTypeStat({
    required this.typeName,
    required this.color,
    this.total = 0,
    this.completed = 0,
    this.cancelled = 0,
  });

  double get completionRate => total > 0 ? completed / total : 0;
}

class RouteHistoryItem {
  final String id;
  final String name;
  final String mercaderistaName;
  final String routeTypeName;
  final String routeTypeColor;
  final String status;
  final DateTime scheduledDate;
  final int totalClients;
  final int completedClients;

  const RouteHistoryItem({
    required this.id,
    required this.name,
    required this.mercaderistaName,
    required this.routeTypeName,
    required this.routeTypeColor,
    required this.status,
    required this.scheduledDate,
    this.totalClients = 0,
    this.completedClients = 0,
  });

  double get completionRate =>
      totalClients > 0 ? completedClients / totalClients : 0;
}

class EventsStats {
  final int totalEvents;
  final int totalCheckIns;
  final int totalAssigned;
  final double attendanceRate;
  final List<EventReportDetail> events;

  const EventsStats({
    this.totalEvents = 0,
    this.totalCheckIns = 0,
    this.totalAssigned = 0,
    this.attendanceRate = 0,
    this.events = const [],
  });
}

class EventReportDetail {
  final String id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final int assignedCount;
  final int checkInCount;
  final String status;

  const EventReportDetail({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    this.assignedCount = 0,
    this.checkInCount = 0,
    this.status = 'planned',
  });

  double get attendanceRate =>
      assignedCount > 0 ? checkInCount / assignedCount : 0;
}
