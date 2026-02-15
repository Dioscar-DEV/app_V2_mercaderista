import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/models/report_models.dart';
import '../../data/repositories/reports_repository.dart';
import 'auth_provider.dart';

/// Repositorio de reportes
final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepository(Supabase.instance.client);
});

/// Filtro global de reportes
/// Se inicializa con la sede del usuario si es supervisor
final reportsFilterProvider = StateProvider<ReportsFilter>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  final user = userAsync.valueOrNull;

  String? sede;
  if (user != null && user.isSupervisor && user.sede != null) {
    // Supervisor: forzar su sede
    sede = user.sede!.value;
  }
  // Owner: sede null = ve todo

  return ReportsFilter.thisMonth().copyWith(sede: sede);
});

/// Si el usuario actual es owner (puede filtrar por cualquier sede)
final isOwnerProvider = Provider<bool>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  return userAsync.valueOrNull?.isOwner ?? false;
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
  return repo.getEventsStats(from: filter.from, to: filter.to, sede: filter.sede);
});

/// Respuestas de formularios
final formAnswersProvider = FutureProvider<List<FormAnswerRow>>((ref) async {
  final filter = ref.watch(reportsFilterProvider);
  final repo = ref.watch(reportsRepositoryProvider);
  return repo.getFormAnswers(from: filter.from, to: filter.to, sede: filter.sede);
});
