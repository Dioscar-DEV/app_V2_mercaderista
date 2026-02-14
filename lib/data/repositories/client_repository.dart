import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/models/client.dart';
import '../../core/models/user.dart';
import '../services/external_client_api_service.dart';

/// Filtros para búsqueda de clientes
class ClientFilters {
  final String? search;
  final String? sedeApp;
  final int? apiSedeCode;
  final String? ciudad;
  final bool? activo;
  final bool? sinVisitaReciente; // Sin visita en los últimos N días
  final int? diasSinVisita;
  final String? assignedMercaderistaId;
  final bool? conMercaderistaAsignado;

  const ClientFilters({
    this.search,
    this.sedeApp,
    this.apiSedeCode,
    this.ciudad,
    this.activo,
    this.sinVisitaReciente,
    this.diasSinVisita,
    this.assignedMercaderistaId,
    this.conMercaderistaAsignado,
  });

  ClientFilters copyWith({
    String? search,
    String? sedeApp,
    int? apiSedeCode,
    String? ciudad,
    bool? activo,
    bool? sinVisitaReciente,
    int? diasSinVisita,
    String? assignedMercaderistaId,
    bool? conMercaderistaAsignado,
  }) {
    return ClientFilters(
      search: search ?? this.search,
      sedeApp: sedeApp ?? this.sedeApp,
      apiSedeCode: apiSedeCode ?? this.apiSedeCode,
      ciudad: ciudad ?? this.ciudad,
      activo: activo ?? this.activo,
      sinVisitaReciente: sinVisitaReciente ?? this.sinVisitaReciente,
      diasSinVisita: diasSinVisita ?? this.diasSinVisita,
      assignedMercaderistaId: assignedMercaderistaId ?? this.assignedMercaderistaId,
      conMercaderistaAsignado: conMercaderistaAsignado ?? this.conMercaderistaAsignado,
    );
  }

  bool get hasFilters =>
      search != null ||
      sedeApp != null ||
      apiSedeCode != null ||
      ciudad != null ||
      activo != null ||
      sinVisitaReciente == true ||
      assignedMercaderistaId != null ||
      conMercaderistaAsignado != null;
}

/// Repositorio de clientes
class ClientRepository {
  final SupabaseClient _client;
  final ExternalClientApiService _externalApi;

  ClientRepository({
    SupabaseClient? client,
    ExternalClientApiService? externalApi,
  })  : _client = client ?? Supabase.instance.client,
        _externalApi = externalApi ?? ExternalClientApiService();

  /// Obtiene clientes desde Supabase con filtros
  Future<List<Client>> getClients({
    required AppUser requestingUser,
    ClientFilters? filters,
    int? limit,
    int? offset,
  }) async {
    var query = _client.from('clients').select();

    // Filtrar por sede según el rol del usuario
    if (!requestingUser.role.canViewAllSedes) {
      // Supervisor y mercaderista solo ven clientes de su sede
      final userSedeApp = requestingUser.sede?.value;
      if (userSedeApp != null) {
        query = query.eq('sede_app', userSedeApp);
      }
    }

    // Aplicar filtros adicionales
    if (filters != null) {
      if (filters.sedeApp != null) {
        query = query.eq('sede_app', filters.sedeApp!);
      }
      if (filters.apiSedeCode != null) {
        query = query.eq('api_sede_codigo', filters.apiSedeCode!);
      }
      if (filters.ciudad != null && filters.ciudad!.isNotEmpty) {
        query = query.ilike('ciudad', '%${filters.ciudad}%');
      }
      if (filters.activo != null) {
        query = query.eq('inactivo', !filters.activo!);
      }
      if (filters.assignedMercaderistaId != null) {
        query = query.eq('assigned_mercaderista_id', filters.assignedMercaderistaId!);
      }
      if (filters.conMercaderistaAsignado == true) {
        query = query.not('assigned_mercaderista_id', 'is', null);
      } else if (filters.conMercaderistaAsignado == false) {
        query = query.isFilter('assigned_mercaderista_id', null);
      }
      if (filters.sinVisitaReciente == true && filters.diasSinVisita != null) {
        final fechaLimite = DateTime.now().subtract(Duration(days: filters.diasSinVisita!));
        query = query.or('last_visit_at.is.null,last_visit_at.lt.${fechaLimite.toIso8601String()}');
      }
      if (filters.search != null && filters.search!.isNotEmpty) {
        query = query.or(
          'cli_des.ilike.%${filters.search}%,'
          'rif.ilike.%${filters.search}%,'
          'ciudad.ilike.%${filters.search}%,'
          'direc1.ilike.%${filters.search}%,'
          'dir_ent2.ilike.%${filters.search}%'
        );
      }
    }

    // Ordenar y paginar
    final orderedQuery = query.order('cli_des', ascending: true);
    
    final limitedQuery = limit != null ? orderedQuery.limit(limit) : orderedQuery;
    
    final finalQuery = offset != null 
        ? limitedQuery.range(offset, offset + (limit ?? 50) - 1) 
        : limitedQuery;

    final response = await finalQuery;
    return (response as List).map((json) => Client.fromJson(json)).toList();
  }

