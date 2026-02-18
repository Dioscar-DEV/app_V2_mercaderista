import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/route.dart';
import '../../core/models/route_type.dart';
import '../../core/models/route_form_question.dart';
import '../../core/models/route_template.dart';
import '../../core/models/route_visit.dart';
import '../../core/enums/route_status.dart';
import '../../data/repositories/route_repository.dart';
import '../../data/repositories/offline_first_route_repository.dart';
import 'auth_provider.dart';

/// Provider del repositorio de rutas (online)
final routeRepositoryProvider = Provider<RouteRepository>((ref) {
  return RouteRepository();
});

/// Provider del repositorio offline-first
final offlineFirstRouteRepositoryProvider = Provider<OfflineFirstRouteRepository>((ref) {
  final repository = OfflineFirstRouteRepository();
  repository.startMonitoring();
  ref.onDispose(() => repository.stopMonitoring());
  return repository;
});

/// Provider de filtros de rutas
final routeFiltersProvider = StateProvider<RouteFilters>((ref) {
  return const RouteFilters();
});

/// Provider de la fecha seleccionada en el calendario
final selectedDateProvider = StateProvider<DateTime>((ref) {
  return DateTime.now();
});

/// Provider de la semana seleccionada en el calendario
final selectedWeekStartProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  // Obtener el lunes de la semana actual
  return now.subtract(Duration(days: now.weekday - 1));
});

/// Provider de rutas con filtros aplicados
final routesProvider = FutureProvider<List<AppRoute>>((ref) async {
  final repository = ref.watch(routeRepositoryProvider);
  final filters = ref.watch(routeFiltersProvider);
  final currentUser = await ref.watch(currentUserProvider.future);
  
  if (currentUser == null) {
    throw Exception('Usuario no autenticado');
  }
  
  return repository.getRoutes(
    requestingUser: currentUser,
    filters: filters,
  );
});

/// Provider de rutas para la fecha seleccionada
final routesForSelectedDateProvider = FutureProvider<List<AppRoute>>((ref) async {
  final repository = ref.watch(routeRepositoryProvider);
  final selectedDate = ref.watch(selectedDateProvider);
  final currentUser = await ref.watch(currentUserProvider.future);
  
  if (currentUser == null) {
    throw Exception('Usuario no autenticado');
  }
  
  return repository.getRoutesForDate(
    requestingUser: currentUser,
    date: selectedDate,
  );
});

/// Provider de rutas para la semana seleccionada (con filtros)
final routesForWeekProvider = FutureProvider<List<AppRoute>>((ref) async {
  final repository = ref.watch(routeRepositoryProvider);
  final weekStart = ref.watch(selectedWeekStartProvider);
  final filters = ref.watch(routeFiltersProvider);
  final currentUser = await ref.watch(currentUserProvider.future);

  if (currentUser == null) {
    throw Exception('Usuario no autenticado');
  }

  return repository.getRoutesForWeek(
    requestingUser: currentUser,
    weekStart: weekStart,
    filters: filters.hasFilters ? filters : null,
  );
});

/// Provider de rutas del día actual (para mercaderista) - OFFLINE FIRST
final todayRoutesProvider = FutureProvider<List<AppRoute>>((ref) async {
  final offlineRepository = ref.watch(offlineFirstRouteRepositoryProvider);
  final currentUser = await ref.watch(currentUserProvider.future);
  
  if (currentUser == null) {
    throw Exception('Usuario no autenticado');
  }
  
  return offlineRepository.getRoutesForToday(user: currentUser);
});

/// Provider para forzar refresh de rutas de hoy
final todayRoutesRefreshProvider = FutureProvider.family<List<AppRoute>, bool>((ref, forceRefresh) async {
  final offlineRepository = ref.watch(offlineFirstRouteRepositoryProvider);
  final currentUser = await ref.watch(currentUserProvider.future);
  
  if (currentUser == null) {
    throw Exception('Usuario no autenticado');
  }
  
  return offlineRepository.getRoutesForToday(user: currentUser, forceRefresh: forceRefresh);
});

