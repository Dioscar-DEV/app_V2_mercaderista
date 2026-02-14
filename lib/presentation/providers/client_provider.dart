import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/client.dart';
import '../../data/repositories/client_repository.dart';
import '../../data/services/external_client_api_service.dart';
import 'auth_provider.dart';

/// Provider del servicio de API externa
final externalClientApiProvider = Provider<ExternalClientApiService>((ref) {
  return ExternalClientApiService();
});

/// Provider del repositorio de clientes
final clientRepositoryProvider = Provider<ClientRepository>((ref) {
  return ClientRepository();
});

/// Provider de filtros de clientes
final clientFiltersProvider = StateProvider<ClientFilters>((ref) {
  return const ClientFilters();
});

/// Provider de clientes con filtros aplicados
final clientsProvider = FutureProvider<List<Client>>((ref) async {
  final repository = ref.watch(clientRepositoryProvider);
  final filters = ref.watch(clientFiltersProvider);
  final currentUser = await ref.watch(currentUserProvider.future);
  
  if (currentUser == null) {
    throw Exception('Usuario no autenticado');
  }
  
  return repository.getClients(
    requestingUser: currentUser,
    filters: filters,
    limit: 5000,
  );
});

/// Provider de un cliente específico
final clientByIdProvider = FutureProvider.family<Client?, String>((ref, coCli) async {
  final repository = ref.watch(clientRepositoryProvider);
  return repository.getClientByCoCli(coCli);
});

/// Provider de estadísticas de clientes
final clientStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repository = ref.watch(clientRepositoryProvider);
  final currentUser = await ref.watch(currentUserProvider.future);
  final filters = ref.watch(clientFiltersProvider);
  
  if (currentUser == null) {
    throw Exception('Usuario no autenticado');
  }
  
  return repository.getClientStats(
    requestingUser: currentUser,
    sedeApp: filters.sedeApp,
  );
});

/// Provider de sedes de la API
final apiSedesProvider = FutureProvider<List<ApiSede>>((ref) async {
  final repository = ref.watch(clientRepositoryProvider);
  return repository.getApiSedes();
});

/// Provider de ciudades disponibles
final availableCitiesProvider = FutureProvider<List<String>>((ref) async {
  final repository = ref.watch(clientRepositoryProvider);
  final filters = ref.watch(clientFiltersProvider);
  return repository.getCiudadesDisponibles(sedeApp: filters.sedeApp);
});

/// Provider de visitas de un cliente
final clientVisitsProvider = FutureProvider.family<List<ClientVisit>, String>((ref, coCli) async {
  final repository = ref.watch(clientRepositoryProvider);
  return repository.getClientVisits(coCli, limit: 20);
});

/// Estado de sincronización
class SyncState {
  final bool isSyncing;
  final int current;
  final int total;
  final String message;
  final SyncResult? result;
  final String? error;

  const SyncState({
    this.isSyncing = false,
    this.current = 0,
    this.total = 0,
    this.message = '',
    this.result,
    this.error,
  });

  SyncState copyWith({
    bool? isSyncing,
    int? current,
    int? total,
    String? message,
    SyncResult? result,
    String? error,
  }) {
    return SyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      current: current ?? this.current,
      total: total ?? this.total,
      message: message ?? this.message,
      result: result ?? this.result,
      error: error,
    );
  }

  double get progress => total > 0 ? current / total : 0;
}

/// Provider del estado de sincronización
final syncStateProvider = StateNotifierProvider<SyncController, SyncState>((ref) {
  return SyncController(ref);
});

/// Controlador de sincronización
class SyncController extends StateNotifier<SyncState> {
  final Ref _ref;
  
  SyncController(this._ref) : super(const SyncState());

