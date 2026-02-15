import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../providers/reports_provider.dart';
import '../../../../core/models/report_models.dart';

/// Pantalla de reporte de analisis de eventos
class EventsReportScreen extends ConsumerWidget {
  const EventsReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(reportsFilterProvider);
    final eventsAsync = ref.watch(eventsStatsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analisis de Eventos'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Filter Chips ---
            _buildFilterChips(context, ref, filter),

            const SizedBox(height: 16),

            // --- KPI Cards ---
            eventsAsync.when(
              data: (stats) => _buildKpiCards(context, stats),
              loading: () => const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => _buildErrorCard(context, 'Error: $e'),
            ),

            const SizedBox(height: 24),

            // --- Events List with Attendance Bars ---
            eventsAsync.when(
              data: (stats) => _buildEventsList(context, stats),
              loading: () => const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) =>
                  _buildErrorCard(context, 'Error cargando eventos: $e'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips(
      BuildContext context, WidgetRef ref, ReportsFilter current) {
    final filters = <MapEntry<String, ReportsFilter>>[
      MapEntry('Hoy', ReportsFilter.today()),
      MapEntry('7d', ReportsFilter.last7Days()),
      MapEntry('30d', ReportsFilter.last30Days()),
      MapEntry('Este mes', ReportsFilter.thisMonth()),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((entry) {
          final isSelected = current.label == entry.value.label;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(entry.key),
              selected: isSelected,
              onSelected: (_) {
                ref.read(reportsFilterProvider.notifier).state = entry.value;
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildKpiCards(BuildContext context, EventsStats stats) {
    return Row(
      children: [
        Expanded(
          child: _KpiCard(
            title: 'Eventos',
            value: '${stats.totalEvents}',
            icon: Icons.event,
            color: Colors.purple,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _KpiCard(
            title: 'Check-ins',
            value: '${stats.totalCheckIns}',
            icon: Icons.check_circle,
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _KpiCard(
            title: 'Asistencia',
            value: '${(stats.attendanceRate * 100).toStringAsFixed(1)}%',
            icon: Icons.groups,
            color: Colors.blue,
          ),
        ),
      ],
    );
  }

  Widget _buildEventsList(BuildContext context, EventsStats stats) {
    final theme = Theme.of(context);

    if (stats.events.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'No hay eventos en el periodo seleccionado',
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Detalle de Eventos',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: stats.events.length,
          itemBuilder: (context, index) {
            final event = stats.events[index];
            final attendancePct = event.attendanceRate;
            final attendanceColor = attendancePct >= 0.8
                ? Colors.green
                : attendancePct >= 0.5
                    ? Colors.amber
                    : Colors.red;

            final startStr =
                '${event.startDate.day.toString().padLeft(2, '0')}/${event.startDate.month.toString().padLeft(2, '0')}';
            final endStr =
                '${event.endDate.day.toString().padLeft(2, '0')}/${event.endDate.month.toString().padLeft(2, '0')}';
            final statusInfo = _getEventStatusInfo(event.status);

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            event.name,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusInfo.color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            statusInfo.label,
                            style: TextStyle(
                              fontSize: 11,
                              color: statusInfo.color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          '$startStr - $endStr',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          'Asistencia: ${event.checkInCount}/${event.assignedCount}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(attendancePct * 100).toStringAsFixed(0)}%',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: attendanceColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: attendancePct,
                      backgroundColor: attendanceColor.withOpacity(0.15),
                      valueColor:
                          AlwaysStoppedAnimation<Color>(attendanceColor),
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  _StatusInfo _getEventStatusInfo(String status) {
    switch (status) {
      case 'planned':
        return _StatusInfo('Planificado', Colors.blue);
      case 'active':
        return _StatusInfo('Activo', Colors.green);
      case 'in_progress':
        return _StatusInfo('En curso', Colors.orange);
      case 'completed':
        return _StatusInfo('Finalizado', Colors.grey);
      case 'cancelled':
        return _StatusInfo('Cancelado', Colors.red);
      default:
        return _StatusInfo(status, Colors.grey);
    }
  }

  Widget _buildErrorCard(BuildContext context, String message) {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: Colors.red.shade700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusInfo {
  final String label;
  final Color color;
  const _StatusInfo(this.label, this.color);
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
