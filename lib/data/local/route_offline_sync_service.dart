import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/route.dart';
import '../../core/models/route_visit.dart';
import '../../core/models/route_form_question.dart';
import '../repositories/route_repository.dart';
import 'route_local_storage.dart';

/// Servicio que orquesta la sincronización de datos offline
class RouteOfflineSyncService {
  final RouteRepository _repository;
  final RouteLocalStorage _localStorage;
  final Connectivity _connectivity;
  
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  bool _isOnline = true;
  bool _isSyncing = false;

  // Callbacks para notificar cambios de estado
  Function(bool isOnline)? onConnectivityChanged;
  Function(int synced, int total)? onSyncProgress;
  Function(String error)? onSyncError;
  Function()? onSyncComplete;

  RouteOfflineSyncService({
    RouteRepository? repository,
    RouteLocalStorage? localStorage,
    Connectivity? connectivity,
  })  : _repository = repository ?? RouteRepository(),
        _localStorage = localStorage ?? RouteLocalStorage(),
        _connectivity = connectivity ?? Connectivity();

  /// Inicia el monitoreo de conectividad
  void startMonitoring() {
    _checkConnectivity();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((result) {
      _handleConnectivityChange([result]);
    });
  }

  /// Detiene el monitoreo de conectividad
  void stopMonitoring() {
    _connectivitySubscription?.cancel();
  }

  Future<void> _checkConnectivity() async {
    final result = await _connectivity.checkConnectivity();
    _handleConnectivityChange([result]);
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final wasOnline = _isOnline;
    _isOnline = results.any((r) => 
      r == ConnectivityResult.wifi || 
      r == ConnectivityResult.mobile ||
      r == ConnectivityResult.ethernet
    );

    if (_isOnline != wasOnline) {
      onConnectivityChanged?.call(_isOnline);

      // Si volvemos a estar online, intentar sincronizar
      if (_isOnline && !_isSyncing) {
        syncPendingData();
      }
    }
  }

  bool get isOnline => _isOnline;

  // ========================
  // DESCARGA PARA OFFLINE
  // ========================

  /// Descarga una ruta completa para uso offline
  Future<void> downloadRouteForOffline(String routeId) async {
    try {
      // Obtener ruta del servidor con todos sus datos
      final data = await _repository.getRouteForOffline(routeId);
      final route = data['route'] as AppRoute;
      final questions = data['questions'] as List<RouteFormQuestion>;

      // Guardar localmente
      await _localStorage.saveRouteOffline(route, questions);
    } catch (e) {
      throw Exception('Error descargando ruta para offline: $e');
    }
  }

  /// Obtiene una ruta (desde servidor si hay conexión, desde local si no)
  Future<Map<String, dynamic>?> getRoute(String routeId) async {
    if (_isOnline) {
      try {
        final data = await _repository.getRouteForOffline(routeId);
        
        // Guardar copia local
        final route = data['route'] as AppRoute;
        final questions = data['questions'] as List<RouteFormQuestion>;
        await _localStorage.saveRouteOffline(route, questions);
        
        return data;
      } catch (e) {
        // Si falla, intentar desde local
        return _localStorage.getRouteOffline(routeId);
      }
    } else {
      return _localStorage.getRouteOffline(routeId);
    }
  }

  // ========================
  // OPERACIONES OFFLINE
  // ========================

  /// Inicia visita a un cliente (funciona offline)
  Future<RouteClient?> startClientVisit({
    required String routeId,
    required String routeClientId,
    required double latitude,
    required double longitude,
  }) async {
    if (_isOnline) {
      try {
        final result = await _repository.startClientVisit(
          routeClientId: routeClientId,
          latitude: latitude,
          longitude: longitude,
        );

        // Actualizar copia local
        await _localStorage.updateRouteClientOffline(
          routeId,
          routeClientId,
          RouteClientStatus.inProgress,
          startedAt: DateTime.now(),
          latitudeStart: latitude,
          longitudeStart: longitude,
        );

        return result;
      } catch (e) {
        // Si falla, operar offline
        await _localStorage.updateRouteClientOffline(
          routeId,
          routeClientId,
          RouteClientStatus.inProgress,
          startedAt: DateTime.now(),
          latitudeStart: latitude,
          longitudeStart: longitude,
        );
        return null;
      }
    } else {
      // Modo offline
      await _localStorage.updateRouteClientOffline(
        routeId,
        routeClientId,
        RouteClientStatus.inProgress,
        startedAt: DateTime.now(),
        latitudeStart: latitude,
        longitudeStart: longitude,
      );
      return null;
    }
  }

