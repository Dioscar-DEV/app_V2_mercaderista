import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/models/route.dart';
import '../../core/models/route_type.dart';
import '../../core/models/route_form_question.dart';
import '../../core/models/route_template.dart';
import '../../core/models/route_visit.dart';
import '../../core/models/user.dart';
import '../../core/enums/route_status.dart';
import '../../core/enums/user_role.dart';

/// Filtros para búsqueda de rutas
class RouteFilters {
  final String? search;
  final String? sedeApp;
  final String? mercaderistaId;
  final RouteStatus? status;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? routeTypeId;

  const RouteFilters({
    this.search,
    this.sedeApp,
    this.mercaderistaId,
    this.status,
    this.dateFrom,
    this.dateTo,
    this.routeTypeId,
  });

  RouteFilters copyWith({
    String? search,
    String? sedeApp,
    String? mercaderistaId,
    RouteStatus? status,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? routeTypeId,
  }) {
    return RouteFilters(
      search: search ?? this.search,
      sedeApp: sedeApp ?? this.sedeApp,
      mercaderistaId: mercaderistaId ?? this.mercaderistaId,
      status: status ?? this.status,
      dateFrom: dateFrom ?? this.dateFrom,
      dateTo: dateTo ?? this.dateTo,
      routeTypeId: routeTypeId ?? this.routeTypeId,
    );
  }

  bool get hasFilters =>
      search != null ||
      sedeApp != null ||
      mercaderistaId != null ||
      status != null ||
      dateFrom != null ||
      dateTo != null ||
      routeTypeId != null;
}

/// Repositorio de rutas
class RouteRepository {
  final SupabaseClient _client;

  RouteRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  // ========================
  // RUTAS (CRUD)
  // ========================

  /// Obtiene rutas con filtros
  Future<List<AppRoute>> getRoutes({
    required AppUser requestingUser,
    RouteFilters? filters,
    int? limit,
    int? offset,
  }) async {
    // Construir filtros primero
    var filterBuilder = _client.from('routes').select('''
      *,
      route_type:route_types(*),
      route_clients(*, clients(*))
    ''');

    // Filtrar por sede según el rol del usuario
    if (!requestingUser.role.canViewAllSedes) {
      final userSedeApp = requestingUser.sede?.value;
      if (userSedeApp != null) {
        filterBuilder = filterBuilder.eq('sede_app', userSedeApp);
      }
    }

    // Si es mercaderista, solo ve sus propias rutas
    if (requestingUser.role == UserRole.mercaderista) {
      filterBuilder = filterBuilder.eq('mercaderista_id', requestingUser.id);
    }

    // Aplicar filtros adicionales
    if (filters != null) {
      if (filters.sedeApp != null) {
        filterBuilder = filterBuilder.eq('sede_app', filters.sedeApp!);
      }
      if (filters.mercaderistaId != null) {
        filterBuilder = filterBuilder.eq('mercaderista_id', filters.mercaderistaId!);
      }
      if (filters.status != null) {
        filterBuilder = filterBuilder.eq('status', filters.status!.value);
      }
      if (filters.dateFrom != null) {
        filterBuilder = filterBuilder.gte('scheduled_date', filters.dateFrom!.toIso8601String().split('T')[0]);
      }
      if (filters.dateTo != null) {
        filterBuilder = filterBuilder.lte('scheduled_date', filters.dateTo!.toIso8601String().split('T')[0]);
      }
      if (filters.routeTypeId != null) {
        filterBuilder = filterBuilder.eq('route_type_id', filters.routeTypeId!);
      }
      if (filters.search != null && filters.search!.isNotEmpty) {
        filterBuilder = filterBuilder.ilike('name', '%${filters.search}%');
      }
    }

    // Ordenar por fecha programada descendente
    var query = filterBuilder.order('scheduled_date', ascending: false);

    // Paginación
    if (limit != null && offset != null) {
      final response = await query.range(offset, offset + limit - 1);
      return (response as List).map((json) => AppRoute.fromJson(json)).toList();
    } else if (limit != null) {
      final response = await query.limit(limit);
      return (response as List).map((json) => AppRoute.fromJson(json)).toList();
    }

    final response = await query;
    return (response as List).map((json) => AppRoute.fromJson(json)).toList();
  }

