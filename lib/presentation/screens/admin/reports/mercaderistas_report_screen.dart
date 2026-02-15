import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../providers/reports_provider.dart';
import '../../../../core/models/report_models.dart';

/// Pantalla de rendimiento de mercaderistas con rankings y gráfica comparativa.
class MercaderistasReportScreen extends ConsumerWidget {
  const MercaderistasReportScreen({super.key});

  static const List<String> _filterLabels = [
    'Hoy',
    '7 días',
    '30 días',
    'Este mes',
  ];

  ReportsFilter _filterFromIndex(int index) {
    switch (index) {
      case 0:
        return ReportsFilter.today();
      case 1:
        return ReportsFilter.last7Days();
      case 2:
        return ReportsFilter.last30Days();
      case 3:
      default:
        return ReportsFilter.thisMonth();
    }
  }

  int _selectedFilterIndex(WidgetRef ref) {
    final current = ref.read(reportsFilterProvider);
    final label = current.label;
    final idx = _filterLabels.indexOf(label);
    return idx >= 0 ? idx : 3;
  }

  /// Devuelve el color del avatar según la tasa de completado.
  Color _rateColor(double rate) {
    if (rate > 0.8) return Colors.green;
    if (rate >= 0.5) return Colors.amber.shade700;
    return Colors.red;
  }

  /// Obtiene las iniciales del nombre (hasta 2 letras).
  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  /// Obtiene solo el primer nombre para la etiqueta del eje X.
  String _firstName(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    return parts.isNotEmpty ? parts[0] : fullName;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final performanceAsync = ref.watch(mercaderistasPerformanceProvider);
    final selectedIndex = _selectedFilterIndex(ref);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rendimiento Mercaderistas'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Filter chips ──
            _buildFilterChips(ref, selectedIndex),
            const SizedBox(height: 16),

            // ── Content ──
            performanceAsync.when(
              data: (performers) => _buildContent(context, performers),
              loading: () => const SizedBox(
                height: 300,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => _buildErrorBox('Error cargando datos: $e'),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────── Filter Chips ─────────────────────────────

  Widget _buildFilterChips(WidgetRef ref, int selectedIndex) {
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

  // ───────────────────────────── Main Content ─────────────────────────────

  Widget _buildContent(
      BuildContext context, List<MercaderistaPerformance> performers) {
    if (performers.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('No hay datos de mercaderistas')),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Performance cards list ──
        ...performers.map((m) => _buildPerformanceCard(context, m)),
        const SizedBox(height: 24),

        // ── Bar chart: Comparativo ──
        _buildBarChart(context, performers),
      ],
    );
  }

  // ───────────────────────────── Performance Card ─────────────────────────

  Widget _buildPerformanceCard(
      BuildContext context, MercaderistaPerformance m) {
    final rate = m.completionRate;
    final ratePct = (rate * 100).toStringAsFixed(0);
    final avatarColor = _rateColor(rate);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: avatarColor,
          foregroundColor: Colors.white,
          child: Text(
            _initials(m.name),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                m.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: avatarColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$ratePct%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: avatarColor,
                ),
              ),
            ),
          ],
        ),
        subtitle: Text(
          '${m.routesAssigned} rutas asignadas · ${m.routesCompleted} completadas · ${m.clientsVisited} clientes',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: rate,
                strokeWidth: 3.5,
                backgroundColor: Colors.grey.shade200,
                color: avatarColor,
              ),
              Text(
                '$ratePct',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: avatarColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────────── Bar Chart ─────────────────────────────

  Widget _buildBarChart(
      BuildContext context, List<MercaderistaPerformance> performers) {
    // Limit to 10 for readability
    final data = performers.length > 10 ? performers.sublist(0, 10) : performers;

    double maxY = 0;
    for (final m in data) {
      if (m.routesAssigned > maxY) maxY = m.routesAssigned.toDouble();
      if (m.routesCompleted > maxY) maxY = m.routesCompleted.toDouble();
    }
    maxY = (maxY * 1.25).ceilToDouble();
    if (maxY < 1) maxY = 1;

    final barGroups = <BarChartGroupData>[];
    for (int i = 0; i < data.length; i++) {
      final m = data[i];
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: m.routesAssigned.toDouble(),
              color: Colors.grey.shade400,
              width: 10,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
            ),
            BarChartRodData(
              toY: m.routesCompleted.toDouble(),
              color: Colors.green,
              width: 10,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
            ),
          ],
          barsSpace: 3,
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
              'Comparativo',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _legendDot(Colors.grey.shade400, 'Asignadas'),
                const SizedBox(width: 16),
                _legendDot(Colors.green, 'Completadas'),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  maxY: maxY,
                  alignment: BarChartAlignment.spaceAround,
                  barGroups: barGroups,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: (maxY / 4).ceilToDouble().clamp(1, double.infinity),
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.grey.withValues(alpha: 0.2),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIdx, rod, rodIdx) {
                        final label = rodIdx == 0 ? 'Asignadas' : 'Completadas';
                        return BarTooltipItem(
                          '$label: ${rod.toY.toInt()}',
                          TextStyle(
                            color: rod.color,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= data.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              data[idx].routesCompleted.toString(),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          );
                        },
                      ),
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
                            style: const TextStyle(
                                fontSize: 10, color: Colors.grey),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= data.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              _firstName(data[idx].name),
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.grey),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        },
                      ),
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

  // ───────────────────────────── Helpers ─────────────────────────────

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