  /// Inicia la sincronización de clientes
  Future<void> syncClients({List<int>? sedeCodes}) async {
    if (state.isSyncing) return;

    state = state.copyWith(
      isSyncing: true,
      current: 0,
      total: sedeCodes?.length ?? ExternalClientApiService.sedeMapping.length,
      message: 'Iniciando sincronización...',
      error: null,
      result: null,
    );

    try {
      final repository = _ref.read(clientRepositoryProvider);
      
      final result = await repository.syncClientsFromApi(
        sedeCodes: sedeCodes,
        onProgress: (current, total, message) {
          state = state.copyWith(
            current: current,
            total: total,
            message: message,
          );
        },
      );

      state = state.copyWith(
        isSyncing: false,
        result: result,
        message: 'Sincronización completada',
      );

      // Refrescar los providers de clientes
      _ref.invalidate(clientsProvider);
      _ref.invalidate(clientStatsProvider);
      _ref.invalidate(apiSedesProvider);

    } catch (e) {
      state = state.copyWith(
        isSyncing: false,
        error: e.toString(),
        message: 'Error en sincronización',
      );
    }
  }

  /// Reinicia el estado
  void reset() {
    state = const SyncState();
  }
}

/// Controlador de acciones sobre clientes
class ClientActionsController extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  
  ClientActionsController(this._ref) : super(const AsyncValue.data(null));

  /// Asigna un mercaderista a un cliente
  Future<void> assignMercaderista(String coCli, String? mercaderistaId) async {
    state = const AsyncValue.loading();
    try {
      final repository = _ref.read(clientRepositoryProvider);
      await repository.assignMercaderista(coCli, mercaderistaId);
      _ref.invalidate(clientByIdProvider(coCli));
      _ref.invalidate(clientsProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Actualiza notas de un cliente
  Future<void> updateNotes(String coCli, String? notes) async {
    state = const AsyncValue.loading();
    try {
      final repository = _ref.read(clientRepositoryProvider);
      await repository.updateClientNotes(coCli, notes);
      _ref.invalidate(clientByIdProvider(coCli));
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Registra una visita
  Future<ClientVisit?> registerVisit({
    required String clientCoCli,
    required String mercaderistaId,
    double? latitude,
    double? longitude,
    String? notes,
    List<String>? photos,
  }) async {
    state = const AsyncValue.loading();
    try {
      final repository = _ref.read(clientRepositoryProvider);
      final visit = await repository.registerVisit(
        clientCoCli: clientCoCli,
        mercaderistaId: mercaderistaId,
        latitude: latitude,
        longitude: longitude,
        notes: notes,
        photos: photos,
      );
      _ref.invalidate(clientByIdProvider(clientCoCli));
      _ref.invalidate(clientVisitsProvider(clientCoCli));
      _ref.invalidate(clientsProvider);
      state = const AsyncValue.data(null);
      return visit;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }
}

final clientActionsProvider = StateNotifierProvider<ClientActionsController, AsyncValue<void>>((ref) {
  return ClientActionsController(ref);
});

/// Provider para búsqueda de clientes
final clientSearchQueryProvider = StateProvider<String>((ref) => '');

/// Provider de clientes filtrados por búsqueda
final searchedClientsProvider = Provider<AsyncValue<List<Client>>>((ref) {
  final clientsAsync = ref.watch(clientsProvider);
  final searchQuery = ref.watch(clientSearchQueryProvider).toLowerCase();

  return clientsAsync.when(
    data: (clients) {
      if (searchQuery.isEmpty) {
        return AsyncValue.data(clients);
      }
      final filtered = clients.where((c) {
        return c.cliDes.toLowerCase().contains(searchQuery) ||
            (c.rif?.toLowerCase().contains(searchQuery) ?? false) ||
            (c.ciudad?.toLowerCase().contains(searchQuery) ?? false) ||
            (c.direc1?.toLowerCase().contains(searchQuery) ?? false) ||
            (c.dirEnt2?.toLowerCase().contains(searchQuery) ?? false);
      }).toList();
      return AsyncValue.data(filtered);
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});