  /// Completa visita a un cliente (funciona offline)
  Future<void> completeClientVisit({
    required String routeId,
    required String routeClientId,
    required RouteVisit visit,
    required List<RouteVisitAnswer> answers,
  }) async {
    if (_isOnline) {
      try {
        await _repository.completeClientVisit(
          routeClientId: routeClientId,
          latitude: visit.latitude ?? 0,
          longitude: visit.longitude ?? 0,
        );

        await _repository.createVisit(visit: visit, answers: answers);

        // Actualizar copia local
        await _localStorage.updateRouteClientOffline(
          routeId,
          routeClientId,
          RouteClientStatus.completed,
          completedAt: DateTime.now(),
          latitudeEnd: visit.latitude,
          longitudeEnd: visit.longitude,
        );
      } catch (e) {
        // Si falla, guardar para sincronizar después
        await _saveVisitForLaterSync(routeId, routeClientId, visit, answers);
      }
    } else {
      // Modo offline
      await _saveVisitForLaterSync(routeId, routeClientId, visit, answers);
    }
  }

  Future<void> _saveVisitForLaterSync(
    String routeId,
    String routeClientId,
    RouteVisit visit,
    List<RouteVisitAnswer> answers,
  ) async {
    // Actualizar estado local
    await _localStorage.updateRouteClientOffline(
      routeId,
      routeClientId,
      RouteClientStatus.completed,
      completedAt: DateTime.now(),
      latitudeEnd: visit.latitude,
      longitudeEnd: visit.longitude,
    );

    // Guardar visita pendiente con respuestas
    final visitWithAnswers = visit.copyWith(answers: answers);
    await _localStorage.savePendingVisit(visitWithAnswers);
  }

  // ========================
  // SINCRONIZACIÓN
  // ========================

  /// Sincroniza todos los datos pendientes
  Future<void> syncPendingData() async {
    if (!_isOnline || _isSyncing) return;

    _isSyncing = true;

    try {
      // Obtener visitas pendientes
      final pendingVisits = await _localStorage.getPendingVisits();
      
      if (pendingVisits.isEmpty) {
        onSyncComplete?.call();
        return;
      }

      final syncedIds = <String>[];
      
      for (int i = 0; i < pendingVisits.length; i++) {
        final visit = pendingVisits[i];
        
        onSyncProgress?.call(i + 1, pendingVisits.length);

        try {
          // Sincronizar la visita
          await _repository.createVisit(
            visit: visit,
            answers: visit.answers ?? [],
          );
          syncedIds.add(visit.id);
        } catch (e) {
          onSyncError?.call('Error sincronizando visita: $e');
        }
      }

      // Eliminar visitas sincronizadas del almacenamiento local
      if (syncedIds.isNotEmpty) {
        await _localStorage.removeSyncedVisits(syncedIds);
      }

      onSyncComplete?.call();
    } finally {
      _isSyncing = false;
    }
  }

  /// Obtiene estadísticas de datos pendientes
  Future<Map<String, int>> getPendingStats() async {
    return _localStorage.getOfflineStats();
  }

  /// Limpia todos los datos offline
  Future<void> clearOfflineData() async {
    await _localStorage.clearAll();
  }
}

/// Provider del servicio de sincronización offline
final routeOfflineSyncProvider = Provider<RouteOfflineSyncService>((ref) {
  final service = RouteOfflineSyncService();
  service.startMonitoring();
  
  ref.onDispose(() {
    service.stopMonitoring();
  });
  
  return service;
});

/// Provider del estado de conectividad
final connectivityProvider = StreamProvider<bool>((ref) {
  final connectivity = Connectivity();
  
  return connectivity.onConnectivityChanged.map((result) {
    return result == ConnectivityResult.wifi || 
           result == ConnectivityResult.mobile ||
           result == ConnectivityResult.ethernet;
  });
});

/// Provider de visitas pendientes de sincronización
final pendingVisitsCountProvider = FutureProvider<int>((ref) async {
  final service = ref.watch(routeOfflineSyncProvider);
  final stats = await service.getPendingStats();
  return stats['pendingVisits'] ?? 0;
});