/// Provider de una ruta específica por ID
final routeByIdProvider = FutureProvider.family<AppRoute?, String>((ref, id) async {
  final repository = ref.watch(routeRepositoryProvider);
  return repository.getRouteById(id);
});

/// Provider de tipos de ruta
final routeTypesProvider = FutureProvider<List<RouteType>>((ref) async {
  final repository = ref.watch(routeRepositoryProvider);
  return repository.getRouteTypes();
});

/// Provider de preguntas del formulario por tipo de ruta
final formQuestionsProvider = FutureProvider.family<List<RouteFormQuestion>, String>((ref, routeTypeId) async {
  final repository = ref.watch(routeRepositoryProvider);
  return repository.getFormQuestions(routeTypeId);
});

/// Provider de plantillas
final templatesProvider = FutureProvider<List<RouteTemplate>>((ref) async {
  final repository = ref.watch(routeRepositoryProvider);
  final currentUser = await ref.watch(currentUserProvider.future);
  
  if (currentUser == null) {
    throw Exception('Usuario no autenticado');
  }
  
  return repository.getTemplates(requestingUser: currentUser);
});

/// Provider de la ruta activa del mercaderista (la que está ejecutando)
final activeRouteProvider = StateProvider<AppRoute?>((ref) {
  return null;
});

/// Provider del índice del cliente actual en la ruta activa
final currentRouteClientIndexProvider = StateProvider<int>((ref) {
  return 0;
});

/// Estado de la ejecución de ruta (para mercaderista)
class RouteExecutionState {
  final AppRoute? route;
  final List<RouteFormQuestion> questions;
  final int currentClientIndex;
  final bool isLoading;
  final String? error;
  final bool isOfflineMode;
  final List<RouteVisit> pendingVisits; // Visitas pendientes de sincronizar

  const RouteExecutionState({
    this.route,
    this.questions = const [],
    this.currentClientIndex = 0,
    this.isLoading = false,
    this.error,
    this.isOfflineMode = false,
    this.pendingVisits = const [],
  });

  RouteExecutionState copyWith({
    AppRoute? route,
    List<RouteFormQuestion>? questions,
    int? currentClientIndex,
    bool? isLoading,
    String? error,
    bool? isOfflineMode,
    List<RouteVisit>? pendingVisits,
  }) {
    return RouteExecutionState(
      route: route ?? this.route,
      questions: questions ?? this.questions,
      currentClientIndex: currentClientIndex ?? this.currentClientIndex,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isOfflineMode: isOfflineMode ?? this.isOfflineMode,
      pendingVisits: pendingVisits ?? this.pendingVisits,
    );
  }

  RouteClient? get currentClient {
    if (route?.clients == null || route!.clients!.isEmpty) return null;
    if (currentClientIndex >= route!.clients!.length) return null;
    return route!.clients![currentClientIndex];
  }

  bool get hasNextClient {
    if (route?.clients == null) return false;
    return currentClientIndex < route!.clients!.length - 1;
  }

  bool get hasPreviousClient {
    return currentClientIndex > 0;
  }

  int get totalClients => route?.clients?.length ?? 0;
  int get completedClients => route?.clients?.where((c) => c.isCompleted).length ?? 0;
}

/// Notifier para la ejecución de rutas (OFFLINE-FIRST)
class RouteExecutionNotifier extends StateNotifier<RouteExecutionState> {
  final OfflineFirstRouteRepository _offlineRepository;
  final RouteRepository _onlineRepository;

  RouteExecutionNotifier(this._offlineRepository, this._onlineRepository) : super(const RouteExecutionState());