  /// Obtiene un cliente por su código
  Future<Client?> getClientByCoCli(String coCli) async {
    final response = await _client
        .from('clients')
        .select()
        .eq('co_cli', coCli)
        .maybeSingle();
    
    if (response == null) return null;
    return Client.fromJson(response);
  }

  /// Crea un nuevo cliente
  Future<Client> createClient({
    required String coCli,
    required String cliDes,
    required String sedeApp,
    String? ciudad,
    String? direc1,
    String? telefonos,
    String? rif,
    String? email,
    String? respons,
    int? apiSedecodigo,
  }) async {
    final data = {
      'co_cli': coCli,
      'cli_des': cliDes,
      'sede_app': sedeApp,
      'ciudad': ciudad,
      'direc1': direc1,
      'telefonos': telefonos,
      'rif': rif,
      'email': email,
      'respons': respons,
      'api_sede_codigo': apiSedecodigo,
      'inactivo': false,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    final response = await _client
        .from('clients')
        .insert(data)
        .select()
        .single();
    
    return Client.fromJson(response);
  }

  /// Actualiza un cliente existente
  Future<Client> updateClient({
    required String coCli,
    String? cliDes,
    String? ciudad,
    String? direc1,
    String? telefonos,
    String? rif,
    String? email,
    String? respons,
    bool? inactivo,
  }) async {
    final data = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    
    if (cliDes != null) data['cli_des'] = cliDes;
    if (ciudad != null) data['ciudad'] = ciudad;
    if (direc1 != null) data['direc1'] = direc1;
    if (telefonos != null) data['telefonos'] = telefonos;
    if (rif != null) data['rif'] = rif;
    if (email != null) data['email'] = email;
    if (respons != null) data['respons'] = respons;
    if (inactivo != null) data['inactivo'] = inactivo;

    final response = await _client
        .from('clients')
        .update(data)
        .eq('co_cli', coCli)
        .select()
        .single();
    
    return Client.fromJson(response);
  }

  /// Cambia el estado activo/inactivo de un cliente
  Future<void> toggleClientStatus(String coCli, bool inactivo) async {
    await _client
        .from('clients')
        .update({
          'inactivo': inactivo,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('co_cli', coCli);
  }

  /// Obtiene las ciudades disponibles para filtros
  Future<List<String>> getCiudadesDisponibles({String? sedeApp}) async {
    var query = _client.from('clients').select('ciudad');
    
    if (sedeApp != null) {
      query = query.eq('sede_app', sedeApp);
    }
    
    final response = await query;
    final ciudades = (response as List)
        .map((r) => r['ciudad'] as String?)
        .where((c) => c != null && c.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();
    ciudades.sort();
    return ciudades;
  }

  /// Obtiene las sedes de la API
  Future<List<ApiSede>> getApiSedes() async {
    final response = await _client
        .from('api_sedes')
        .select()
        .order('codigo');
    
    return (response as List).map((json) => ApiSede.fromJson(json)).toList();
  }

  /// Obtiene estadísticas de clientes
  Future<Map<String, dynamic>> getClientStats({
    required AppUser requestingUser,
    String? sedeApp,
  }) async {
    final sedeFilter = !requestingUser.role.canViewAllSedes
        ? requestingUser.sede?.value
        : sedeApp;

    var query = _client.from('clients').select('co_cli, inactivo, last_visit_at, assigned_mercaderista_id');
    
    if (sedeFilter != null) {
      query = query.eq('sede_app', sedeFilter);
    }

    final response = await query;
    final clients = response as List;

    final total = clients.length;
    final activos = clients.where((c) => c['inactivo'] != true).length;
    final inactivos = clients.where((c) => c['inactivo'] == true).length;
    final conMercaderista = clients.where((c) => c['assigned_mercaderista_id'] != null).length;
    
    final ahora = DateTime.now();
    final hace7Dias = ahora.subtract(const Duration(days: 7));
    final visitadosReciente = clients.where((c) {
      final lastVisit = c['last_visit_at'];
      if (lastVisit == null) return false;
      return DateTime.parse(lastVisit).isAfter(hace7Dias);
    }).length;

    final sinVisitar = clients.where((c) => c['last_visit_at'] == null).length;

    return {
      'total': total,
      'activos': activos,
      'inactivos': inactivos,
      'con_mercaderista': conMercaderista,
      'sin_mercaderista': total - conMercaderista,
      'visitados_7_dias': visitadosReciente,
      'sin_visitar': sinVisitar,
    };
  }

  /// Sincroniza clientes desde la API externa
  Future<SyncResult> syncClientsFromApi({
    List<int>? sedeCodes,
    void Function(int current, int total, String message)? onProgress,
  }) async {
    int inserted = 0;
    int updated = 0;
    int errors = 0;
    final errorMessages = <String>[];

    try {
      // Obtener sedes si no se especificaron
      final codes = sedeCodes ?? ExternalClientApiService.sedeMapping.keys.toList();
      
      for (var i = 0; i < codes.length; i++) {
        final code = codes[i];
        final sedeName = ExternalClientApiService.getSedeNameByCode(code);
        onProgress?.call(i + 1, codes.length, 'Sincronizando $sedeName...');
        
        try {
          final clients = await _externalApi.getClientesBySede(code);
          
          for (final client in clients) {
            try {
              // Intentar upsert
              await _client.from('clients').upsert(
                client.toJson(),
                onConflict: 'co_cli',
              );
              
              // Verificar si es insert o update
              final existing = await _client
                  .from('clients')
                  .select('synced_at')
                  .eq('co_cli', client.coCli)
                  .maybeSingle();
              
              if (existing != null && existing['synced_at'] != null) {
                updated++;
              } else {
                inserted++;
              }
            } catch (e) {
              errors++;
              if (errorMessages.length < 10) {
                errorMessages.add('${client.coCli}: $e');
              }
            }
          }
        } catch (e) {
          errors++;
          errorMessages.add('Sede $code: $e');
        }
      }

      // Actualizar timestamps de sedes
      await _updateApiSedesTimestamps();

    } catch (e) {
      errorMessages.add('Error general: $e');
    }

    return SyncResult(
      inserted: inserted,
      updated: updated,
      errors: errors,
      errorMessages: errorMessages,
    );
  }

  /// Actualiza los timestamps de las sedes
  Future<void> _updateApiSedesTimestamps() async {
    try {
      final sedes = await _externalApi.getSedes();
      for (final sede in sedes) {
        await _client.from('api_sedes').upsert({
          'codigo': sede.codigo,
          'nombre': sede.nombre,
          'sede_app': sede.sedeApp,
          'total_clientes': sede.totalClientes,
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'codigo');
      }
    } catch (e) {
      print('Error actualizando sedes: $e');
    }
  }

  /// Asigna un mercaderista a un cliente
  Future<void> assignMercaderista(String coCli, String? mercaderistaId) async {
    await _client.from('clients').update({
      'assigned_mercaderista_id': mercaderistaId,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('co_cli', coCli);
  }

  /// Actualiza notas de un cliente
  Future<void> updateClientNotes(String coCli, String? notes) async {
    await _client.from('clients').update({
      'notes': notes,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('co_cli', coCli);
  }

  /// Registra una visita a un cliente
  Future<ClientVisit> registerVisit({
    required String clientCoCli,
    required String mercaderistaId,
    double? latitude,
    double? longitude,
    String? notes,
    List<String>? photos,
  }) async {
    // Crear la visita
    final visitData = {
      'client_co_cli': clientCoCli,
      'mercaderista_id': mercaderistaId,
      'visited_at': DateTime.now().toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'notes': notes,
      'photos': photos,
    };

    final response = await _client
        .from('client_visits')
        .insert(visitData)
        .select()
        .single();

    // Actualizar last_visit_at y visit_count del cliente
    await _client.rpc('increment_client_visit', params: {
      'client_id': clientCoCli,
    }).catchError((_) async {
      // Si el RPC no existe, actualizar manualmente
      await _client.from('clients').update({
        'last_visit_at': DateTime.now().toIso8601String(),
        'visit_count': await _getVisitCount(clientCoCli),
      }).eq('co_cli', clientCoCli);
    });

    return ClientVisit.fromJson(response);
  }

  /// Obtiene el conteo de visitas de un cliente
  Future<int> _getVisitCount(String coCli) async {
    final response = await _client
        .from('client_visits')
        .select('id')
        .eq('client_co_cli', coCli);
    return (response as List).length;
  }

  /// Obtiene el historial de visitas de un cliente
  Future<List<ClientVisit>> getClientVisits(String coCli, {int? limit}) async {
    var query = _client
        .from('client_visits')
        .select()
        .eq('client_co_cli', coCli)
        .order('visited_at', ascending: false);
    
    if (limit != null) {
      query = query.limit(limit);
    }

    final response = await query;
    return (response as List).map((json) => ClientVisit.fromJson(json)).toList();
  }

  /// Obtiene las visitas de un mercaderista
  Future<List<ClientVisit>> getMercaderistaVisits(
    String mercaderistaId, {
    DateTime? desde,
    DateTime? hasta,
    int? limit,
  }) async {
    var filterQuery = _client
        .from('client_visits')
        .select()
        .eq('mercaderista_id', mercaderistaId);
    
    if (desde != null) {
      filterQuery = filterQuery.gte('visited_at', desde.toIso8601String());
    }
    if (hasta != null) {
      filterQuery = filterQuery.lte('visited_at', hasta.toIso8601String());
    }
    
    final orderedQuery = filterQuery.order('visited_at', ascending: false);
    final finalQuery = limit != null ? orderedQuery.limit(limit) : orderedQuery;

    final response = await finalQuery;
    return (response as List).map((json) => ClientVisit.fromJson(json)).toList();
  }
}

/// Resultado de sincronización
class SyncResult {
  final int inserted;
  final int updated;
  final int errors;
  final List<String> errorMessages;

  const SyncResult({
    required this.inserted,
    required this.updated,
    required this.errors,
    this.errorMessages = const [],
  });

  int get total => inserted + updated;
  bool get hasErrors => errors > 0;

  @override
  String toString() =>
      'SyncResult(inserted: $inserted, updated: $updated, errors: $errors)';
}
