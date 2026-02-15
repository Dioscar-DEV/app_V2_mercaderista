import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../providers/reports_provider.dart';
import '../../../../core/models/report_models.dart';

/// Pantalla de reporte de cobertura de clientes
class ClientCoverageReportScreen extends ConsumerWidget {
  const ClientCoverageReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coverageAsync = ref.watch(clientCoverageProvider);
    final unvisitedAsync = ref.watch(unvisitedClientsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cobertura de Clientes'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- KPI Cards ---
            coverageAsync.when(
              data: (stats) => _buildKpiCards(context, stats),
              loading: () => const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => _buildErrorCard(context, 'Error cargando cobertura: $e'),
            ),

            const SizedBox(height: 24),

            // --- Donut Chart ---
            coverageAsync.when(
              data: (stats) => _buildDonutChart(context, stats),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 24),

            // --- Coverage by Sede ---
            coverageAsync.when(
              data: (stats) => _buildCoverageBySede(context, stats),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 24),

            // --- Unvisited Clients List ---
            unvisitedAsync.when(
              data: (clients) => _buildUnvisitedList(context, clients),
              loading: () => const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => _buildErrorCard(context, 'Error cargando clientes: $e'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCards(BuildContext context, ClientCoverageStats stats) {
    final theme = Theme.of(context);
    final total = stats.totalActive;

    String pct(int count) {
      if (total == 0) return '0%';
      return '${(count / total * 100).toStringAsFixed(1)}%';
    }

    return Row(
      children: [
        Expanded(
          child: _KpiCard(
            title: 'Ultimos 7 dias',
            value: '${stats.visitedLast7Days}',
            subtitle: pct(stats.visitedLast7Days),
            icon: Icons.check_circle,
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _KpiCard(
            title: 'Ultimos 30 dias',
            value: '${stats.visitedLast30Days}',
            subtitle: pct(stats.visitedLast30Days),
            icon: Icons.schedule,
            color: Colors.orange,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _KpiCard(
            title: 'Sin visitar',
            value: '${stats.neverVisited}',
            subtitle: pct(stats.neverVisited),
            icon: Icons.warning,
            color: Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildDonutChart(BuildContext context, ClientCoverageStats stats) {
    final theme = Theme.of(context);
    final total = stats.totalActive;
    if (total == 0) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'No hay clientes activos',
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
          ),
        ),
      );
    }

    final visitedRecent = stats.visitedLast7Days;
    final visited7to30 = stats.visitedLast30Days - stats.visitedLast7Days;
    final visitedOver30 =
        total - stats.visitedLast30Days - stats.neverVisited;
    final neverVisited = stats.neverVisited;

    // Clamp negative values to zero in case of data inconsistencies
    final safeVisited7to30 = visited7to30 < 0 ? 0 : visited7to30;
    final safeVisitedOver30 = visitedOver30 < 0 ? 0 : visitedOver30;

    final sections = <PieChartSectionData>[
      if (visitedRecent > 0)
        PieChartSectionData(
          value: visitedRecent.toDouble(),
          title: '$visitedRecent',
          color: Colors.green,
          radius: 40,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      if (safeVisited7to30 > 0)
        PieChartSectionData(
          value: safeVisited7to30.toDouble(),
          title: '$safeVisited7to30',
          color: Colors.amber,
          radius: 40,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      if (safeVisitedOver30 > 0)
        PieChartSectionData(
          value: safeVisitedOver30.toDouble(),
          title: '$safeVisitedOver30',
          color: Colors.red,
          radius: 40,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      if (neverVisited > 0)
        PieChartSectionData(
          value: neverVisited.toDouble(),
          title: '$neverVisited',
          color: Colors.grey,
          radius: 40,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estado de Visitas',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      sections: sections,
                      centerSpaceRadius: 50,
                      sectionsSpace: 2,
                      startDegreeOffset: -90,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$total',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Total',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _LegendItem(color: Colors.green, label: '< 7 dias'),
                _LegendItem(color: Colors.amber, label: '7-30 dias'),
                _LegendItem(color: Colors.red, label: '> 30 dias'),
                _LegendItem(color: Colors.grey, label: 'Nunca visitado'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverageBySede(BuildContext context, ClientCoverageStats stats) {
    final theme = Theme.of(context);

    if (stats.bySede.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cobertura por Sede',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: stats.bySede.map((sede) {
              final pct = sede.coverageRate;
              final color = pct > 0.7
                  ? Colors.green
                  : pct >= 0.4
                      ? Colors.amber
                      : Colors.red;

              return ListTile(
                title: Text(sede.sede),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: color.withOpacity(0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                trailing: Text(
                  '${sede.visitedClients}/${sede.totalClients}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildUnvisitedList(
      BuildContext context, List<UnvisitedClient> clients) {
    final theme = Theme.of(context);

    if (clients.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'Todos los clientes han sido visitados recientemente',
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
          ),
        ),
      );
    }

    final displayClients = clients.take(20).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Clientes sin Visitar (+30 dias)',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displayClients.length,
            itemBuilder: (context, index) {
              final client = displayClients[index];
              final isNeverVisited = client.lastVisitAt == null;
              final isCritical = client.daysSinceVisit > 60;

              final iconColor = isCritical || isNeverVisited
                  ? Colors.red
                  : Colors.amber;

              final lastVisitText = isNeverVisited
                  ? 'Nunca visitado'
                  : 'Ultima visita: ${client.daysSinceVisit} dias';

              return ListTile(
                leading: Icon(
                  Icons.warning_amber_rounded,
                  color: iconColor,
                ),
                title: Text(
                  client.name,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  'Sede: ${client.sede} \u00b7 $lastVisitText',
                  style: theme.textTheme.bodySmall,
                ),
              );
            },
          ),
        ),
        if (clients.length > 20)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Center(
              child: Text(
                'Mostrando 20 de ${clients.length} clientes',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            ),
          ),
      ],
    );
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

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
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
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w500,
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
