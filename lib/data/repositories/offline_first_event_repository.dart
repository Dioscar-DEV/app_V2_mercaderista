import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../../core/models/event.dart';
import '../../core/models/event_check_in.dart';
import '../../core/models/route_form_question.dart';
import '../local/database_service.dart';
import 'event_repository.dart';

/// Repositorio offline-first para eventos
class OfflineFirstEventRepository {
  final EventRepository _remoteRepository;
  final DatabaseService _localDb;
  final Connectivity _connectivity;

  bool _isOnline = true;

  OfflineFirstEventRepository({
    EventRepository? remoteRepository,
    DatabaseService? localDb,
    Connectivity? connectivity,
  })  : _remoteRepository = remoteRepository ?? EventRepository(),
        _localDb = localDb ?? DatabaseService(),
        _connectivity = connectivity ?? Connectivity();

  Future<void> _checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _isOnline = result == ConnectivityResult.wifi ||
          result == ConnectivityResult.mobile ||
          result == ConnectivityResult.ethernet;
    } catch (_) {
      _isOnline = false;
    }
  }

  bool get isOnline => _isOnline;

  // ========================
  // EVENTOS DEL MERCADERISTA (OFFLINE-FIRST)
  // ========================

  /// Obtiene eventos del mercaderista para una fecha
  Future<List<AppEvent>> getMercaderistaEvents({
    required String mercaderistaId,
    required DateTime date,
  }) async {
    await _checkConnectivity();
    final dateStr = date.toIso8601String().split('T')[0];

    if (_isOnline) {
      try {
        final events = await _remoteRepository.getMercaderistaEvents(
          mercaderistaId: mercaderistaId,
          date: date,
        );

        // Guardar en local para offline
        for (final event in events) {
          await _localDb.saveEvent(event.toJson());
          if (event.mercaderistas != null) {
            for (final m in event.mercaderistas!) {
              await _localDb.saveEventMercaderista({
                'id': m.id,
                'event_id': m.eventId,
                'mercaderista_id': m.mercaderistaId,
                'mercaderista_name': m.mercaderistaName,
                'created_at': m.createdAt.toIso8601String(),
              });
            }
          }
        }

        return events;
      } catch (e) {
        debugPrint('[OfflineEvents] Error fetching remote: $e');
        if (e is SocketException) _isOnline = false;
      }
    }

    // Fallback: local
    final localEvents = await _localDb.getEventsForDate(mercaderistaId, dateStr);
    return localEvents.map((json) => AppEvent.fromJson(json)).toList();
  }

  /// Descarga evento completo para uso offline
  Future<void> downloadEventForOffline(String eventId) async {
    await _checkConnectivity();
    if (!_isOnline) return;

    try {
      final data = await _remoteRepository.getEventForOffline(eventId);
      final event = data['event'] as AppEvent;
      final questions = data['questions'] as List<RouteFormQuestion>;

      // Guardar evento
      await _localDb.saveEvent(event.toJson());

      // Guardar mercaderistas
      if (event.mercaderistas != null) {
        for (final m in event.mercaderistas!) {
          await _localDb.saveEventMercaderista({
            'id': m.id,
            'event_id': m.eventId,
            'mercaderista_id': m.mercaderistaId,
            'mercaderista_name': m.mercaderistaName,
            'created_at': m.createdAt.toIso8601String(),
          });
        }
      }

      // Guardar preguntas del formulario
      if (questions.isNotEmpty) {
        await _localDb.saveFormQuestions(questions);
      }

      debugPrint('[OfflineEvents] Evento $eventId descargado para offline');
    } catch (e) {
      debugPrint('[OfflineEvents] Error downloading event: $e');
    }
  }

  // ========================
  // CHECK-IN (OFFLINE-FIRST)
  // ========================

  /// Crea un check-in (online o pending_sync)
  Future<EventCheckIn?> submitCheckIn({
    required EventCheckIn checkIn,
    required List<EventCheckInAnswer> answers,
  }) async {
    await _checkConnectivity();

    if (_isOnline) {
      try {
        final created = await _remoteRepository.createCheckIn(checkIn);

        // Guardar respuestas con el ID del check-in creado
        if (answers.isNotEmpty) {
          final answersWithId = answers
              .map((a) => EventCheckInAnswer(
                    id: a.id,
                    checkInId: created.id,
                    questionId: a.questionId,
                    answer: a.answer,
                    photoUrl: a.photoUrl,
                    createdAt: a.createdAt,
                  ))
              .toList();
          await _remoteRepository.saveCheckInAnswers(answersWithId);
        }

        // Guardar en local
        await _localDb.saveEventCheckIn({
          ...created.toJson(),
          'answers_json': jsonEncode(answers.map((a) => a.toInsertJson()).toList()),
          'is_synced': 1,
        });

        return created;
      } catch (e) {
        debugPrint('[OfflineEvents] Error submitting check-in online: $e');
        if (e is SocketException) _isOnline = false;
      }
    }

    // Offline: guardar en pending_sync
    final offlineId = 'offline_${DateTime.now().millisecondsSinceEpoch}';
    final data = {
      ...checkIn.toInsertJson(),
      'answers': answers.map((a) => a.toInsertJson()).toList(),
    };

    await _localDb.savePendingSync(
      tableName: 'event_check_ins',
      recordId: offlineId,
      operation: 'event_check_in',
      data: data,
    );

    // Guardar localmente para que se vea en la UI
    await _localDb.saveEventCheckIn({
      'id': offlineId,
      ...checkIn.toJson(),
      'answers_json': jsonEncode(answers.map((a) => a.toInsertJson()).toList()),
      'is_synced': 0,
    });

    debugPrint('[OfflineEvents] Check-in guardado offline: $offlineId');

    return checkIn.copyWith(id: offlineId);
  }

  /// Obtiene check-in del mercaderista para un evento y fecha
  Future<EventCheckIn?> getCheckIn({
    required String eventId,
    required String mercaderistaId,
    required DateTime date,
  }) async {
    await _checkConnectivity();

    if (_isOnline) {
      try {
        return await _remoteRepository.getCheckIn(
          eventId: eventId,
          mercaderistaId: mercaderistaId,
          date: date,
        );
      } catch (e) {
        debugPrint('[OfflineEvents] Error fetching check-in: $e');
      }
    }

    // Fallback: local
    final locals = await _localDb.getEventCheckIns(eventId, mercaderistaId);
    final dateStr = date.toIso8601String().split('T')[0];
    final match = locals.where((c) => c['check_in_date'] == dateStr);
    if (match.isEmpty) return null;
    return EventCheckIn.fromJson(match.first);
  }

  /// Obtiene preguntas del formulario (offline-first)
  Future<List<RouteFormQuestion>> getFormQuestions(String routeTypeId) async {
    await _checkConnectivity();

    if (_isOnline) {
      try {
        final questions = await _remoteRepository.getFormQuestions(routeTypeId);
        await _localDb.saveFormQuestions(questions);
        return questions;
      } catch (e) {
        debugPrint('[OfflineEvents] Error fetching questions: $e');
      }
    }

    return _localDb.getFormQuestionsByRouteType(routeTypeId);
  }
}