  /// Carga una ruta para ejecución - OFFLINE FIRST
  /// 1. Busca en BD local primero
  /// 2. Si no existe local, intenta desde servidor (silencioso)
  Future<void> loadRoute(String routeId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // 1. Primero intentar desde BD local
      final localRoute = await _offlineRepository.getRouteById(routeId);
      
      if (localRoute != null) {
        // Cargar preguntas del formulario desde local
        List<RouteFormQuestion> questions = [];
        if (localRoute.routeTypeId != null) {
          questions = await _offlineRepository.getFormQuestions(localRoute.routeTypeId!);
        }
        
        // Tenemos datos locales - mostrar inmediatamente
        state = state.copyWith(
          route: localRoute,
          questions: questions,
          currentClientIndex: _findFirstPendingClientIndex(localRoute),
          isLoading: false,
          isOfflineMode: !_offlineRepository.isOnline,
        );
        
        // Si hay conexión, intentar actualizar en background (silencioso)
        if (_offlineRepository.isOnline) {
          _syncRouteInBackground(routeId);
        }
        return;
      }

      // 2. No hay datos locales - intentar desde servidor
      if (_offlineRepository.isOnline) {
        try {
          final data = await _onlineRepository.getRouteForOffline(routeId);
          final route = data['route'] as AppRoute;
          final questions = data['questions'] as List<RouteFormQuestion>;

          // Guardar en local para uso futuro
          await _offlineRepository.downloadRouteForOffline(routeId);

          state = state.copyWith(
            route: route,
            questions: questions,
            currentClientIndex: _findFirstPendingClientIndex(route),
            isLoading: false,
            isOfflineMode: false,
          );
        } catch (e) {
          // Error de conexión - modo offline sin datos
          state = state.copyWith(
            isLoading: false,
            error: 'Sin conexión y no hay datos offline. Descarga la ruta mientras tengas internet.',
            isOfflineMode: true,
          );
        }
      } else {
        // Sin conexión y sin datos locales
        state = state.copyWith(
          isLoading: false,
          error: 'Sin conexión y no hay datos offline. Descarga la ruta mientras tengas internet.',
          isOfflineMode: true,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Error al cargar la ruta: $e',
      );
    }
  }

  /// Sincroniza ruta en background (silencioso)
  Future<void> _syncRouteInBackground(String routeId) async {
    try {
      final data = await _onlineRepository.getRouteForOffline(routeId);
      final route = data['route'] as AppRoute;
      final questions = data['questions'] as List<RouteFormQuestion>;
      
      // Actualizar estado con datos frescos
      if (mounted) {
        state = state.copyWith(
          route: route,
          questions: questions,
        );
      }
    } catch (_) {
      // Silencioso - ya tenemos datos locales
    }
  }

  int _findFirstPendingClientIndex(AppRoute route) {
    if (route.clients == null || route.clients!.isEmpty) return 0;
    
    for (int i = 0; i < route.clients!.length; i++) {
      if (route.clients![i].isPending || route.clients![i].isInProgress) {
        return i;
      }
    }
    return 0;
  }

  /// Inicia la ruta - OFFLINE FIRST
  Future<void> startRoute() async {
    if (state.route == null) return;

    try {
      final updatedRoute = await _offlineRepository.startRoute(state.route!.id);
      if (updatedRoute != null) {
        state = state.copyWith(route: updatedRoute);
      }
    } catch (e) {
      // Silencioso en modo offline
      if (!state.isOfflineMode) {
        state = state.copyWith(error: 'Error al iniciar la ruta: $e');
      }
    }
  }

  /// Inicia visita al cliente actual - OFFLINE FIRST
  Future<void> startCurrentClientVisit({
    required double latitude,
    required double longitude,
  }) async {
    final currentClient = state.currentClient;
    if (currentClient == null) return;

    try {
      await _offlineRepository.startClientVisit(
        routeClientId: currentClient.id,
        latitude: latitude,
        longitude: longitude,
      );

      // Actualizar estado local inmediatamente
      final updatedClient = currentClient.copyWith(
        status: RouteClientStatus.inProgress,
        startedAt: DateTime.now(),
        latitudeStart: latitude,
        longitudeStart: longitude,
      );
      _updateClientInRoute(updatedClient);
    } catch (e) {
      if (!state.isOfflineMode) {
        state = state.copyWith(error: 'Error al iniciar visita: $e');
      }
    }
  }

