import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../core/models/route.dart';
import '../../core/models/route_form_question.dart';
import '../../core/models/event_check_in.dart';
import '../../core/models/user.dart';
import '../../core/enums/route_status.dart';
import '../local/database_service.dart';
import 'event_repository.dart';
import 'route_repository.dart';

/// Repositorio que implementa patrón Offline-First
/// - Lee primero de la base de datos local
/// - Sincroniza con el servidor en background
/// - Opera completamente offline si no hay conexión
class OfflineFirstRouteRepository {
  final RouteRepository _remoteRepository;
  final DatabaseService _localDb;
  final Connectivity _connectivity;
  
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  bool _isOnline = true;
  bool _isSyncing = false;

  OfflineFirstRouteRepository({
    RouteRepository? remoteRepository,
    DatabaseService? localDb,
    Connectivity? connectivity,
  })  : _remoteRepository = remoteRepository ?? RouteRepository(),
        _localDb = localDb ?? DatabaseService(),
        _connectivity = connectivity ?? Connectivity();

  /// Inicia el monitoreo de conectividad
  void startMonitoring() {
    _checkConnectivity();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(_handleConnectivityChange);
  }

  /// Detiene el monitoreo
  void stopMonitoring() {
    _connectivitySubscription?.cancel();
  }

  Future<void> _checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _handleConnectivityChange(result);
    } catch (_) {
      _isOnline = false;
    }
  }

  void _handleConnectivityChange(ConnectivityResult result) {
    final wasOnline = _isOnline;
    _isOnline = result == ConnectivityResult.wifi ||
        result == ConnectivityResult.mobile ||
        result == ConnectivityResult.ethernet;

    // Si volvemos a estar online, sincronizar silenciosamente
    if (_isOnline && !wasOnline && !_isSyncing) {
      syncPendingChanges();
    }
  }

  bool get isOnline => _isOnline;

  // ========================
  // LECTURA OFFLINE-FIRST
  // ========================

  /// Obtiene rutas para hoy - OFFLINE FIRST
  /// 1. Retorna datos locales inmediatamente
  /// 2. Sincroniza con servidor en background (silencioso)
  Future<List<AppRoute>> getRoutesForToday({
    required AppUser user,
    bool forceRefresh = false,
  }) async {
    final today = DateTime.now();
    
    // 1. Primero intentar obtener de local
    List<AppRoute> localRoutes = [];
    try {
      localRoutes = await _localDb.getRoutesForDate(user.id, today);
    } catch (e) {
      // Ignorar errores de BD local, continuar
    }

    // 2. Si forceRefresh o no hay datos locales, intentar sincronizar
    if (forceRefresh || localRoutes.isEmpty) {
      await _syncRoutesFromServer(user, today);
      
      // Recargar desde local después de sync
      try {
        localRoutes = await _localDb.getRoutesForDate(user.id, today);
      } catch (_) {}
    } else {
      // Sync en background (no bloquea)
      _syncRoutesFromServer(user, today);
    }

    return localRoutes;
  }

  /// Sincroniza rutas desde el servidor (silencioso)
  Future<void> _syncRoutesFromServer(AppUser user, DateTime date) async {
    if (!_isOnline) return;

    try {
      final remoteRoutes = await _remoteRepository.getRoutesForDate(
        requestingUser: user,
        date: date,
      );

      // Guardar cada ruta en local
      for (final route in remoteRoutes) {
        await _localDb.saveRoute(route, isSynced: true);
        
        // Descargar preguntas del formulario para el tipo de ruta
        if (route.routeTypeId != null) {
          await _downloadQuestionsForRouteType(route.routeTypeId!);
        }
      }
    } on SocketException catch (_) {
      // Sin conexión - ignorar silenciosamente
      _isOnline = false;
    } catch (_) {
      // Cualquier otro error - ignorar silenciosamente
    }
  }

  /// Descarga preguntas del formulario para un tipo de ruta
  Future<void> _downloadQuestionsForRouteType(String routeTypeId) async {
    try {
      // Verificar si ya las tenemos
      final hasQuestions = await _localDb.hasQuestionsForRouteType(routeTypeId);
      if (hasQuestions) return;
      
      // Descargar del servidor
      final questions = await _remoteRepository.getFormQuestions(routeTypeId);
      if (questions.isNotEmpty) {
        await _localDb.saveFormQuestions(questions);
      }
    } catch (_) {
      // Silencioso
    }
  }

  /// Obtiene una ruta por ID - OFFLINE FIRST
  Future<AppRoute?> getRouteById(String routeId) async {
    // Primero buscar en local
    AppRoute? localRoute;
    try {
      localRoute = await _localDb.getRouteById(routeId);
    } catch (_) {}

    // Si no hay local, intentar desde servidor
    if (localRoute == null && _isOnline) {
      try {
        final remoteRoute = await _remoteRepository.getRouteById(routeId);
        if (remoteRoute != null) {
          await _localDb.saveRoute(remoteRoute, isSynced: true);
          return remoteRoute;
        }
      } on SocketException catch (_) {
        _isOnline = false;
      } catch (_) {
        // Ignorar errores
      }
    }

    return localRoute;
  }

  // ========================
  // ESCRITURA OFFLINE-FIRST
  // ========================

  /// Inicia una ruta - funciona offline
  Future<AppRoute?> startRoute(String routeId) async {
    // 1. Actualizar localmente primero (is_synced = false)
    await _localDb.updateRouteStatus(routeId, RouteStatus.inProgress);

    // 2. Intentar sincronizar con servidor
    if (_isOnline) {
      try {
        final result = await _remoteRepository.startRoute(routeId);
        await _localDb.saveRoute(result, isSynced: true);
        return result;
      } on SocketException catch (_) {
        _isOnline = false;
      } catch (_) {
        // Guardar para sync posterior
        await _localDb.savePendingSync(
          tableName: 'routes',
          recordId: routeId,
          operation: 'start_route',
          data: {'route_id': routeId},
        );
      }
    } else {
      // Guardar operación pendiente
      await _localDb.savePendingSync(
        tableName: 'routes',
        recordId: routeId,
        operation: 'start_route',
        data: {'route_id': routeId},
      );
    }

    // Retornar versión local
    return _localDb.getRouteById(routeId);
  }

  /// Completa una ruta - funciona offline
  Future<AppRoute?> completeRoute(String routeId) async {
    await _localDb.updateRouteStatus(routeId, RouteStatus.completed);

    if (_isOnline) {
      try {
        final result = await _remoteRepository.completeRoute(routeId);
        await _localDb.saveRoute(result, isSynced: true);
        return result;
      } on SocketException catch (_) {
        _isOnline = false;
      } catch (_) {
        await _localDb.savePendingSync(
          tableName: 'routes',
          recordId: routeId,
          operation: 'complete_route',
          data: {'route_id': routeId},
        );
      }
    } else {
      await _localDb.savePendingSync(
        tableName: 'routes',
        recordId: routeId,
        operation: 'complete_route',
        data: {'route_id': routeId},
      );
    }

    return _localDb.getRouteById(routeId);
  }

  /// Inicia visita a un cliente - funciona offline
  Future<void> startClientVisit({
    required String routeClientId,
    required double latitude,
    required double longitude,
  }) async {
    await _localDb.updateRouteClientStatus(
      routeClientId: routeClientId,
      status: RouteClientStatus.inProgress,
      startedAt: DateTime.now(),
      latitudeStart: latitude,
      longitudeStart: longitude,
    );

    if (_isOnline) {
      try {
        await _remoteRepository.startClientVisit(
          routeClientId: routeClientId,
          latitude: latitude,
          longitude: longitude,
        );
        await _localDb.markRouteClientSynced(routeClientId);
      } on SocketException catch (_) {
        _isOnline = false;
      } catch (_) {
        // Ya guardado localmente, se sincronizará después
      }
    }
  }

  /// Completa visita a un cliente - funciona offline
  Future<void> completeClientVisit({
    required String routeClientId,
    required double latitude,
    required double longitude,
  }) async {
    await _localDb.updateRouteClientStatus(
      routeClientId: routeClientId,
      status: RouteClientStatus.completed,
      completedAt: DateTime.now(),
      latitudeEnd: latitude,
      longitudeEnd: longitude,
    );

    if (_isOnline) {
      try {
        await _remoteRepository.completeClientVisit(
          routeClientId: routeClientId,
          latitude: latitude,
          longitude: longitude,
        );
        await _localDb.markRouteClientSynced(routeClientId);
      } on SocketException catch (_) {
        _isOnline = false;
      } catch (_) {
        // Ya guardado localmente
      }
    }
  }

  /// Omite un cliente - funciona offline
  Future<void> skipClientVisit({required String routeClientId}) async {
    await _localDb.updateRouteClientStatus(
      routeClientId: routeClientId,
      status: RouteClientStatus.skipped,
      completedAt: DateTime.now(),
    );

    if (_isOnline) {
      try {
        await _remoteRepository.skipClientVisit(routeClientId);
        await _localDb.markRouteClientSynced(routeClientId);
      } on SocketException catch (_) {
        _isOnline = false;
      } catch (_) {
        // Ya guardado localmente, se sincronizará después
      }
    }
  }

  /// Marca un cliente como cerrado temporalmente - funciona offline
  Future<void> markClientClosedTemp({
    required String routeClientId,
    String? reason,
  }) async {
    await _localDb.updateRouteClientStatus(
      routeClientId: routeClientId,
      status: RouteClientStatus.closedTemp,
      completedAt: DateTime.now(),
      closureReason: reason,
    );

    if (_isOnline) {
      try {
        await _remoteRepository.markClientClosedTemp(
          routeClientId: routeClientId,
          reason: reason,
        );
        await _localDb.markRouteClientSynced(routeClientId);
      } on SocketException catch (_) {
        _isOnline = false;
      } catch (_) {
        // Ya guardado localmente, se sincronizará después
      }
    }
  }

  /// Actualiza coordenadas GPS y last_visit_at en tabla clients - funciona offline
  Future<void> updateClientAfterVisit({
    required String clientCoCli,
    required double latitude,
    required double longitude,
  }) async {
    final data = {
      'client_co_cli': clientCoCli,
      'latitude': latitude,
      'longitude': longitude,
      'last_visit_at': DateTime.now().toIso8601String(),
    };

    if (_isOnline) {
      try {
        await _remoteRepository.updateClientAfterVisit(
          clientCoCli: clientCoCli,
          latitude: latitude,
          longitude: longitude,
        );
        return;
      } on SocketException catch (_) {
        _isOnline = false;
      } catch (_) {
        // Guardar para sync posterior
      }
    }

    // Offline o falló: guardar como pendiente
    await _localDb.savePendingSync(
      tableName: 'clients',
      recordId: clientCoCli,
      operation: 'client_update',
      data: data,
    );
  }

  // ========================
  // SINCRONIZACIÓN
  // ========================

  /// Sincroniza todos los cambios pendientes con el servidor
  Future<void> syncPendingChanges() async {
    if (_isSyncing || !_isOnline) return;

    _isSyncing = true;
    try {
      // 1. Sincronizar rutas no sincronizadas
      final unsyncedRoutes = await _localDb.getUnsyncedRoutes();
      for (final routeMap in unsyncedRoutes) {
        try {
          // Sincronizar según el estado
          final status = routeMap['status'] as String;
          final routeId = routeMap['id'] as String;
          
          if (status == 'in_progress' && routeMap['started_at'] != null) {
            await _remoteRepository.startRoute(routeId);
          } else if (status == 'completed') {
            await _remoteRepository.completeRoute(routeId);
          }
          
          await _localDb.markRouteSynced(routeId);
        } catch (_) {
          // Continuar con el siguiente
        }
      }

      // 2. Sincronizar clientes de ruta no sincronizados
      final unsyncedClients = await _localDb.getUnsyncedRouteClients();
      for (final clientMap in unsyncedClients) {
        try {
          final status = clientMap['status'] as String;
          final clientId = clientMap['id'] as String;
          
          if (status == 'in_progress') {
            await _remoteRepository.startClientVisit(
              routeClientId: clientId,
              latitude: clientMap['latitude_start'] as double? ?? 0,
              longitude: clientMap['longitude_start'] as double? ?? 0,
            );
          } else if (status == 'completed') {
            await _remoteRepository.completeClientVisit(
              routeClientId: clientId,
              latitude: clientMap['latitude_end'] as double? ?? 0,
              longitude: clientMap['longitude_end'] as double? ?? 0,
            );
          } else if (status == 'skipped') {
            await _remoteRepository.skipClientVisit(clientId);
          } else if (status == 'closed_temp') {
            await _remoteRepository.markClientClosedTemp(
              routeClientId: clientId,
              reason: clientMap['closure_reason'] as String?,
            );
          }
          
          await _localDb.markRouteClientSynced(clientId);
        } catch (_) {
          // Continuar con el siguiente
        }
      }

      // 3. Procesar operaciones pendientes
      final pendingOps = await _localDb.getPendingSyncOperations();
      for (final op in pendingOps) {
        try {
          final operation = op['operation'] as String;
          final recordId = op['record_id'] as String;
          
          switch (operation) {
            case 'start_route':
              await _remoteRepository.startRoute(recordId);
              break;
            case 'complete_route':
              await _remoteRepository.completeRoute(recordId);
              break;
            case 'client_update':
              final data = jsonDecode(op['data_json'] as String) as Map<String, dynamic>;
              await _remoteRepository.updateClientAfterVisit(
                clientCoCli: data['client_co_cli'] as String,
                latitude: (data['latitude'] as num).toDouble(),
                longitude: (data['longitude'] as num).toDouble(),
              );
              break;
            case 'event_check_in':
              final data = jsonDecode(op['data_json'] as String) as Map<String, dynamic>;
              final eventRepo = EventRepository();
              final checkIn = EventCheckIn(
                id: '',
                eventId: data['event_id'] as String,
                mercaderistaId: data['mercaderista_id'] as String,
                checkInDate: DateTime.parse(data['check_in_date'] as String),
                startedAt: data['started_at'] != null ? DateTime.parse(data['started_at'] as String) : null,
                completedAt: data['completed_at'] != null ? DateTime.parse(data['completed_at'] as String) : null,
                latitude: (data['latitude'] as num?)?.toDouble(),
                longitude: (data['longitude'] as num?)?.toDouble(),
                observations: data['observations'] as String?,
                createdAt: DateTime.now(),
              );
              final created = await eventRepo.createCheckIn(checkIn);
              if (data['answers'] != null) {
                final answers = (data['answers'] as List).map((a) {
                  final m = a as Map<String, dynamic>;
                  return EventCheckInAnswer(
                    id: '',
                    checkInId: created.id,
                    questionId: m['question_id'] as String,
                    answer: m['answer'] as String?,
                    photoUrl: m['photo_url'] as String?,
                    createdAt: DateTime.now(),
                  );
                }).toList();
                await eventRepo.saveCheckInAnswers(answers);
              }
              break;
          }
          
          await _localDb.removePendingSync(op['id'] as int);
        } catch (_) {
          // Continuar con el siguiente
        }
      }
    } finally {
      _isSyncing = false;
    }
  }

  /// Descarga ruta completa para uso offline
  Future<void> downloadRouteForOffline(String routeId) async {
    if (!_isOnline) return;

    try {
      final route = await _remoteRepository.getRouteById(routeId);
      if (route != null) {
        await _localDb.saveRoute(route, isSynced: true);
        
        // También descargar preguntas
        if (route.routeTypeId != null) {
          await _downloadQuestionsForRouteType(route.routeTypeId!);
        }
      }
    } catch (_) {
      // Silencioso
    }
  }

  /// Obtiene preguntas del formulario - OFFLINE FIRST
  Future<List<RouteFormQuestion>> getFormQuestions(String routeTypeId) async {
    // Primero buscar en local
    try {
      final localQuestions = await _localDb.getFormQuestionsByRouteType(routeTypeId);
      if (localQuestions.isNotEmpty) {
        return localQuestions;
      }
    } catch (_) {}

    // Si no hay local y hay conexión, descargar
    if (_isOnline) {
      try {
        final questions = await _remoteRepository.getFormQuestions(routeTypeId);
        if (questions.isNotEmpty) {
          await _localDb.saveFormQuestions(questions);
        }
        return questions;
      } catch (_) {}
    }

    return [];
  }

  /// Limpia datos antiguos
  Future<void> cleanOldData() async {
    await _localDb.cleanOldRoutes();
  }
}