  /// Obtiene rutas para una fecha específica (para calendario)
  Future<List<AppRoute>> getRoutesForDate({
    required AppUser requestingUser,
    required DateTime date,
  }) async {
    return getRoutes(
      requestingUser: requestingUser,
      filters: RouteFilters(
        dateFrom: date,
        dateTo: date,
      ),
    );
  }

  /// Obtiene rutas de la semana (para calendario semanal)
  Future<List<AppRoute>> getRoutesForWeek({
    required AppUser requestingUser,
    required DateTime weekStart,
  }) async {
    final weekEnd = weekStart.add(const Duration(days: 6));
    return getRoutes(
      requestingUser: requestingUser,
      filters: RouteFilters(
        dateFrom: weekStart,
        dateTo: weekEnd,
      ),
    );
  }

  /// Obtiene una ruta por ID con todos sus detalles
  Future<AppRoute?> getRouteById(String id) async {
    final response = await _client
        .from('routes')
        .select('''
          *,
          route_type:route_types(*),
          route_clients(*, clients(*))
        ''')
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return AppRoute.fromJson(response);
  }

  /// Crea una nueva ruta
  Future<AppRoute> createRoute(AppRoute route) async {
    final response = await _client
        .from('routes')
        .insert(route.toInsertJson())
        .select()
        .single();

    return AppRoute.fromJson(response);
  }

  /// Actualiza una ruta existente
  Future<AppRoute> updateRoute(AppRoute route) async {
    final response = await _client
        .from('routes')
        .update({
          'name': route.name,
          'scheduled_date': route.scheduledDate.toIso8601String().split('T')[0],
          'status': route.status.value,
          'mercaderista_id': route.mercaderistaId,
          'route_type_id': route.routeTypeId,
          'notes': route.notes,
          'started_at': route.startedAt?.toIso8601String(),
          'completed_at': route.completedAt?.toIso8601String(),
          'total_clients': route.totalClients,
          'completed_clients': route.completedClients,
        })
        .eq('id', route.id)
        .select()
        .single();

    return AppRoute.fromJson(response);
  }

  /// Elimina una ruta
  Future<void> deleteRoute(String id) async {
    await _client.from('routes').delete().eq('id', id);
  }

  /// Inicia una ruta (cambia estado a in_progress)
  Future<AppRoute> startRoute(String routeId) async {
    final response = await _client
        .from('routes')
        .update({
          'status': 'in_progress',
          'started_at': DateTime.now().toIso8601String(),
        })
        .eq('id', routeId)
        .select()
        .single();

    return AppRoute.fromJson(response);
  }

  /// Completa una ruta
  Future<AppRoute> completeRoute(String routeId) async {
    final response = await _client
        .from('routes')
        .update({
          'status': 'completed',
          'completed_at': DateTime.now().toIso8601String(),
        })
        .eq('id', routeId)
        .select()
        .single();

    return AppRoute.fromJson(response);
  }

  // ========================
  // CLIENTES EN RUTA
  // ========================

  /// Agrega clientes a una ruta
  Future<List<RouteClient>> addClientsToRoute({
    required String routeId,
    required List<String> clientIds,
  }) async {
    final clientsToInsert = clientIds.asMap().entries.map((entry) {
      return {
        'route_id': routeId,
        'client_co_cli': entry.value,
        'order_number': entry.key + 1,
        'status': 'pending',
      };
    }).toList();

    final response = await _client
        .from('route_clients')
        .insert(clientsToInsert)
        .select('*, clients(*)');

    // Actualizar contador de clientes en la ruta
    await _client.from('routes').update({
      'total_clients': clientIds.length,
    }).eq('id', routeId);

    return (response as List)
        .map((json) => RouteClient.fromJson(json))
        .toList();
  }

