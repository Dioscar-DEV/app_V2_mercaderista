import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/enums/event_status.dart';
import '../../core/models/event.dart';
import '../../core/models/event_check_in.dart';
import '../../core/models/route_form_question.dart';
import '../../core/models/user.dart';
import '../../data/repositories/event_repository.dart';
import '../../data/repositories/offline_first_event_repository.dart';
import 'auth_provider.dart';

/// Provider del repositorio de eventos (Supabase directo)
final eventRepositoryProvider = Provider<EventRepository>((ref) {
  return EventRepository();
});

/// Provider del repositorio offline-first de eventos
final offlineEventRepositoryProvider = Provider<OfflineFirstEventRepository>((ref) {
  return OfflineFirstEventRepository();
});

/// Lista de eventos para admin (auto-actualiza status a in_progress si estamos en fecha)
final eventsProvider = FutureProvider.family<List<AppEvent>, AppUser>((ref, user) async {
  final repo = ref.watch(eventRepositoryProvider);
  final events = await repo.getEvents(requestingUser: user);

  // Auto-actualizar estados de eventos
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  bool hadChanges = false;

  for (final event in events) {
    // planned → in_progress si estamos dentro del rango de fechas
    if (event.status == EventStatus.planned && event.includesDate(now)) {
      try {
        await repo.updateEvent(event.copyWith(status: EventStatus.inProgress));
        hadChanges = true;
      } catch (e) {
        debugPrint('[Events] Error auto-updating to in_progress: $e');
      }
    }
    // in_progress → completed si ya pasó la fecha fin
    final endDate = DateTime(event.endDate.year, event.endDate.month, event.endDate.day);
    if (event.status == EventStatus.inProgress && today.isAfter(endDate)) {
      try {
        await repo.updateEvent(event.copyWith(status: EventStatus.completed));
        hadChanges = true;
      } catch (e) {
        debugPrint('[Events] Error auto-updating to completed: $e');
      }
    }
  }

  // Re-cargar si hubo cambios
  if (hadChanges) {
    return repo.getEvents(requestingUser: user);
  }

  return events;
});

/// Evento por ID
final eventByIdProvider = FutureProvider.family<AppEvent?, String>((ref, id) async {
  final repo = ref.watch(eventRepositoryProvider);
  return repo.getEventById(id);
});

/// Eventos del mercaderista para hoy (offline-first)
final mercaderistaEventsProvider = FutureProvider<List<AppEvent>>((ref) async {
  final userAsync = ref.watch(currentUserProvider);
  final user = userAsync.valueOrNull;
  if (user == null) return [];

  final repo = ref.watch(offlineEventRepositoryProvider);
  return repo.getMercaderistaEvents(
    mercaderistaId: user.id,
    date: DateTime.now(),
  );
});

/// Mercaderistas disponibles para asignar a evento
final availableMercaderistasProvider =
    FutureProvider.family<List<AppUser>, String?>((ref, sedeApp) async {
  final repo = ref.watch(eventRepositoryProvider);
  return repo.getAvailableMercaderistas(sedeApp: sedeApp);
});

/// Preguntas del formulario para un tipo de ruta (offline-first)
final eventFormQuestionsProvider =
    FutureProvider.family<List<RouteFormQuestion>, String>((ref, routeTypeId) async {
  final repo = ref.watch(offlineEventRepositoryProvider);
  return repo.getFormQuestions(routeTypeId);
});

/// Check-ins de un evento (admin view)
final eventCheckInsProvider =
    FutureProvider.family<List<EventCheckIn>, String>((ref, eventId) async {
  final repo = ref.watch(eventRepositoryProvider);
  return repo.getCheckInsForEvent(eventId);
});

/// Verifica si el mercaderista actual ya hizo check-in hoy para un evento
final eventTodayCheckInProvider =
    FutureProvider.family<bool, String>((ref, eventId) async {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) return false;
  final repo = ref.watch(offlineEventRepositoryProvider);
  final checkIn = await repo.getCheckIn(
    eventId: eventId,
    mercaderistaId: user.id,
    date: DateTime.now(),
  );
  return checkIn != null;
});

/// Estado del check-in del mercaderista actual
class EventCheckInState {
  final bool isLoading;
  final String? error;
  final EventCheckIn? checkIn;
  final bool isCompleted;

  const EventCheckInState({
    this.isLoading = false,
    this.error,
    this.checkIn,
    this.isCompleted = false,
  });

  EventCheckInState copyWith({
    bool? isLoading,
    String? error,
    EventCheckIn? checkIn,
    bool? isCompleted,
  }) {
    return EventCheckInState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      checkIn: checkIn ?? this.checkIn,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

/// Notifier para gestionar check-in de evento
class EventCheckInNotifier extends StateNotifier<EventCheckInState> {
  final OfflineFirstEventRepository _offlineRepo;

  EventCheckInNotifier(this._offlineRepo) : super(const EventCheckInState());

  /// Carga check-in existente para un evento y fecha
  Future<void> loadCheckIn({
    required String eventId,
    required String mercaderistaId,
    required DateTime date,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final checkIn = await _offlineRepo.getCheckIn(
        eventId: eventId,
        mercaderistaId: mercaderistaId,
        date: date,
      );
      state = state.copyWith(
        isLoading: false,
        checkIn: checkIn,
        isCompleted: checkIn?.isCompleted ?? false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Envía un check-in con formulario
  Future<bool> submitCheckIn({
    required String eventId,
    required String mercaderistaId,
    required DateTime date,
    required double latitude,
    required double longitude,
    String? observations,
    List<EventCheckInAnswer> answers = const [],
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final checkIn = EventCheckIn(
        id: '',
        eventId: eventId,
        mercaderistaId: mercaderistaId,
        checkInDate: date,
        startedAt: DateTime.now(),
        completedAt: DateTime.now(),
        latitude: latitude,
        longitude: longitude,
        observations: observations,
        createdAt: DateTime.now(),
      );

      final result = await _offlineRepo.submitCheckIn(
        checkIn: checkIn,
        answers: answers,
      );

      state = state.copyWith(
        isLoading: false,
        checkIn: result,
        isCompleted: true,
      );

      return true;
    } catch (e) {
      debugPrint('[EventCheckIn] Error: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }
}

/// Provider del notifier de check-in
final eventCheckInNotifierProvider =
    StateNotifierProvider<EventCheckInNotifier, EventCheckInState>((ref) {
  final offlineRepo = ref.watch(offlineEventRepositoryProvider);
  return EventCheckInNotifier(offlineRepo);
});
