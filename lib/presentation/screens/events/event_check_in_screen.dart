import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/event.dart';
import '../../../core/models/event_check_in.dart';
import '../../../core/models/route_form_question.dart';
import '../../../core/models/route_visit.dart';
import '../../providers/auth_provider.dart';
import '../../providers/event_provider.dart';
import '../../widgets/route_visit_form.dart';

/// Pantalla de check-in de evento para mercaderista
class EventCheckInScreen extends ConsumerStatefulWidget {
  final String eventId;

  const EventCheckInScreen({super.key, required this.eventId});

  @override
  ConsumerState<EventCheckInScreen> createState() =>
      _EventCheckInScreenState();
}

class _EventCheckInScreenState extends ConsumerState<EventCheckInScreen> {
  bool _isLoadingEvent = true;
  AppEvent? _event;
  List<RouteFormQuestion> _questions = [];
  bool _hasCheckedInToday = false;
  EventCheckIn? _todayCheckIn;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final offlineRepo = ref.read(offlineEventRepositoryProvider);
      final repo = ref.read(eventRepositoryProvider);

      // Cargar evento
      final event = await repo.getEventById(widget.eventId);
      if (event == null || !mounted) return;

      // Cargar preguntas si tiene tipo de formulario
      List<RouteFormQuestion> questions = [];
      if (event.routeTypeId != null) {
        questions = await offlineRepo.getFormQuestions(event.routeTypeId!);
      }

      // Verificar si ya hizo check-in hoy
      final user = ref.read(currentUserProvider).valueOrNull;
      if (user != null) {
        final existingCheckIn = await offlineRepo.getCheckIn(
          eventId: widget.eventId,
          mercaderistaId: user.id,
          date: DateTime.now(),
        );
        if (mounted) {
          setState(() {
            _todayCheckIn = existingCheckIn;
            _hasCheckedInToday = existingCheckIn != null;
          });
        }
      }

      if (mounted) {
        setState(() {
          _event = event;
          _questions = questions;
          _isLoadingEvent = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingEvent = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingEvent) {
      return Scaffold(
        appBar: AppBar(title: const Text('Evento')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_event == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Evento')),
        body: const Center(child: Text('Evento no encontrado')),
      );
    }

    final event = _event!;
    final currentDay = event.currentDay;

    return Scaffold(
      appBar: AppBar(
        title: Text(event.name),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info del evento
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    if (event.locationName != null)
                      Row(
                        children: [
                          Icon(Icons.location_on,
                              size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(event.locationName!,
                                style: TextStyle(color: Colors.grey[600])),
                          ),
                        ],
                      ),
                    if (event.latitude != null && event.longitude != null) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _openInMaps(
                              event.latitude!, event.longitude!),
                          icon: const Icon(Icons.map, size: 18),
                          label: const Text('Abrir en Google Maps'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.teal,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          '${_formatDate(event.startDate)} - ${_formatDate(event.endDate)}',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    if (currentDay != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.teal.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Día $currentDay de ${event.totalDays}',
                          style: const TextStyle(
                            color: Colors.teal,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    if (event.notes != null && event.notes!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(event.notes!,
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: 13)),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Estado del check-in hoy
            if (_hasCheckedInToday) ...[
              Card(
                color: Colors.green[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Icon(Icons.check_circle,
                          color: Colors.green, size: 48),
                      const SizedBox(height: 8),
                      const Text(
                        'Check-in completado hoy',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      if (_todayCheckIn?.observations != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Observaciones: ${_todayCheckIn!.observations}',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ] else ...[
              // Formulario de check-in
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Realizar Check-in',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Al hacer check-in se capturará tu ubicación GPS actual.',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                      const SizedBox(height: 16),

                      // Si hay formulario, mostrar RouteVisitForm
                      if (_questions.isNotEmpty)
                        RouteVisitForm(
                          questions: _questions,
                          onComplete: (answers, photoUrls, observations) {
                            _submitCheckIn(
                              answers: answers,
                              observations: observations,
                            );
                          },
                        )
                      else
                        // Solo botón de check-in sin formulario
                        _SimpleCheckInForm(
                          onSubmit: (observations) {
                            _submitCheckIn(
                              answers: [],
                              observations: observations,
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _submitCheckIn({
    required List<RouteVisitAnswer> answers,
    String? observations,
  }) async {
    // Obtener GPS
    Position? position;
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.denied &&
          permission != LocationPermission.deniedForever) {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
      }
    } catch (_) {}

    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;

    // Convertir RouteVisitAnswers a EventCheckInAnswers
    final checkInAnswers = answers.map((a) {
      String? answerValue;
      if (a.answerText != null) {
        answerValue = a.answerText;
      } else if (a.answerNumber != null) {
        answerValue = a.answerNumber.toString();
      } else if (a.answerBoolean != null) {
        answerValue = a.answerBoolean.toString();
      } else if (a.answerOptions != null) {
        answerValue = a.answerOptions!.join(', ');
      }

      return EventCheckInAnswer(
        id: '',
        checkInId: '',
        questionId: a.questionId,
        answer: answerValue,
        photoUrl: a.answerPhotoUrls?.isNotEmpty == true
            ? a.answerPhotoUrls!.first
            : null,
        createdAt: DateTime.now(),
      );
    }).toList();

    final notifier = ref.read(eventCheckInNotifierProvider.notifier);
    final success = await notifier.submitCheckIn(
      eventId: widget.eventId,
      mercaderistaId: user.id,
      date: DateTime.now(),
      latitude: position?.latitude ?? 0.0,
      longitude: position?.longitude ?? 0.0,
      observations: observations,
      answers: checkInAnswers,
    );

    if (mounted) {
      if (success) {
        setState(() => _hasCheckedInToday = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Check-in completado'),
            backgroundColor: Colors.green,
          ),
        );
        // Invalidar providers
        ref.invalidate(mercaderistaEventsProvider);
      } else {
        final error = ref.read(eventCheckInNotifierProvider).error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${error ?? 'Desconocido'}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _openInMaps(double lat, double lng) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir Google Maps')),
      );
    }
  }

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';
}

/// Formulario simple de check-in (sin preguntas dinámicas)
class _SimpleCheckInForm extends StatefulWidget {
  final Function(String?) onSubmit;

  const _SimpleCheckInForm({required this.onSubmit});

  @override
  State<_SimpleCheckInForm> createState() => _SimpleCheckInFormState();
}

class _SimpleCheckInFormState extends State<_SimpleCheckInForm> {
  final _obsController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _obsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _obsController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Observaciones (opcional)',
            hintText: 'Escribe observaciones del día...',
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _isSubmitting
              ? null
              : () {
                  setState(() => _isSubmitting = true);
                  widget.onSubmit(
                    _obsController.text.trim().isNotEmpty
                        ? _obsController.text.trim()
                        : null,
                  );
                },
          icon: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_circle),
          label: const Text('Hacer Check-in'),
        ),
      ],
    );
  }
}