  /// Completa visita al cliente actual - OFFLINE FIRST
  Future<void> completeCurrentClientVisit({
    required double latitude,
    required double longitude,
    required List<RouteVisitAnswer> answers,
    List<String>? photoUrls,
    String? observations,
    String? mercaderistaId,
  }) async {
    final currentClient = state.currentClient;
    if (currentClient == null) return;

    try {
      await _offlineRepository.completeClientVisit(
        routeClientId: currentClient.id,
        latitude: latitude,
        longitude: longitude,
      );

      // Actualizar estado local inmediatamente
      final updatedClient = currentClient.copyWith(
        status: RouteClientStatus.completed,
        completedAt: DateTime.now(),
        latitudeEnd: latitude,
        longitudeEnd: longitude,
      );
      _updateClientInRoute(updatedClient);

      // Actualizar cliente: coordenadas GPS + last_visit_at (offline-first)
      try {
        await _offlineRepository.updateClientAfterVisit(
          clientCoCli: currentClient.clientId,
          latitude: latitude,
          longitude: longitude,
        );
      } catch (_) {
        // Silencioso - no bloquear el flujo por esto
      }

      // Construir la visita con campos correctos para Supabase
      final visit = RouteVisit(
        id: '',
        routeClientId: currentClient.id,
        routeId: state.route?.id,
        clientCoCli: currentClient.clientId,
        mercaderistaId: mercaderistaId ?? state.route?.mercaderistaId,
        visitedAt: DateTime.now(),
        latitude: latitude != 0.0 ? latitude : null,
        longitude: longitude != 0.0 ? longitude : null,
        photos: photoUrls,
        notes: observations,
        createdAt: DateTime.now(),
      );

      // Si hay conexión, crear la visita en el servidor
      if (_offlineRepository.isOnline) {
        try {
          await _onlineRepository.createVisit(visit: visit, answers: answers);
        } catch (e) {
          // Guardar como pendiente para sincronizar después
          addPendingVisit(visit.copyWith(answers: answers));
        }
      } else {
        // Sin conexión: guardar para sincronizar después
        addPendingVisit(visit.copyWith(answers: answers));
      }

      // Avanzar al siguiente cliente si hay
      if (state.hasNextClient) {
        nextClient();
      }
    } catch (e) {
      if (!state.isOfflineMode) {
        state = state.copyWith(error: 'Error al completar visita: $e');
      }
    }
  }

  /// Omite el cliente actual - OFFLINE FIRST
  Future<void> skipCurrentClient() async {
    final currentClient = state.currentClient;
    if (currentClient == null) return;

    try {
      // Persistir en SQLite (funciona offline)
      await _offlineRepository.skipClientVisit(
        routeClientId: currentClient.id,
      );

      // Actualizar estado en memoria
      final updatedClient = currentClient.copyWith(
        status: RouteClientStatus.skipped,
        completedAt: DateTime.now(),
      );
      _updateClientInRoute(updatedClient);

      if (state.hasNextClient) {
        nextClient();
      }
    } catch (e) {
      if (!state.isOfflineMode) {
        state = state.copyWith(error: 'Error al omitir cliente: $e');
      }
    }
  }

