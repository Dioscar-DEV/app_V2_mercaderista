import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/enums/event_status.dart';
import '../../../../core/models/event.dart';
import '../../../../core/models/event_check_in.dart';
import '../../../providers/event_provider.dart';

/// Pantalla de detalle de evento (admin)
class EventDetailScreen extends ConsumerWidget {
  final String eventId;

  const EventDetailScreen({super.key, required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(eventByIdProvider(eventId));
    final checkInsAsync = ref.watch(eventCheckInsProvider(eventId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del Evento'),
        actions: [
          eventAsync.whenOrNull(
                data: (event) {
                  if (event == null) return null;
                  if (!event.status.canBeEdited) return null;
                  return IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () =>
                        context.push('/admin/events/${event.id}/edit'),
                  );
                },
              ) ??
              const SizedBox.shrink(),
        ],
      ),
      body: eventAsync.when(
        data: (event) {
          if (event == null) {
            return const Center(child: Text('Evento no encontrado'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info del evento
                _buildInfoCard(context, event),
                const SizedBox(height: 16),

                // Mercaderistas asignados (con estado de check-in de hoy)
                checkInsAsync.when(
                  data: (checkIns) =>
                      _buildMercaderistasCard(context, event, checkIns),
                  loading: () =>
                      _buildMercaderistasCard(context, event, const []),
                  error: (_, __) =>
                      _buildMercaderistasCard(context, event, const []),
                ),
                const SizedBox(height: 16),

                // Check-ins por día (historial)
                Text(
                  'Historial de Check-ins',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                checkInsAsync.when(
                  data: (checkIns) => _buildCheckInsSection(context, event, checkIns),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('Error cargando check-ins: $e'),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, AppEvent event) {
    final statusColor = _getStatusColor(event.status);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    event.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    event.status.displayName,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (event.description != null) ...[
              const SizedBox(height: 8),
              Text(event.description!,
                  style: TextStyle(color: Colors.grey[600])),
            ],
            const Divider(height: 24),

            // Fechas
            _infoRow(Icons.calendar_today, 'Fechas',
                '${_formatDate(event.startDate)} - ${_formatDate(event.endDate)} (${event.totalDays} días)'),

            // Ubicación
            if (event.locationName != null)
              _infoRow(Icons.location_on, 'Ubicación', event.locationName!),

            // Coordenadas
            if (event.latitude != null)
              _infoRow(Icons.gps_fixed, 'GPS',
                  '${event.latitude!.toStringAsFixed(4)}, ${event.longitude!.toStringAsFixed(4)}'),

            // Tipo de formulario
            if (event.routeType != null)
              _infoRow(Icons.assignment, 'Formulario', event.routeType!.name),

            // Notas
            if (event.notes != null)
              _infoRow(Icons.notes, 'Notas', event.notes!),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildMercaderistasCard(
      BuildContext context, AppEvent event, List<EventCheckIn> checkIns) {
    final mercs = event.mercaderistas ?? [];
    final now = DateTime.now();
    final todayStr = '${now.day}/${now.month}/${now.year}';
    final isInDateRange = event.includesDate(now);

    // Check-ins de hoy
    final todayCheckIns = checkIns.where((ci) {
      final ciDate = ci.checkInDate;
      return ciDate.day == now.day &&
          ciDate.month == now.month &&
          ciDate.year == now.year;
    }).toList();

    // Set de IDs que ya hicieron check-in hoy
    final checkedInIds = todayCheckIns.map((ci) => ci.mercaderistaId).toSet();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Mercaderistas Asignados (${mercs.length})',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                if (isInDateRange && mercs.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: checkedInIds.length == mercs.length
                          ? Colors.green.withValues(alpha: 0.15)
                          : Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${checkedInIds.length}/${mercs.length} hoy',
                      style: TextStyle(
                        color: checkedInIds.length == mercs.length
                            ? Colors.green
                            : Colors.orange,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (mercs.isEmpty)
              Text('No hay mercaderistas asignados',
                  style: TextStyle(color: Colors.grey[600]))
            else
              ...mercs.map((m) {
                final hasCheckedIn = checkedInIds.contains(m.mercaderistaId);
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: isInDateRange
                        ? (hasCheckedIn
                            ? Colors.green
                            : Colors.red.withValues(alpha: 0.7))
                        : Colors.grey[400],
                    child: Icon(
                      isInDateRange
                          ? (hasCheckedIn ? Icons.check : Icons.close)
                          : Icons.person,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(m.mercaderistaName ?? 'Sin nombre'),
                  subtitle: m.mercaderistaEmail != null
                      ? Text(m.mercaderistaEmail!)
                      : null,
                  trailing: isInDateRange
                      ? Text(
                          hasCheckedIn ? 'Completado' : 'Pendiente',
                          style: TextStyle(
                            color: hasCheckedIn ? Colors.green : Colors.red,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        )
                      : null,
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckInsSection(
      BuildContext context, AppEvent event, List<EventCheckIn> checkIns) {
    if (checkIns.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.event_busy, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 8),
                Text('No hay check-ins aún',
                    style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          ),
        ),
      );
    }

    // Agrupar por fecha
    final byDate = <String, List<EventCheckIn>>{};
    for (final ci in checkIns) {
      final dateStr = _formatDate(ci.checkInDate);
      byDate.putIfAbsent(dateStr, () => []).add(ci);
    }

    return Column(
      children: byDate.entries.map((entry) {
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ExpansionTile(
            title: Text(
              entry.key,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text('${entry.value.length} check-in(s)'),
            children: entry.value.map((ci) {
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: ci.isCompleted ? Colors.green : Colors.orange,
                  child: Icon(
                    ci.isCompleted ? Icons.check : Icons.schedule,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                title: Text(ci.mercaderistaName ?? 'Mercaderista'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (ci.startedAt != null)
                      Text('Hora: ${_formatTime(ci.startedAt!)}'),
                    if (ci.observations != null && ci.observations!.isNotEmpty)
                      Text('Obs: ${ci.observations}'),
                    if (ci.answers != null && ci.answers!.isNotEmpty)
                      Text('${ci.answers!.length} respuesta(s)'),
                  ],
                ),
                isThreeLine: ci.observations != null,
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  Color _getStatusColor(EventStatus status) {
    switch (status) {
      case EventStatus.planned:
        return Colors.blue;
      case EventStatus.inProgress:
        return Colors.orange;
      case EventStatus.completed:
        return Colors.green;
      case EventStatus.cancelled:
        return Colors.red;
    }
  }

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  String _formatTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
