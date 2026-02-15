import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../providers/reports_provider.dart';
import '../../../../core/models/report_models.dart';

/// Pantalla de reporte de analisis de rutas
class RoutesReportScreen extends ConsumerWidget {
  const RoutesReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(reportsFilterProvider);
    final dashboardAsync = ref.watch(dashboardStatsProvider);
    final routeBreakdownAsync = ref.watch(routeBreakdownProvider);
    final routeHistoryAsync = ref.watch(routeHistoryProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analisis de Rutas'),
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
            dashboardAsync.when(
              data: (stats) => _buildKpiCards(context, stats),
              loading: () => const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => _buildErrorCard(context, 'Error: $e'),
            ),

            const SizedBox(height: 24),

            // --- Bar Chart by Status ---
            routeHistoryAsync.when(
              data: (routes) => _buildStatusBarChart(context, routes),
              loading: () => const SizedBox(
                height: 240,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => _buildErrorCard(context, 'Error cargando rutas: $e'),
            ),

            const SizedBox(height: 24),

            // --- Pie Chart by Type ---
            routeBreakdownAsync.when(
              data: (breakdown) => _buildTypePieChart(context, breakdown),
              loading: () => const SizedBox(
                height: 240,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => _buildErrorCard(context, 'Error cargando tipos: $e'),
            ),

            const SizedBox(height: 24),

            // --- Route History List ---
            routeHistoryAsync.when(
              data: (routes) => _buildRouteHistoryList(context, routes),
              loading: () => const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => _buildErrorCard(context, 'Error: $e'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips(
      BuildContext context, WidgetRef ref, ReportsFilter current) {
    final currentSede = current.sede;
    final filters = <MapEntry<String, ReportsFilter>>[
      MapEntry('Hoy', ReportsFilter.today().copyWith(sede: currentSede)),
      MapEntry('7d', ReportsFilter.last7Days().copyWith(sede: currentSede)),
      MapEntry('30d', ReportsFilter.last30Days().copyWith(sede: currentSede)),
      MapEntry('Este mes', ReportsFilter.thisMonth().copyWith(sede: currentSede)),
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

  Widget _buildKpiCards(BuildContext context, DashboardStats stats) {
    final completionColor = stats.completionRate >= 0.7
        ? Colors.green
        : stats.completionRate >= 0.4
            ? Colors.amber
            : Colors.red;

    return Row(
      children: [
        Expanded(
          child: _KpiCard(
            title: 'Completitud',
            value: '${(stats.completionRate * 100).toStringAsFixed(1)}%',
            icon: Icons.pie_chart,
            color: completionColor,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _KpiCard(
            title: 'Promedio',
            value: stats.avgClientsPerRoute.toStringAsFixed(1),
            icon: Icons.people_outline,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _KpiCard(
            title: 'Total',
            value: '${stats.totalRoutes}',
            icon: Icons.route,
            color: Colors.deepPurple,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBarChart(
      BuildContext context, List<RouteHistoryItem> routes) {
    final theme = Theme.of(context);

    int planned = 0;
    int inProgress = 0;
    int completed = 0;
    int cancelled = 0;

    for (final route in routes) {
      switch (route.status) {
        case 'planned':
          planned++;
          break;
        case 'in_progress':
          inProgress++;
          break;
        case 'completed':
          completed++;
          break;
        case 'cancelled':
          cancelled++;
          break;
      }
    }

    final maxY = [planned, inProgress, completed, cancelled]
        .reduce((a, b) => a > b ? a : b)
        .toDouble();

    if (maxY == 0) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'No hay rutas en el periodo seleccionado',
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rutas por Estado',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY * 1.2,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final labels = [
                          'Planificadas',
                          'En progreso',
                          'Completadas',
                          'Canceladas',
                        ];
                        return BarTooltipItem(
                          '${labels[groupIndex]}\n${rod.toY.toInt()}',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          const labels = ['Plan', 'Prog', 'Comp', 'Canc'];
                          final idx = value.toInt();
                          if (idx < 0 || idx >= labels.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              labels[idx],
                              style: const TextStyle(fontSize: 11),
                            ),
                          );
                        },
                        reservedSize: 30,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (value, meta) {
                          if (value == value.roundToDouble()) {
                            return Text(
                              '${value.toInt()}',
                              style: const TextStyle(fontSize: 11),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: (maxY / 4).ceilToDouble().clamp(1, double.infinity),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: [
                    _makeBarGroup(0, planned.toDouble(), Colors.blue),
                    _makeBarGroup(1, inProgress.toDouble(), Colors.orange),
                    _makeBarGroup(2, completed.toDouble(), Colors.green),
                    _makeBarGroup(3, cancelled.toDouble(), Colors.red),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  BarChartGroupData _makeBarGroup(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 28,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(4),
          ),
        ),
      ],
    );
  }

  Widget _buildTypePieChart(BuildContext context, RouteTypeBreakdown breakdown) {
    final theme = Theme.of(context);

    if (breakdown.byType.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'No hay datos de tipos de ruta',
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
          ),
        ),
      );
    }

    final sections = breakdown.byType.map((typeStat) {
      final color =
          Color(int.parse(typeStat.color.replaceFirst('#', '0xFF')));
      return PieChartSectionData(
        value: typeStat.total.toDouble(),
        title: '${typeStat.total}',
        color: color,
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Por Tipo de Ruta',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  centerSpaceRadius: 40,
                  sectionsSpace: 2,
                  startDegreeOffset: -90,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: breakdown.byType.map((typeStat) {
                final color = Color(
                    int.parse(typeStat.color.replaceFirst('#', '0xFF')));
                return _LegendItem(color: color, label: typeStat.typeName);
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteHistoryList(
      BuildContext context, List<RouteHistoryItem> routes) {
    final theme = Theme.of(context);

    if (routes.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'No hay rutas en el periodo seleccionado',
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
          'Historial de Rutas',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: routes.length,
          itemBuilder: (context, index) {
            final route = routes[index];
            final typeColor = Color(
                int.parse(route.routeTypeColor.replaceFirst('#', '0xFF')));
            final statusInfo = _getStatusInfo(route.status);
            final dateStr =
                '${route.scheduledDate.day.toString().padLeft(2, '0')}/${route.scheduledDate.month.toString().padLeft(2, '0')}';
            final completionPct = route.completionRate;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          dateStr,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: typeColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            route.routeTypeName,
                            style: TextStyle(
                              fontSize: 11,
                              color: typeColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
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
                    const SizedBox(height: 8),
                    Text(
                      route.name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      route.mercaderistaName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: LinearProgressIndicator(
                            value: completionPct,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              completionPct >= 0.7
                                  ? Colors.green
                                  : completionPct >= 0.4
                                      ? Colors.amber
                                      : Colors.red,
                            ),
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${route.completedClients}/${route.totalClients}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
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

  _StatusInfo _getStatusInfo(String status) {
    switch (status) {
      case 'planned':
        return _StatusInfo('Planificada', Colors.blue);
      case 'in_progress':
        return _StatusInfo('En progreso', Colors.orange);
      case 'completed':
        return _StatusInfo('Completada', Colors.green);
      case 'cancelled':
        return _StatusInfo('Cancelada', Colors.red);
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

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