  /// Elimina un cliente de una ruta
  Future<void> removeClientFromRoute({
    required String routeId,
    required String clientId,
  }) async {
    await _client
        .from('route_clients')
        .delete()
        .eq('route_id', routeId)
        .eq('client_co_cli', clientId);

    // Actualizar contador
    final count = await _client
        .from('route_clients')
        .select()
        .eq('route_id', routeId);

    await _client.from('routes').update({
      'total_clients': (count as List).length,
    }).eq('id', routeId);
  }

  /// Actualiza el orden de los clientes en una ruta
  Future<void> reorderRouteClients({
    required String routeId,
    required List<String> clientIds,
  }) async {
    for (int i = 0; i < clientIds.length; i++) {
      await _client
          .from('route_clients')
          .update({'order_number': i + 1})
          .eq('route_id', routeId)
          .eq('client_co_cli', clientIds[i]);
    }
  }

  /// Inicia visita a un cliente (actualiza estado y GPS inicial)
  Future<RouteClient> startClientVisit({
    required String routeClientId,
    required double latitude,
    required double longitude,
  }) async {
    final response = await _client
        .from('route_clients')
        .update({
          'status': 'in_progress',
          'started_at': DateTime.now().toIso8601String(),
          'latitude_start': latitude,
          'longitude_start': longitude,
        })
        .eq('id', routeClientId)
        .select('*, clients(*)')
        .single();

    return RouteClient.fromJson(response);
  }

  /// Completa visita a un cliente
  Future<RouteClient> completeClientVisit({
    required String routeClientId,
    required double latitude,
    required double longitude,
  }) async {
    final response = await _client
        .from('route_clients')
        .update({
          'status': 'completed',
          'completed_at': DateTime.now().toIso8601String(),
          'latitude_end': latitude,
          'longitude_end': longitude,
        })
        .eq('id', routeClientId)
        .select('*, clients(*)')
        .single();

    // Actualizar contador de completados en la ruta
    final routeClient = RouteClient.fromJson(response);
    await _updateCompletedClientsCount(routeClient.routeId);

    return routeClient;
  }

  /// Omite un cliente (skip)
  Future<RouteClient> skipClientVisit(String routeClientId) async {
    final response = await _client
        .from('route_clients')
        .update({
          'status': 'skipped',
          'completed_at': DateTime.now().toIso8601String(),
        })
        .eq('id', routeClientId)
        .select('*, clients(*)')
        .single();

    return RouteClient.fromJson(response);
  }

  /// Marca un cliente como cerrado temporalmente
  Future<RouteClient> markClientClosedTemp({
    required String routeClientId,
    String? reason,
  }) async {
    final response = await _client
        .from('route_clients')
        .update({
          'status': 'closed_temp',
          'completed_at': DateTime.now().toIso8601String(),
          'closure_reason': reason,
        })
        .eq('id', routeClientId)
        .select('*, clients(*)')
        .single();

    return RouteClient.fromJson(response);
  }

  /// Marca un cliente como cerrado permanentemente
  Future<void> markClientPermanentlyClosed({
    required String clientCoCli,
    required String reason,
  }) async {
    await _client.from('clients').update({
      'permanently_closed': true,
      'closed_at': DateTime.now().toIso8601String(),
      'closed_reason': reason,
    }).eq('co_cli', clientCoCli);
  }

  /// Cancela una ruta con motivo obligatorio
  Future<void> cancelRoute({
    required String routeId,
    required String reason,
  }) async {
    await _client.from('routes').update({
      'status': 'cancelled',
      'cancellation_reason': reason,
      'completed_at': DateTime.now().toIso8601String(),
    }).eq('id', routeId);
  }