  /// Marca el cliente actual como cerrado temporalmente - OFFLINE FIRST
  Future<void> markCurrentClientClosedTemp({String? reason}) async {
    final currentClient = state.currentClient;
    if (currentClient == null) return;

    try {
      // Persistir en SQLite (funciona offline)
      await _offlineRepository.markClientClosedTemp(
        routeClientId: currentClient.id,
        reason: reason,
      );

      // Actualizar estado en memoria
      final updatedClient = currentClient.copyWith(
        status: RouteClientStatus.closedTemp,
        closureReason: reason,
        completedAt: DateTime.now(),
      );
      _updateClientInRoute(updatedClient);

      if (state.hasNextClient) {
        nextClient();
      }
    } catch (e) {
      if (!state.isOfflineMode) {
        state = state.copyWith(error: 'Error al marcar cliente como cerrado: $e');
      }
    }
  }

  /// Marca un cliente como cerrado permanentemente
  Future<void> markClientPermanentlyClosed({
    required String clientCoCli,
    required String reason,
  }) async {
    try {
      if (_offlineRepository.isOnline) {
        await _onlineRepository.markClientPermanentlyClosed(
          clientCoCli: clientCoCli,
          reason: reason,
        );
      }
    } catch (e) {
      state = state.copyWith(error: 'Error al marcar cierre permanente: $e');
    }
  }

  /// Cancela la ruta con motivo obligatorio
  Future<void> cancelRoute({required String reason}) async {
    if (state.route == null) return;

    try {
      if (_offlineRepository.isOnline) {
        await _onlineRepository.cancelRoute(
          routeId: state.route!.id,
          reason: reason,
        );
      }

      final updatedRoute = state.route!.copyWith(
        status: RouteStatus.cancelled,
        cancellationReason: reason,
      );
      state = state.copyWith(route: updatedRoute);
    } catch (e) {
      state = state.copyWith(error: 'Error al cancelar la ruta: $e');
    }
  }

  void _updateClientInRoute(RouteClient updatedClient) {
    if (state.route?.clients == null) return;

    final updatedClients = state.route!.clients!.map((c) {
      return c.id == updatedClient.id ? updatedClient : c;
    }).toList();

    final updatedRoute = state.route!.copyWith(
      clients: updatedClients,
      completedClients: updatedClients.where((c) => c.isCompleted).length,
    );

    state = state.copyWith(route: updatedRoute);
  }

  /// Avanza al siguiente cliente
  void nextClient() {
    if (state.hasNextClient) {
      state = state.copyWith(currentClientIndex: state.currentClientIndex + 1);
    }
  }

  /// Retrocede al cliente anterior
  void previousClient() {
    if (state.hasPreviousClient) {
      state = state.copyWith(currentClientIndex: state.currentClientIndex - 1);
    }
  }

  /// Va a un cliente específico por índice
  void goToClient(int index) {
    if (index >= 0 && index < state.totalClients) {
      state = state.copyWith(currentClientIndex: index);
    }
  }

  /// Completa la ruta - OFFLINE FIRST
  Future<void> completeRoute() async {
    if (state.route == null) return;

    try {
      final updatedRoute = await _offlineRepository.completeRoute(state.route!.id);
      if (updatedRoute != null) {
        state = state.copyWith(route: updatedRoute);
      }
    } catch (e) {
      if (!state.isOfflineMode) {
        state = state.copyWith(error: 'Error al completar la ruta: $e');
      }
    }
  }

  /// Activa/desactiva modo offline
  void setOfflineMode(bool isOffline) {
    state = state.copyWith(isOfflineMode: isOffline);
  }

  /// Agrega una visita pendiente (para sincronizar después)
  void addPendingVisit(RouteVisit visit) {
    state = state.copyWith(
      pendingVisits: [...state.pendingVisits, visit],
    );
  }

  /// Sincroniza visitas pendientes y cambios de estado offline
  Future<void> syncPendingVisits() async {
    // 1. Sincronizar cambios de estado de clientes (skip, closed_temp, etc.)
    try {
      await _offlineRepository.syncPendingChanges();
    } catch (_) {
      // Silencioso
    }

    // 2. Sincronizar visitas pendientes (formularios)
    if (state.pendingVisits.isEmpty) return;

    try {
      await _onlineRepository.syncPendingVisits(state.pendingVisits);
      state = state.copyWith(pendingVisits: []);
    } catch (e) {
      // Silencioso
    }
  }

