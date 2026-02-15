import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/models/report_models.dart';
import '../../data/repositories/reports_repository.dart';

/// Repositorio de reportes
final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepository(Supabase.instance.client);
});

/// Filtro global de reportes
final reportsFilterProvider = StateProvider<ReportsFilter>((ref) {
  return ReportsFilter.thisMonth();
});

/// Dashboard KPIs
final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  final filter = ref.watch(reportsFilterProvider);
  final repo = ref.watch(reportsRepositoryProvider);
  return repo.getDashboardStats(from: filter.from, to: filter.to, sede: filter.sede);
});

/// Tendencia diaria
final dailyTrendsProvider = FutureProvider<List<DailyTrend>>((ref) async {
  final filter = ref.watch(reportsFilterProvider);
  final repo = ref.watch(reportsRepositoryProvider);
  return repo.getDailyTrends(from: filter.from, to: filter.to, sede: filter.sede);
});

/// Rendimiento mercaderistas
final mercaderistasPerformanceProvider =
    FutureProvider<List<MercaderistaPerformance>>((ref) async {
  final filter = ref.watch(reportsFilterProvider);
  final repo = ref.watch(reportsRepositoryProvider);
  return repo.getMercaderistasPerformance(from: filter.from, to: filter.to, sede: filter.sede);
});

/// Cobertura de clientes
final clientCoverageProvider = FutureProvider<ClientCoverageStats>((ref) async {
  final filter = ref.watch(reportsFilterProvider);
  final repo = ref.watch(reportsRepositoryProvider);
  return repo.getClientCoverage(sede: filter.sede);
});

/// Clientes sin visitar
final unvisitedClientsProvider = FutureProvider<List<UnvisitedClient>>((ref) async {
  final filter = ref.watch(reportsFilterProvider);
  final repo = ref.watch(reportsRepositoryProvider);
  return repo.getUnvisitedClients(sede: filter.sede);
});

/// Distribución de rutas por tipo
final routeBreakdownProvider = FutureProvider<RouteTypeBreakdown>((ref) async {
  final filter = ref.watch(reportsFilterProvider);
  final repo = ref.watch(reportsRepositoryProvider);
  return repo.getRouteBreakdown(from: filter.from, to: filter.to, sede: filter.sede);
});

/// Historial de rutas
final routeHistoryProvider = FutureProvider<List<RouteHistoryItem>>((ref) async {
  final filter = ref.watch(reportsFilterProvider);
  final repo = ref.watch(reportsRepositoryProvider);
  return repo.getRouteHistory(from: filter.from, to: filter.to, sede: filter.sede);
});

/// Estadísticas de eventos
final eventsStatsProvider = FutureProvider<EventsStats>((ref) async {
  final filter = ref.watch(reportsFilterProvider);
  final repo = ref.watch(reportsRepositoryProvider);
  return repo.getEventsStats(from: filter.from, to: filter.to);
});
