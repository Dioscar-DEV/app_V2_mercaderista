import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../providers/reports_provider.dart';
import '../../../../core/models/report_models.dart';
import '../../../../core/enums/sede.dart';

/// Pantalla principal del módulo de reportes con KPIs, gráficas y acceso rápido.
class ReportsDashboardScreen extends ConsumerStatefulWidget {
  const ReportsDashboardScreen({super.key});

  @override
  ConsumerState<ReportsDashboardScreen> createState() =>
      _ReportsDashboardScreenState();
}

class _ReportsDashboardScreenState
    extends ConsumerState<ReportsDashboardScreen> {
  /// Convierte un string hexadecimal de color (e.g. "#FF5733" o "FF5733") a [Color].
  Color _parseColor(String hex) {
    String sanitized = hex.replaceAll('#', '');
    if (sanitized.length == 6) {
      sanitized = 'FF$sanitized';
    }
    return Color(int.parse(sanitized, radix: 16));
  }

  /// Devuelve la etiqueta y la factory correspondiente al índice del filtro.
  static const List<String> _filterLabels = [
    'Hoy',
    '7 días',
    '30 días',
    'Este mes',
  ];

  ReportsFilter _filterFromIndex(int index) {
    final currentSede = ref.read(reportsFilterProvider).sede;
    ReportsFilter base;
    switch (index) {
      case 0:
        base = ReportsFilter.today();
        break;
      case 1:
        base = ReportsFilter.last7Days();
        break;
      case 2:
        base = ReportsFilter.last30Days();
        break;
      case 3:
      default:
        base = ReportsFilter.thisMonth();
        break;
    }
    return base.copyWith(sede: currentSede);
  }

  int _selectedFilterIndex() {
    final current = ref.read(reportsFilterProvider);
    final label = current.label;
    final idx = _filterLabels.indexOf(label);
    return idx >= 0 ? idx : 3;
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    final trendsAsync = ref.watch(dailyTrendsProvider);
    final breakdownAsync = ref.watch(routeBreakdownProvider);
    final selectedIndex = _selectedFilterIndex();

    final isOwner = ref.watch(isOwnerProvider);
    final currentFilter = ref.watch(reportsFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Filter chips ──
            _buildFilterChips(selectedIndex),
            const SizedBox(height: 8),

            // ── Sede selector (solo para owner) ──
            if (isOwner) _buildSedeSelector(currentFilter),
            const SizedBox(height: 16),

            // ── KPIs Grid ──
            statsAsync.when(
              data: (stats) => _buildKpisGrid(stats),
              loading: () => const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => _buildErrorBox('Error cargando KPIs: $e'),
            ),
            const SizedBox(height: 16),

            // ── Line Chart: Tendencia ──
            trendsAsync.when(
              data: (trends) => _buildTrendChart(trends),
              loading: () => const SizedBox(
                height: 260,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) =>
                  _buildErrorBox('Error cargando tendencia: $e'),
            ),
            const SizedBox(height: 16),

            // ── Pie Chart: Distribución por Tipo ──
            breakdownAsync.when(
              data: (breakdown) => _buildPieChart(breakdown),
              loading: () => const SizedBox(
                height: 240,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) =>
                  _buildErrorBox('Error cargando distribución: $e'),
            ),
            const SizedBox(height: 16),

            // ── Quick access cards ──
            _buildQuickAccessGrid(),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────── Sede Selector ─────────────────────────────

  Widget _buildSedeSelector(ReportsFilter currentFilter) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          FilterChip(
            label: const Text('Todas las sedes'),
            selected: currentFilter.sede == null,
            showCheckmark: false,
            onSelected: (_) {
              ref.read(reportsFilterProvider.notifier).state =
                  currentFilter.copyWith(clearSede: true);
            },
          ),
          const SizedBox(width: 8),
          ...Sede.values.map((sede) {
            final isSelected = currentFilter.sede == sede.value;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(sede.displayName),
                selected: isSelected,
                showCheckmark: false,
                onSelected: (_) {
                  ref.read(reportsFilterProvider.notifier).state =
                      currentFilter.copyWith(sede: sede.value);
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  // ───────────────────────────── Filter Chips ─────────────────────────────

  Widget _buildFilterChips(int selectedIndex) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(_filterLabels.length, (index) {
          final isSelected = index == selectedIndex;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(_filterLabels[index]),
              selected: isSelected,
              showCheckmark: false,
              onSelected: (_) {
                ref.read(reportsFilterProvider.notifier).state =
                    _filterFromIndex(index);
              },
            ),
          );
        }),
      ),
    );
  }

  // ───────────────────────────── KPIs Grid ─────────────────────────────

  Widget _buildKpisGrid(DashboardStats stats) {
    final completionPct = stats.totalRoutes > 0
        ? (stats.completedRoutes / stats.totalRoutes * 100).toStringAsFixed(0)
        : '0';

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: [
        _KpiCard(
          icon: Icons.route,
          color: Colors.blue,
          value: '${stats.completedRoutes}/${stats.totalRoutes}',
          label: 'Rutas ($completionPct%)',
        ),
        _KpiCard(
          icon: Icons.check_circle,
          color: Colors.green,
          value: stats.totalVisits.toString(),
          label: 'Visitas',
        ),
        _KpiCard(
          icon: Icons.people,
          color: Colors.orange,
          value: stats.uniqueClientsVisited.toString(),
          label: 'Clientes',
        ),
        _KpiCard(
          icon: Icons.event,
          color: Colors.purple,
          value: stats.totalCheckIns.toString(),
          label: 'Eventos',
        ),
      ],
    );
  }

  // ───────────────────────────── Trend Line Chart ─────────────────────────

  Widget _buildTrendChart(List<DailyTrend> trends) {
    if (trends.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tendencia',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      )),
              const SizedBox(height: 32),
              const Center(child: Text('Sin datos disponibles')),
              const SizedBox(height: 32),
            ],
          ),
        ),
      );
    }

    // Build spots
    final routeSpots = <FlSpot>[];
    final visitSpots = <FlSpot>[];
    for (int i = 0; i < trends.length; i++) {
      routeSpots.add(FlSpot(i.toDouble(), trends[i].routesCompleted.toDouble()));
      visitSpots.add(FlSpot(i.toDouble(), trends[i].visitsCompleted.toDouble()));
    }

    // Calculate max Y
    double maxY = 0;
    for (final t in trends) {
      if (t.routesCompleted > maxY) maxY = t.routesCompleted.toDouble();
      if (t.visitsCompleted > maxY) maxY = t.visitsCompleted.toDouble();
    }
    maxY = (maxY * 1.2).ceilToDouble();
    if (maxY < 1) maxY = 1;

    // Determine label interval so we show ~5-7 labels max
    final labelInterval = (trends.length / 6).ceil().clamp(1, trends.length);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tendencia',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    )),
            const SizedBox(height: 8),
            Row(
              children: [
                _legendDot(Colors.blue, 'Rutas'),
                const SizedBox(width: 16),
                _legendDot(Colors.green, 'Visitas'),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: (trends.length - 1).toDouble(),
                  minY: 0,
                  maxY: maxY,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: (maxY / 4).ceilToDouble().clamp(1, double.infinity),
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.grey.withValues(alpha: 0.2),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        interval: (maxY / 4).ceilToDouble().clamp(1, double.infinity),
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        interval: labelInterval.toDouble(),
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= trends.length) {
                            return const SizedBox.shrink();
                          }
                          final d = trends[idx].date;
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '${d.day}/${d.month}',
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: routeSpots,
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 2.5,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.blue.withValues(alpha: 0.08),
                      ),
                    ),
                    LineChartBarData(
                      spots: visitSpots,
                      isCurved: true,
                      color: Colors.green,
                      barWidth: 2.5,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.green.withValues(alpha: 0.08),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final color = spot.bar.color ?? Colors.grey;
                          final label = color == Colors.blue ? 'Rutas' : 'Visitas';
                          return LineTooltipItem(
                            '$label: ${spot.y.toInt()}',
                            TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  // ───────────────────────────── Pie Chart ─────────────────────────────

  Widget _buildPieChart(RouteTypeBreakdown breakdown) {
    final types = breakdown.byType;
    if (types.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Distribución por Tipo',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      )),
              const SizedBox(height: 32),
              const Center(child: Text('Sin datos disponibles')),
              const SizedBox(height: 32),
            ],
          ),
        ),
      );
    }

    final sections = <PieChartSectionData>[];
    for (int i = 0; i < types.length; i++) {
      final stat = types[i];
      final color = _parseColor(stat.color);
      sections.add(
        PieChartSectionData(
          value: stat.total.toDouble(),
          color: color,
          title: '',
          radius: 60,
          badgeWidget: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Text(
              stat.total.toString(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          badgePositionPercentageOffset: 1.2,
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Distribución por Tipo',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    )),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  centerSpaceRadius: 36,
                  sectionsSpace: 2,
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Legend
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: types.map((stat) {
                final color = _parseColor(stat.color);
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      stat.typeName,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────── Quick Access Grid ────────────────────────

  Widget _buildQuickAccessGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Acceso Rápido',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                )),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 2.4,
          children: [
            _QuickAccessCard(
              icon: Icons.people,
              title: 'Mercaderistas',
              color: Colors.teal,
              onTap: () => context.push('/admin/reports/mercaderistas'),
            ),
            _QuickAccessCard(
              icon: Icons.store,
              title: 'Clientes',
              color: Colors.orange,
              onTap: () => context.push('/admin/reports/clients'),
            ),
            _QuickAccessCard(
              icon: Icons.route,
              title: 'Rutas',
              color: Colors.blue,
              onTap: () => context.push('/admin/reports/routes'),
            ),
            _QuickAccessCard(
              icon: Icons.event,
              title: 'Eventos',
              color: Colors.purple,
              onTap: () => context.push('/admin/reports/events'),
            ),
          ],
        ),
      ],
    );
  }

  // ───────────────────────────── Error Box ─────────────────────────────

  Widget _buildErrorBox(String message) {
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
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Private helper widgets
// ═══════════════════════════════════════════════════════════════════════════

/// Tarjeta de KPI con borde lateral coloreado.
class _KpiCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  const _KpiCard({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: color, width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Tarjeta de acceso rápido a sub-reportes.
class _QuickAccessCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _QuickAccessCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