  /// Limpia el estado
  void clear() {
    state = const RouteExecutionState();
  }
}

/// Provider del notifier de ejecución de rutas - OFFLINE FIRST
final routeExecutionProvider =
    StateNotifierProvider<RouteExecutionNotifier, RouteExecutionState>((ref) {
  final offlineRepository = ref.watch(offlineFirstRouteRepositoryProvider);
  final onlineRepository = ref.watch(routeRepositoryProvider);
  return RouteExecutionNotifier(offlineRepository, onlineRepository);
});

/// Provider de rutas del día anterior con clientes pendientes
final yesterdayPendingRoutesProvider = FutureProvider.autoDispose<List<AppRoute>>((ref) async {
  final currentUser = ref.watch(currentUserProvider).valueOrNull;
  if (currentUser == null) return [];

  final repository = ref.watch(routeRepositoryProvider);
  return repository.getYesterdayPendingRoutes(currentUser.id);
});

/// Estado para creación/edición de rutas
class RouteFormState {
  final String name;
  final DateTime scheduledDate;
  final String? mercaderistaId;
  final String? routeTypeId;
  final String? templateId;
  final List<String> selectedClientIds;
  final String? notes;
  final bool isLoading;
  final String? error;

  const RouteFormState({
    this.name = '',
    required this.scheduledDate,
    this.mercaderistaId,
    this.routeTypeId,
    this.templateId,
    this.selectedClientIds = const [],
    this.notes,
    this.isLoading = false,
    this.error,
  });

  RouteFormState copyWith({
    String? name,
    DateTime? scheduledDate,
    String? mercaderistaId,
    String? routeTypeId,
    String? templateId,
    List<String>? selectedClientIds,
    String? notes,
    bool? isLoading,
    String? error,
  }) {
    return RouteFormState(
      name: name ?? this.name,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      mercaderistaId: mercaderistaId ?? this.mercaderistaId,
      routeTypeId: routeTypeId ?? this.routeTypeId,
      templateId: templateId ?? this.templateId,
      selectedClientIds: selectedClientIds ?? this.selectedClientIds,
      notes: notes ?? this.notes,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  bool get isValid =>
      name.isNotEmpty &&
      mercaderistaId != null &&
      selectedClientIds.isNotEmpty;
}

/// Notifier para el formulario de rutas
class RouteFormNotifier extends StateNotifier<RouteFormState> {
  final RouteRepository _repository;

  RouteFormNotifier(this._repository)
      : super(RouteFormState(scheduledDate: DateTime.now()));

  void setName(String name) {
    state = state.copyWith(name: name);
  }

  void setScheduledDate(DateTime date) {
    state = state.copyWith(scheduledDate: date);
  }

  void setMercaderistaId(String? mercaderistaId) {
    state = state.copyWith(mercaderistaId: mercaderistaId);
  }

  void setRouteTypeId(String? routeTypeId) {
    state = state.copyWith(routeTypeId: routeTypeId);
  }

  void setTemplateId(String? templateId) {
    state = state.copyWith(templateId: templateId);
  }

  void setNotes(String? notes) {
    state = state.copyWith(notes: notes);
  }

  void addClient(String clientId) {
    if (!state.selectedClientIds.contains(clientId)) {
      state = state.copyWith(
        selectedClientIds: [...state.selectedClientIds, clientId],
      );
    }
  }

  void removeClient(String clientId) {
    state = state.copyWith(
      selectedClientIds: state.selectedClientIds.where((id) => id != clientId).toList(),
    );
  }

  void setClients(List<String> clientIds) {
    state = state.copyWith(selectedClientIds: clientIds);
  }

  void reorderClients(int oldIndex, int newIndex) {
    final clients = [...state.selectedClientIds];
    if (newIndex > oldIndex) newIndex--;
    final item = clients.removeAt(oldIndex);
    clients.insert(newIndex, item);
    state = state.copyWith(selectedClientIds: clients);
  }

  Future<AppRoute?> createRoute({
    required String sedeApp,
    required String createdBy,
  }) async {
    if (!state.isValid) {
      state = state.copyWith(error: 'Por favor complete todos los campos requeridos');
      return null;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final route = AppRoute(
        id: '',
        mercaderistaId: state.mercaderistaId!,
        name: state.name,
        scheduledDate: state.scheduledDate,
        status: RouteStatus.planned,
        totalClients: state.selectedClientIds.length,
        createdAt: DateTime.now(),
        sedeApp: sedeApp,
        routeTypeId: state.routeTypeId,
        notes: state.notes,
        createdBy: createdBy,
        templateId: state.templateId,
      );

      final createdRoute = await _repository.createRoute(route);

      // Agregar clientes a la ruta
      if (state.selectedClientIds.isNotEmpty) {
        await _repository.addClientsToRoute(
          routeId: createdRoute.id,
          clientIds: state.selectedClientIds,
        );
      }

      state = state.copyWith(isLoading: false);
      return createdRoute;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Error al crear la ruta: $e',
      );
      return null;
    }
  }

  Future<AppRoute?> createRouteFromTemplate({
    required String templateId,
    required String sedeApp,
    required String createdBy,
  }) async {
    if (state.mercaderistaId == null) {
      state = state.copyWith(error: 'Seleccione un mercaderista');
      return null;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final route = await _repository.createRouteFromTemplate(
        templateId: templateId,
        mercaderistaId: state.mercaderistaId!,
        scheduledDate: state.scheduledDate,
        routeTypeId: state.routeTypeId,
        sedeApp: sedeApp,
        createdBy: createdBy,
      );

      state = state.copyWith(isLoading: false);
      return route;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Error al crear la ruta desde plantilla: $e',
      );
      return null;
    }
  }

