import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/route.dart';
import '../../../core/models/user.dart';
import '../../../core/enums/route_status.dart';
import '../../../core/enums/sede.dart';
import '../../../config/theme_config.dart';
import '../../../data/repositories/route_repository.dart';
import '../../providers/auth_provider.dart';
import '../../providers/route_provider.dart';
import '../../providers/user_provider.dart';

/// Pantalla de calendario de rutas para admin/supervisor
class RouteCalendarScreen extends ConsumerStatefulWidget {
  const RouteCalendarScreen({super.key});

  @override
  ConsumerState<RouteCalendarScreen> createState() => _RouteCalendarScreenState();
}

class _RouteCalendarScreenState extends ConsumerState<RouteCalendarScreen> {
  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(selectedDateProvider);
    final weekStart = ref.watch(selectedWeekStartProvider);
    final routesAsync = ref.watch(routesForWeekProvider);
    final statsAsync = ref.watch(routeStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendario de Rutas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            tooltip: 'Ir a hoy',
            onPressed: () => _goToToday(),
          ),
          _buildFilterButton(),
        ],
      ),
      body: Column(
        children: [
          // Panel de estadísticas del día
          statsAsync.when(
            data: (stats) => _buildStatsPanel(stats),
            loading: () => const SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
            error: (e, _) => const SizedBox.shrink(),
          ),

          // Active filters chips
          _buildActiveFiltersBar(),

          // Selector de semana
          _buildWeekSelector(weekStart),

          // Días de la semana
          _buildWeekDays(weekStart, selectedDate, routesAsync),

          // Lista de rutas del día seleccionado
          Expanded(
            child: routesAsync.when(
              data: (routes) => _buildRoutesList(routes, selectedDate),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error: $error'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(routesForWeekProvider),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateRouteDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Nueva Ruta'),
      ),
    );
  }

  Widget _buildStatsPanel(Map<String, dynamic> stats) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: ThemeConfig.disbatteryGradient,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
            label: 'Rutas Hoy',
            value: '${stats['totalRoutesToday'] ?? 0}',
            icon: Icons.route,
          ),
          _StatItem(
            label: 'Completadas',
            value: '${stats['completedRoutesToday'] ?? 0}',
            icon: Icons.check_circle,
          ),
          _StatItem(
            label: 'En Progreso',
            value: '${stats['inProgressRoutesToday'] ?? 0}',
            icon: Icons.play_arrow,
          ),
          _StatItem(
            label: 'Visitas',
            value: '${stats['completedVisitsToday'] ?? 0}/${stats['totalVisitsToday'] ?? 0}',
            icon: Icons.store,
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFiltersBar() {
    final filters = ref.watch(routeFiltersProvider);
    if (!filters.hasFilters) return const SizedBox.shrink();

    final chips = <Widget>[];

    if (filters.sedeApp != null) {
      final sede = Sede.tryFromString(filters.sedeApp);
      chips.add(_buildRemovableChip(
        label: sede?.displayName ?? filters.sedeApp!,
        icon: Icons.business,
        onRemove: () => ref.read(routeFiltersProvider.notifier).state = RouteFilters(
          status: filters.status,
          mercaderistaId: filters.mercaderistaId,
          routeTypeId: filters.routeTypeId,
        ),
      ));
    }

    if (filters.status != null) {
      chips.add(_buildRemovableChip(
        label: filters.status!.displayName,
        icon: Icons.flag,
        onRemove: () => ref.read(routeFiltersProvider.notifier).state = RouteFilters(
          sedeApp: filters.sedeApp,
          mercaderistaId: filters.mercaderistaId,
          routeTypeId: filters.routeTypeId,
        ),
      ));
    }

    if (filters.mercaderistaId != null) {
      final mercaderistas = ref.watch(activeMercaderistasProvider).valueOrNull ?? [];
      final merc = mercaderistas.where((m) => m.id == filters.mercaderistaId).firstOrNull;
      chips.add(_buildRemovableChip(
        label: merc?.fullName ?? 'Mercaderista',
        icon: Icons.person,
        onRemove: () => ref.read(routeFiltersProvider.notifier).state = RouteFilters(
          sedeApp: filters.sedeApp,
          status: filters.status,
          routeTypeId: filters.routeTypeId,
        ),
      ));
    }

    if (filters.routeTypeId != null) {
      final types = ref.watch(routeTypesProvider).valueOrNull ?? [];
      final type = types.where((t) => t.id == filters.routeTypeId).firstOrNull;
      chips.add(_buildRemovableChip(
        label: type?.name ?? 'Tipo',
        icon: Icons.category,
        onRemove: () => ref.read(routeFiltersProvider.notifier).state = RouteFilters(
          sedeApp: filters.sedeApp,
          status: filters.status,
          mercaderistaId: filters.mercaderistaId,
        ),
      ));
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: ThemeConfig.primaryColor.withValues(alpha: 0.05),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: chips),
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: () => ref.read(routeFiltersProvider.notifier).state = const RouteFilters(),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Text('Limpiar', style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w500)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemovableChip({
    required String label,
    required IconData icon,
    required VoidCallback onRemove,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Chip(
        avatar: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        deleteIcon: const Icon(Icons.close, size: 16),
        onDeleted: onRemove,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        labelPadding: const EdgeInsets.only(left: 4, right: 0),
      ),
    );
  }

  Widget _buildWeekSelector(DateTime weekStart) {
    final weekEnd = weekStart.add(const Duration(days: 6));
    final monthNames = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];

    String weekLabel;
    if (weekStart.month == weekEnd.month) {
      weekLabel = '${weekStart.day} - ${weekEnd.day} de ${monthNames[weekStart.month - 1]} ${weekStart.year}';
    } else {
      weekLabel = '${weekStart.day} ${monthNames[weekStart.month - 1].substring(0, 3)} - ${weekEnd.day} ${monthNames[weekEnd.month - 1].substring(0, 3)} ${weekEnd.year}';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey[100],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _changeWeek(-1),
          ),
          Text(
            weekLabel,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => _changeWeek(1),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekDays(DateTime weekStart, DateTime selectedDate, AsyncValue<List<AppRoute>> routesAsync) {
    final dayNames = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    final today = DateTime.now();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(7, (index) {
          final day = weekStart.add(Duration(days: index));
          final isSelected = _isSameDay(day, selectedDate);
          final isToday = _isSameDay(day, today);

          // Contar rutas para este día
          int routesCount = 0;
          routesAsync.whenData((routes) {
            routesCount = routes.where((r) => _isSameDay(r.scheduledDate, day)).length;
          });

          return GestureDetector(
            onTap: () => ref.read(selectedDateProvider.notifier).state = day,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? ThemeConfig.primaryColor
                    : isToday
                        ? ThemeConfig.primaryColor.withValues(alpha: 0.1)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: isToday && !isSelected
                    ? Border.all(color: ThemeConfig.primaryColor, width: 2)
                    : null,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    dayNames[index],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isSelected ? Colors.white : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  ),
                  if (routesCount > 0) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : ThemeConfig.primaryColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$routesCount',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? ThemeConfig.primaryColor : Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildRoutesList(List<AppRoute> allRoutes, DateTime selectedDate) {
    final dayRoutes = allRoutes.where((r) => _isSameDay(r.scheduledDate, selectedDate)).toList();

    if (dayRoutes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.route, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No hay rutas programadas',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Crea una nueva ruta para este día',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: dayRoutes.length,
      itemBuilder: (context, index) {
        final route = dayRoutes[index];
        return _RouteCard(
          route: route,
          onTap: () => _openRouteDetail(route),
        );
      },
    );
  }

  void _goToToday() {
    final today = DateTime.now();
    final mondayOfThisWeek = today.subtract(Duration(days: today.weekday - 1));
    ref.read(selectedWeekStartProvider.notifier).state = mondayOfThisWeek;
    ref.read(selectedDateProvider.notifier).state = today;
  }

  void _changeWeek(int delta) {
    final currentWeekStart = ref.read(selectedWeekStartProvider);
    final newWeekStart = currentWeekStart.add(Duration(days: delta * 7));
    ref.read(selectedWeekStartProvider.notifier).state = newWeekStart;
    ref.read(selectedDateProvider.notifier).state = newWeekStart;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildFilterButton() {
    final filters = ref.watch(routeFiltersProvider);
    final hasFilters = filters.hasFilters;

    return Stack(
      children: [
        IconButton(
          icon: Icon(
            hasFilters ? Icons.filter_list_off : Icons.filter_list,
          ),
          tooltip: hasFilters ? 'Filtros activos' : 'Filtros',
          onPressed: () => _showFilters(),
        ),
        if (hasFilters)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }

  int _countActiveFilters(RouteFilters filters) {
    int count = 0;
    if (filters.sedeApp != null) count++;
    if (filters.status != null) count++;
    if (filters.mercaderistaId != null) count++;
    if (filters.routeTypeId != null) count++;
    return count;
  }

  void _showFilters() {
    final currentUser = ref.read(currentUserProvider).valueOrNull;
    final canViewAllSedes = currentUser?.role.canViewAllSedes ?? false;
    final isAdmin = currentUser?.role.isAdmin ?? false;

    if (!isAdmin) return;

    final currentFilters = ref.read(routeFiltersProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _RouteFiltersSheet(
        initialFilters: currentFilters,
        canViewAllSedes: canViewAllSedes,
        currentUserSede: currentUser?.sede,
        onApply: (filters) {
          ref.read(routeFiltersProvider.notifier).state = filters;
        },
      ),
    );
  }

  void _showCreateRouteDialog() {
    context.push('/admin/routes/create');
  }

  void _openRouteDetail(AppRoute route) {
    context.push('/admin/routes/${route.id}');
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _RouteCard extends StatelessWidget {
  final AppRoute route;
  final VoidCallback onTap;

  const _RouteCard({
    required this.route,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      route.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _buildStatusChip(route.status),
                ],
              ),
              const SizedBox(height: 8),
              if (route.mercaderistaName != null)
                Row(
                  children: [
                    const Icon(Icons.person, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      route.mercaderistaName!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.store, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    '${route.completedClients}/${route.totalClients} clientes',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const Spacer(),
                  if (route.routeType != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _hexToColor(route.routeType!.color).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        route.routeType!.name,
                        style: TextStyle(
                          fontSize: 12,
                          color: _hexToColor(route.routeType!.color),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: route.progress,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    route.isComplete
                        ? Colors.green
                        : route.isInProgress
                            ? Colors.blue
                            : Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(RouteStatus status) {
    Color backgroundColor;
    Color textColor;
    String label;

    switch (status) {
      case RouteStatus.planned:
        backgroundColor = Colors.grey[200]!;
        textColor = Colors.grey[700]!;
        label = 'Planificada';
        break;
      case RouteStatus.inProgress:
        backgroundColor = Colors.blue[100]!;
        textColor = Colors.blue[700]!;
        label = 'En Progreso';
        break;
      case RouteStatus.completed:
        backgroundColor = Colors.green[100]!;
        textColor = Colors.green[700]!;
        label = 'Completada';
        break;
      case RouteStatus.cancelled:
        backgroundColor = Colors.red[100]!;
        textColor = Colors.red[700]!;
        label = 'Cancelada';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }

  Color _hexToColor(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 6 || hex.length == 7) buffer.write('ff');
    buffer.write(hex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}

/// Bottom sheet de filtros para el calendario de rutas
class _RouteFiltersSheet extends ConsumerStatefulWidget {
  final RouteFilters initialFilters;
  final bool canViewAllSedes;
  final Sede? currentUserSede;
  final void Function(RouteFilters) onApply;

  const _RouteFiltersSheet({
    required this.initialFilters,
    required this.canViewAllSedes,
    required this.currentUserSede,
    required this.onApply,
  });

  @override
  ConsumerState<_RouteFiltersSheet> createState() => _RouteFiltersSheetState();
}

class _RouteFiltersSheetState extends ConsumerState<_RouteFiltersSheet> {
  String? _selectedSede;
  RouteStatus? _selectedStatus;
  String? _selectedMercaderistaId;
  String? _selectedRouteTypeId;

  @override
  void initState() {
    super.initState();
    _selectedSede = widget.initialFilters.sedeApp;
    _selectedStatus = widget.initialFilters.status;
    _selectedMercaderistaId = widget.initialFilters.mercaderistaId;
    _selectedRouteTypeId = widget.initialFilters.routeTypeId;
  }

  @override
  Widget build(BuildContext context) {
    final mercaderistasAsync = ref.watch(activeMercaderistasProvider);
    final routeTypesAsync = ref.watch(routeTypesProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: ListView(
          controller: scrollController,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title + Clear
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Filtros',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: _clearAll,
                  child: const Text('Limpiar todo'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // SEDE filter (only for owner)
            if (widget.canViewAllSedes) ...[
              const Text('Sede', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildFilterChip(
                    label: 'Todas',
                    selected: _selectedSede == null,
                    onSelected: (_) => setState(() => _selectedSede = null),
                  ),
                  ...Sede.values.map((sede) => _buildFilterChip(
                    label: sede.displayName,
                    selected: _selectedSede == sede.value,
                    onSelected: (_) => setState(() {
                      _selectedSede = _selectedSede == sede.value ? null : sede.value;
                      // Reset mercaderista when sede changes
                      _selectedMercaderistaId = null;
                    }),
                  )),
                ],
              ),
              const SizedBox(height: 20),
            ],

            // STATUS filter
            const Text('Estado', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildFilterChip(
                  label: 'Todos',
                  selected: _selectedStatus == null,
                  onSelected: (_) => setState(() => _selectedStatus = null),
                ),
                ...RouteStatus.values.map((status) => _buildFilterChip(
                  label: status.displayName,
                  selected: _selectedStatus == status,
                  onSelected: (_) => setState(() {
                    _selectedStatus = _selectedStatus == status ? null : status;
                  }),
                  color: _statusColor(status),
                )),
              ],
            ),
            const SizedBox(height: 20),

            // MERCADERISTA filter
            const Text('Mercaderista', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            mercaderistasAsync.when(
              data: (mercaderistas) {
                // Filter by selected sede if any
                final filtered = _selectedSede != null
                    ? mercaderistas.where((m) => m.sede?.value == _selectedSede).toList()
                    : mercaderistas;

                return DropdownButtonFormField<String?>(
                  value: filtered.any((m) => m.id == _selectedMercaderistaId)
                      ? _selectedMercaderistaId
                      : null,
                  decoration: InputDecoration(
                    hintText: 'Todos los mercaderistas',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    isDense: true,
                  ),
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Todos los mercaderistas'),
                    ),
                    ...filtered.map((m) => DropdownMenuItem<String?>(
                      value: m.id,
                      child: Text(m.fullName, overflow: TextOverflow.ellipsis),
                    )),
                  ],
                  onChanged: (value) => setState(() => _selectedMercaderistaId = value),
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text('Error cargando mercaderistas'),
            ),
            const SizedBox(height: 20),

            // ROUTE TYPE filter
            const Text('Tipo de Ruta', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            routeTypesAsync.when(
              data: (types) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildFilterChip(
                    label: 'Todos',
                    selected: _selectedRouteTypeId == null,
                    onSelected: (_) => setState(() => _selectedRouteTypeId = null),
                  ),
                  ...types.map((type) => _buildFilterChip(
                    label: type.name,
                    selected: _selectedRouteTypeId == type.id,
                    onSelected: (_) => setState(() {
                      _selectedRouteTypeId = _selectedRouteTypeId == type.id ? null : type.id;
                    }),
                    color: _hexToColor(type.color),
                  )),
                ],
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text('Error cargando tipos'),
            ),
            const SizedBox(height: 28),

            // Apply button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: _apply,
                icon: const Icon(Icons.check),
                label: const Text('Aplicar Filtros'),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required ValueChanged<bool> onSelected,
    Color? color,
  }) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      selectedColor: (color ?? ThemeConfig.primaryColor).withValues(alpha: 0.2),
      checkmarkColor: color ?? ThemeConfig.primaryColor,
      labelStyle: TextStyle(
        color: selected ? (color ?? ThemeConfig.primaryColor) : Colors.grey[700],
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Color _statusColor(RouteStatus status) {
    switch (status) {
      case RouteStatus.planned:
        return Colors.grey;
      case RouteStatus.inProgress:
        return Colors.blue;
      case RouteStatus.completed:
        return Colors.green;
      case RouteStatus.cancelled:
        return Colors.red;
    }
  }

  Color _hexToColor(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 6 || hex.length == 7) buffer.write('ff');
    buffer.write(hex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  void _clearAll() {
    setState(() {
      _selectedSede = null;
      _selectedStatus = null;
      _selectedMercaderistaId = null;
      _selectedRouteTypeId = null;
    });
  }

  void _apply() {
    widget.onApply(RouteFilters(
      sedeApp: _selectedSede,
      status: _selectedStatus,
      mercaderistaId: _selectedMercaderistaId,
      routeTypeId: _selectedRouteTypeId,
    ));
    Navigator.of(context).pop();
  }
}
