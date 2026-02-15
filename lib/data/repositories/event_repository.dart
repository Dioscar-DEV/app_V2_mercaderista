import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/models/event.dart';
import '../../core/models/event_check_in.dart';
import '../../core/models/route_form_question.dart';
import '../../core/models/user.dart';
import '../../core/enums/user_role.dart';

/// Repositorio de eventos (Supabase)
class EventRepository {
  final SupabaseClient _client;

  EventRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  // ========================
  // EVENTOS (CRUD)
  // ========================

  /// Obtiene eventos con filtros según rol del usuario
  Future<List<AppEvent>> getEvents({
    required AppUser requestingUser,
    String? status,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    var query = _client.from('events').select('''
      *,
      route_types(*),
      event_mercaderistas(*, users(full_name, email))
    ''');

    // Filtrar por sede según rol
    if (!requestingUser.role.canViewAllSedes) {
      final userSedeApp = requestingUser.sede?.value;
      if (userSedeApp != null) {
        query = query.eq('sede_app', userSedeApp);
      }
    }

    if (status != null) {
      query = query.eq('status', status);
    }
    if (dateFrom != null) {
      query = query.gte('start_date', dateFrom.toIso8601String().split('T')[0]);
    }
    if (dateTo != null) {
      query = query.lte('end_date', dateTo.toIso8601String().split('T')[0]);
    }

    final response = await query.order('start_date', ascending: false);
    return (response as List)
        .map((json) => AppEvent.fromJson(json))
        .toList();
  }

  /// Obtiene un evento por ID
  Future<AppEvent?> getEventById(String id) async {
    final response = await _client
        .from('events')
        .select('''
          *,
          route_types(*),
          event_mercaderistas(*, users(full_name, email))
        ''')
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return AppEvent.fromJson(response);
  }

  /// Crea un nuevo evento
  Future<AppEvent> createEvent(AppEvent event) async {
    final response = await _client
        .from('events')
        .insert(event.toInsertJson())
        .select()
        .single();

    return AppEvent.fromJson(response);
  }

  /// Actualiza un evento
  Future<AppEvent> updateEvent(AppEvent event) async {
    final response = await _client
        .from('events')
        .update({
          'name': event.name,
          'description': event.description,
          'route_type_id': event.routeTypeId,
          'location_name': event.locationName,
          'latitude': event.latitude,
          'longitude': event.longitude,
          'start_date': event.startDate.toIso8601String().split('T')[0],
          'end_date': event.endDate.toIso8601String().split('T')[0],
          'status': event.status.value,
          'notes': event.notes,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', event.id)
        .select()
        .single();

    return AppEvent.fromJson(response);
  }

  /// Elimina un evento
  Future<void> deleteEvent(String id) async {
    await _client.from('events').delete().eq('id', id);
  }

  // ========================
  // MERCADERISTAS EN EVENTO
  // ========================

  /// Asigna mercaderistas a un evento
  Future<void> assignMercaderistas({
    required String eventId,
    required List<String> mercaderistaIds,
  }) async {
    // Eliminar asignaciones previas
    await _client
        .from('event_mercaderistas')
        .delete()
        .eq('event_id', eventId);

    // Insertar nuevas asignaciones
    if (mercaderistaIds.isNotEmpty) {
      final rows = mercaderistaIds.map((id) => {
        'event_id': eventId,
        'mercaderista_id': id,
      }).toList();

      await _client.from('event_mercaderistas').insert(rows);
    }
  }

  /// Obtiene mercaderistas disponibles (activos) filtrados por sede
  Future<List<AppUser>> getAvailableMercaderistas({String? sedeApp}) async {
    var query = _client
        .from('users')
        .select()
        .eq('role', 'mercaderista')
        .eq('status', 'active');

    if (sedeApp != null) {
      query = query.eq('sede', sedeApp);
    }

    final response = await query.order('full_name');
    return (response as List)
        .map((json) => AppUser.fromJson(json))
        .toList();
  }

  // ========================
  // EVENTOS DEL MERCADERISTA
  // ========================

  /// Obtiene eventos asignados a un mercaderista para una fecha
  Future<List<AppEvent>> getMercaderistaEvents({
    required String mercaderistaId,
    required DateTime date,
  }) async {
    final dateStr = date.toIso8601String().split('T')[0];

    final response = await _client
        .from('events')
        .select('''
          *,
          route_types(*),
          event_mercaderistas(*, users(full_name, email))
        ''')
        .lte('start_date', dateStr)
        .gte('end_date', dateStr)
        .neq('status', 'cancelled');

    // Filtrar por mercaderista asignado
    final events = (response as List)
        .map((json) => AppEvent.fromJson(json))
        .where((event) => event.mercaderistas?.any(
              (m) => m.mercaderistaId == mercaderistaId,
            ) ??
            false)
        .toList();

    return events;
  }

  // ========================
  // CHECK-INS
  // ========================

  /// Crea un check-in
  Future<EventCheckIn> createCheckIn(EventCheckIn checkIn) async {
    final response = await _client
        .from('event_check_ins')
        .insert(checkIn.toInsertJson())
        .select()
        .single();

    return EventCheckIn.fromJson(response);
  }

  /// Completa un check-in (actualiza completed_at y observations)
  Future<EventCheckIn> completeCheckIn({
    required String checkInId,
    String? observations,
  }) async {
    final response = await _client
        .from('event_check_ins')
        .update({
          'completed_at': DateTime.now().toIso8601String(),
          'observations': observations,
        })
        .eq('id', checkInId)
        .select()
        .single();

    return EventCheckIn.fromJson(response);
  }

  /// Guarda respuestas del formulario de check-in
  Future<void> saveCheckInAnswers(List<EventCheckInAnswer> answers) async {
    if (answers.isEmpty) return;

    final rows = answers.map((a) => a.toInsertJson()).toList();
    await _client.from('event_check_in_answers').insert(rows);
  }

  /// Obtiene check-ins de un evento (admin view)
  Future<List<EventCheckIn>> getCheckInsForEvent(String eventId) async {
    final response = await _client
        .from('event_check_ins')
        .select('''
          *,
          users(full_name),
          event_check_in_answers(*)
        ''')
        .eq('event_id', eventId)
        .order('check_in_date', ascending: false);

    return (response as List)
        .map((json) => EventCheckIn.fromJson(json))
        .toList();
  }

  /// Obtiene check-in de un mercaderista para un evento y fecha
  Future<EventCheckIn?> getCheckIn({
    required String eventId,
    required String mercaderistaId,
    required DateTime date,
  }) async {
    final dateStr = date.toIso8601String().split('T')[0];

    final response = await _client
        .from('event_check_ins')
        .select('*, event_check_in_answers(*)')
        .eq('event_id', eventId)
        .eq('mercaderista_id', mercaderistaId)
        .eq('check_in_date', dateStr)
        .maybeSingle();

    if (response == null) return null;
    return EventCheckIn.fromJson(response);
  }

  /// Obtiene preguntas del formulario para un tipo de ruta (reutiliza route_form_questions)
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

  /// Descarga evento completo para uso offline
  Future<Map<String, dynamic>> getEventForOffline(String eventId) async {
    final event = await getEventById(eventId);
    if (event == null) throw Exception('Evento no encontrado');

    List<RouteFormQuestion> questions = [];
    if (event.routeTypeId != null) {
      questions = await getFormQuestions(event.routeTypeId!);
    }

    return {
      'event': event,
      'questions': questions,
    };
  }
}
