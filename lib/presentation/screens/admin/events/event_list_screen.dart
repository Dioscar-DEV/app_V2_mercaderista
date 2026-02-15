import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/enums/event_status.dart';
import '../../../../core/models/event.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/event_provider.dart';

/// Pantalla de lista de eventos (admin)
class EventListScreen extends ConsumerStatefulWidget {
  const EventListScreen({super.key});

  @override
  ConsumerState<EventListScreen> createState() => _EventListScreenState();
}

class _EventListScreenState extends ConsumerState<EventListScreen> {
  String _statusFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Eventos'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/admin/events/create'),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Evento'),
      ),
      body: userAsync.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('Usuario no encontrado'));
          }

          final eventsAsync = ref.watch(eventsProvider(user));

          return Column(
            children: [
              // Filtros
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    _buildFilterChip('Todos', 'all'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Planificados', 'planned'),
                    const SizedBox(width: 8),
                    _buildFilterChip('En Progreso', 'in_progress'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Completados', 'completed'),
                  ],
                ),
              ),

              // Lista
              Expanded(
                child: eventsAsync.when(
                  data: (events) {
                    final filtered = _statusFilter == 'all'
                        ? events
                        : events.where((e) => e.status.value == _statusFilter).toList();

                    if (filtered.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.event, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'No hay eventos',
                              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(eventsProvider(user));
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) =>
                            _EventCard(event: filtered[index]),
                      ),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _statusFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() => _statusFilter = value);
      },
    );
  }
}

/// Tarjeta de evento
class _EventCard extends StatelessWidget {
  final AppEvent event;

  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(event.status);
    final mercCount = event.mercaderistas?.length ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/admin/events/${event.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado: nombre + status
              Row(
                children: [
                  Expanded(
                    child: Text(
                      event.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      event.status.displayName,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Fechas
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    _formatDateRange(event.startDate, event.endDate),
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '(${event.totalDays} día${event.totalDays > 1 ? 's' : ''})',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ],
              ),

              // Ubicación
              if (event.locationName != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        event.locationName!,
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 8),

              // Mercaderistas
              Row(
                children: [
                  Icon(Icons.people, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '$mercCount mercaderista${mercCount != 1 ? 's' : ''} asignado${mercCount != 1 ? 's' : ''}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ],
              ),

              // Nombres de mercaderistas
              if (event.mercaderistas != null && event.mercaderistas!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: event.mercaderistas!
                      .take(5)
                      .map((m) => Chip(
                            label: Text(
                              m.mercaderistaName ?? 'Sin nombre',
                              style: const TextStyle(fontSize: 11),
                            ),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
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

  String _formatDateRange(DateTime start, DateTime end) {
    final s = '${start.day}/${start.month}/${start.year}';
    final e = '${end.day}/${end.month}/${end.year}';
    if (s == e) return s;
    return '$s - $e';
  }
}