  /// Obtiene rutas del día anterior con clientes pendientes
  Future<List<AppRoute>> getYesterdayPendingRoutes(String mercaderistaId) async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final dateStr = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

    final response = await _client
        .from('routes')
        .select('*, route_clients(*, clients(*))')
        .eq('mercaderista_id', mercaderistaId)
        .eq('scheduled_date', dateStr)
        .neq('status', 'cancelled');

    final routes = (response as List)
        .map((e) => AppRoute.fromJson(e as Map<String, dynamic>))
        .where((r) => r.clients != null && r.clients!.any((c) => c.isPending || c.isInProgress))
        .toList();

    return routes;
  }

  Future<void> _updateCompletedClientsCount(String routeId) async {
    final completed = await _client
        .from('route_clients')
        .select()
        .eq('route_id', routeId)
        .eq('status', 'completed');

    await _client.from('routes').update({
      'completed_clients': (completed as List).length,
    }).eq('id', routeId);
  }

  // ========================
  // VISITAS Y FORMULARIOS
  // ========================

  /// Crea una visita con sus respuestas
  Future<RouteVisit> createVisit({
    required RouteVisit visit,
    required List<RouteVisitAnswer> answers,
  }) async {
    // Insertar la visita
    final visitResponse = await _client
        .from('route_visits')
        .insert(visit.toInsertJson())
        .select()
        .single();

    final createdVisit = RouteVisit.fromJson(visitResponse);

    // Insertar las respuestas
    if (answers.isNotEmpty) {
      final answersToInsert = answers.map((a) {
        final json = a.toInsertJson();
        json['visit_id'] = createdVisit.id;
        return json;
      }).toList();

      await _client.from('route_visit_answers').insert(answersToInsert);
    }

    return createdVisit;
  }

  /// Obtiene visitas de un route_client
  Future<List<RouteVisit>> getVisitsForRouteClient(String routeClientId) async {
    final response = await _client
        .from('route_visits')
        .select('*, route_visit_answers(*, route_form_questions(*))')
        .eq('route_client_id', routeClientId)
        .order('visited_at', ascending: false);

    return (response as List)
        .map((json) => RouteVisit.fromJson(json))
        .toList();
  }

  // ========================
  // TIPOS DE RUTA
  // ========================

  /// Obtiene todos los tipos de ruta activos
  Future<List<RouteType>> getRouteTypes() async {
    final response = await _client
        .from('route_types')
        .select()
        .eq('is_active', true)
        .order('name');

    return (response as List)
        .map((json) => RouteType.fromJson(json))
        .toList();
  }

  /// Obtiene preguntas del formulario para un tipo de ruta
  Future<List<RouteFormQuestion>> getFormQuestions(String routeTypeId) async {
    final response = await _client
        .from('route_form_questions')
        .select()
        .eq('route_type_id', routeTypeId)
        .eq('is_active', true)
        .order('display_order');

    return (response as List)
        .map((json) => RouteFormQuestion.fromJson(json))
        .toList();
  }

  // ========================
  // PLANTILLAS
  // ========================

  /// Obtiene plantillas
  Future<List<RouteTemplate>> getTemplates({
    required AppUser requestingUser,
  }) async {
    var query = _client.from('route_templates').select('''
      *,
      route_template_clients(*, clients(*))
    ''');

    // Filtrar por sede
    if (!requestingUser.role.canViewAllSedes) {
      final userSedeApp = requestingUser.sede?.value;
      if (userSedeApp != null) {
        query = query.eq('sede_app', userSedeApp);
      }
    }

    final response = await query.eq('is_active', true).order('name');
    return (response as List)
        .map((json) => RouteTemplate.fromJson(json))
        .toList();
  }

  /// Crea una plantilla
  Future<RouteTemplate> createTemplate(RouteTemplate template) async {
    final response = await _client
        .from('route_templates')
        .insert(template.toInsertJson())
        .select()
        .single();

    return RouteTemplate.fromJson(response);
  }

  /// Agrega clientes a una plantilla
  Future<void> addClientsToTemplate({
    required String templateId,
    required List<String> clientIds,
  }) async {
    final clientsToInsert = clientIds.asMap().entries.map((entry) {
      return {
        'template_id': templateId,
        'client_co_cli': entry.value,
        'order_number': entry.key + 1,
      };
    }).toList();

    await _client.from('route_template_clients').insert(clientsToInsert);
  }

  /// Crea una ruta desde una plantilla
  Future<AppRoute> createRouteFromTemplate({
    required String templateId,
    required String mercaderistaId,
    required DateTime scheduledDate,
    required String? routeTypeId,
    required String sedeApp,
    required String createdBy,
  }) async {
    // Obtener la plantilla con sus clientes
    final templateResponse = await _client
        .from('route_templates')
        .select('*, route_template_clients(client_co_cli, order_number)')
        .eq('id', templateId)
        .single();

    final template = RouteTemplate.fromJson(templateResponse);

    // Crear la ruta
    final routeResponse = await _client
        .from('routes')
        .insert({
          'mercaderista_id': mercaderistaId,
          'name': template.name,
          'scheduled_date': scheduledDate.toIso8601String().split('T')[0],
          'status': 'planned',
          'template_id': templateId,
          'route_type_id': routeTypeId,
          'sede_app': sedeApp,
          'created_by': createdBy,
          'total_clients': template.clients?.length ?? 0,
        })
        .select()
        .single();

    final route = AppRoute.fromJson(routeResponse);

    // Agregar los clientes de la plantilla a la ruta
    if (template.clients != null && template.clients!.isNotEmpty) {
      final routeClients = template.clients!.map((tc) {
        return {
          'route_id': route.id,
          'client_co_cli': tc.clientId,
          'order_number': tc.orderNumber,
          'status': 'pending',
        };
      }).toList();

      await _client.from('route_clients').insert(routeClients);
    }

    return route;
  }

  // ========================
  // SINCRONIZACIÓN OFFLINE
  // ========================

  /// Sincroniza visitas pendientes (creadas offline)
  Future<List<RouteVisit>> syncPendingVisits(List<RouteVisit> visits) async {
    final syncedVisits = <RouteVisit>[];

    for (final visit in visits) {
      try {
        // Insertar la visita
        final visitResponse = await _client
            .from('route_visits')
            .insert({
              ...visit.toInsertJson(),
              'synced_at': DateTime.now().toIso8601String(),
            })
            .select()
            .single();

        final syncedVisit = RouteVisit.fromJson(visitResponse);

        // Insertar las respuestas
        if (visit.answers != null && visit.answers!.isNotEmpty) {
          final answersToInsert = visit.answers!.map((a) {
            final json = a.toInsertJson();
            json['visit_id'] = syncedVisit.id;
            return json;
          }).toList();

          await _client.from('route_visit_answers').insert(answersToInsert);
        }

        syncedVisits.add(syncedVisit);
      } catch (e) {
        // Si falla una visita, continuar con las demás
        print('Error syncing visit: $e');
      }
    }

    return syncedVisits;
  }

  /// Obtiene datos completos de ruta para modo offline
  /// Incluye clientes con su información y preguntas del formulario
  Future<Map<String, dynamic>> getRouteForOffline(String routeId) async {
    // Obtener la ruta con sus clientes
    final routeResponse = await _client
        .from('routes')
        .select('''
          *,
          route_type:route_types(*),
          route_clients(*, clients(*))
        ''')
        .eq('id', routeId)
        .single();

    final route = AppRoute.fromJson(routeResponse);

    // Obtener las preguntas del formulario si hay tipo de ruta
    List<RouteFormQuestion> questions = [];
    if (route.routeTypeId != null) {
      questions = await getFormQuestions(route.routeTypeId!);
    }

    return {
      'route': route,
      'questions': questions,
    };
  }
}