  void clear() {
    state = RouteFormState(scheduledDate: DateTime.now());
  }

  void loadFromRoute(AppRoute route) {
    state = RouteFormState(
      name: route.name,
      scheduledDate: route.scheduledDate,
      mercaderistaId: route.mercaderistaId,
      routeTypeId: route.routeTypeId,
      templateId: route.templateId,
      selectedClientIds: route.clients?.map((c) => c.clientId).toList() ?? [],
      notes: route.notes,
    );
  }
}

/// Provider del notifier del formulario de rutas
final routeFormProvider =
    StateNotifierProvider<RouteFormNotifier, RouteFormState>((ref) {
  final repository = ref.watch(routeRepositoryProvider);
  return RouteFormNotifier(repository);
});

/// Provider de estadísticas de rutas para el dashboard
final routeStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final routes = await ref.watch(routesForWeekProvider.future);
  
  final today = DateTime.now();
  final todayStr = today.toIso8601String().split('T')[0];
  
  final todayRoutes = routes.where((r) => 
    r.scheduledDate.toIso8601String().split('T')[0] == todayStr
  ).toList();

  final completedToday = todayRoutes.where((r) => r.isComplete).length;
  final inProgressToday = todayRoutes.where((r) => r.isInProgress).length;
  final plannedToday = todayRoutes.where((r) => r.isPlanned).length;

  int totalVisitsToday = 0;
  int completedVisitsToday = 0;
  for (final route in todayRoutes) {
    totalVisitsToday += route.totalClients;
    completedVisitsToday += route.completedClients;
  }

  return {
    'totalRoutesToday': todayRoutes.length,
    'completedRoutesToday': completedToday,
    'inProgressRoutesToday': inProgressToday,
    'plannedRoutesToday': plannedToday,
    'totalVisitsToday': totalVisitsToday,
    'completedVisitsToday': completedVisitsToday,
    'weekRoutes': routes.length,
    'weekCompletedRoutes': routes.where((r) => r.isComplete).length,
  };
});
