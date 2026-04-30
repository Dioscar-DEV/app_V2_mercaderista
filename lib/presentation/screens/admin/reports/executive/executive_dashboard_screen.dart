import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../../../config/supabase_config.dart';
import '../../../../../config/theme_config.dart';
import '../../../../providers/auth_provider.dart';

// ============================================
// PROVIDERS
// ============================================

/// Emails de usuarios de prueba a excluir de todos los reportes
const _testEmails = ['dioscar05@gmail.com'];

/// Filtros del dashboard ejecutivo
class ExecutiveFilter {
  final DateTime? startDate;
  final DateTime? endDate;
  final String? region; // sede_app value
  final String? ciudad;
  final String? tipo; // merchandising, trade
  final String? mercaderista;
  final String? cliente;
  final String? marca; // 'SHELL', 'QUALID', null = general

  const ExecutiveFilter({
    this.startDate,
    this.endDate,
    this.region,
    this.ciudad,
    this.tipo,
    this.mercaderista,
    this.cliente,
    this.marca,
  });

  ExecutiveFilter copyWith({
    DateTime? startDate,
    DateTime? endDate,
    String? region,
    String? ciudad,
    String? tipo,
    String? mercaderista,
    String? cliente,
    String? marca,
    bool clearRegion = false,
    bool clearCiudad = false,
    bool clearTipo = false,
    bool clearMercaderista = false,
    bool clearCliente = false,
    bool clearMarca = false,
  }) {
    return ExecutiveFilter(
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      region: clearRegion ? null : (region ?? this.region),
      ciudad: clearCiudad ? null : (ciudad ?? this.ciudad),
      tipo: clearTipo ? null : (tipo ?? this.tipo),
      mercaderista: clearMercaderista ? null : (mercaderista ?? this.mercaderista),
      cliente: clearCliente ? null : (cliente ?? this.cliente),
      marca: clearMarca ? null : (marca ?? this.marca),
    );
  }
}

final executiveFilterProvider = StateProvider<ExecutiveFilter>((ref) {
  final now = DateTime.now();
  return ExecutiveFilter(
    startDate: DateTime(2024, 1, 1),
    endDate: now,
  );
});

/// Query helper: construye WHERE conditions
String _buildWhereClause(ExecutiveFilter filter, {String dateCol = 'fecha'}) {
  final conditions = <String>[];
  if (filter.startDate != null) {
    conditions.add("$dateCol >= '${filter.startDate!.toIso8601String()}'");
  }
  if (filter.endDate != null) {
    conditions.add("$dateCol <= '${filter.endDate!.add(const Duration(days: 1)).toIso8601String()}'");
  }
  if (filter.ciudad != null) {
    conditions.add("sucursal = '${filter.ciudad}'");
  }
  if (filter.mercaderista != null) {
    conditions.add("email = '${filter.mercaderista}'");
  }
  if (filter.cliente != null) {
    conditions.add("rif_cliente = '${filter.cliente}'");
  }
  return conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';
}

/// Tablas según filtro de región
List<String> _getTablesForFilter(ExecutiveFilter filter, String type) {
  if (filter.region != null) {
    final prefix = {
      'blitz_2000': 'blitz',
      'grupo_victoria': 'grupo_victoria',
      'oceano_pacifico': 'oriente',
      'grupo_disbattery': 'grupo_disbattery',
    }[filter.region]!;
    return ['${prefix}_$type'];
  }
  return [
    'blitz_$type',
    'grupo_victoria_$type',
    'oriente_$type',
    'grupo_disbattery_$type',
  ];
}

/// Sucursales reales de la DB (para el dropdown dinámico)
final _realSucursalesProvider = FutureProvider<List<String>>((ref) async {
  final sb = SupabaseConfig.client;
  final sucursales = <String>{};
  final tables = [
    'blitz_merchandising', 'blitz_trade',
    'grupo_victoria_merchandising', 'grupo_victoria_trade',
    'oriente_merchandising', 'oriente_trade',
    'grupo_disbattery_merchandising', 'grupo_disbattery_trade',
  ];
  for (final table in tables) {
    try {
      final data = await sb.from(table).select('sucursal').eq('source', 'app').not('email', 'in', _testEmails);
      for (final row in (data as List)) {
        final s = row['sucursal'] as String?;
        if (s != null && s.isNotEmpty) sucursales.add(s);
      }
    } catch (_) {}
  }
  // Mapear valores internos a nombres legibles
  const displayMap = {
    'grupo_victoria': 'Occidente (GV)',
  };
  final result = sucursales.map((s) => displayMap[s] ?? s).toList()..sort();
  return result;
});

/// Mapa inverso: display name → valor real en DB
const _sucursalDisplayToDb = {
  'Occidente (GV)': 'grupo_victoria',
};
String _sucursalToDbValue(String display) => _sucursalDisplayToDb[display] ?? display;
String _sucursalToDisplay(String db) {
  const dbToDisplay = {'grupo_victoria': 'Occidente (GV)'};
  return dbToDisplay[db] ?? db;
}

/// KPIs principales
final executiveKpisProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final filter = ref.watch(executiveFilterProvider);
  final sb = SupabaseConfig.client;

  int totalVisitas = 0;
  int clientesVisitados = 0;

  // Si se filtra por marca, solo consultar trade (mercha no tiene marca)
  final types = filter.tipo == null
      ? (filter.marca != null ? ['trade'] : ['merchandising', 'trade'])
      : [filter.tipo!];

  for (final type in types) {
    final tables = _getTablesForFilter(filter, type);
    for (final table in tables) {
      try {
        var query = sb.from(table).select('rif_cliente').eq('source', 'app').not('email', 'in', _testEmails);
        if (filter.startDate != null) {
          query = query.gte('fecha', filter.startDate!.toIso8601String());
        }
        if (filter.endDate != null) {
          query = query.lte('fecha', filter.endDate!.add(const Duration(days: 1)).toIso8601String());
        }
        if (filter.ciudad != null) {
          query = query.eq('sucursal', filter.ciudad!);
        }
        if (filter.mercaderista != null) {
          query = query.eq('email', filter.mercaderista!);
        }
        // Filtro de marca (solo trade tiene marca_promocionada)
        if (filter.marca != null && type == 'trade') {
          query = query.ilike('marca_promocionada', '%${filter.marca == 'SHELL' ? 'Shell' : 'Qualid'}%');
        }
        final data = await query;
        final rows = data as List;
        totalVisitas += rows.length;
        final uniqueClients = rows.map((r) => r['rif_cliente']).toSet();
        clientesVisitados += uniqueClients.length;
      } catch (_) {}
    }
  }

  // Clientes con y sin coordenadas
  int clientesConCoords = 0;
  int clientesSinCoords = 0;
  try {
    final allClients = await sb.from('clients').select('latitude, longitude').eq('inactivo', false);
    for (final c in (allClients as List)) {
      if (c['latitude'] != null && c['longitude'] != null && c['latitude'] != 0) {
        clientesConCoords++;
      } else {
        clientesSinCoords++;
      }
    }
  } catch (_) {}

  return {
    'totalVisitas': totalVisitas,
    'clientesVisitados': clientesVisitados,
    'clientesConCoords': clientesConCoords,
    'clientesSinCoords': clientesSinCoords,
  };
});

/// Visitas por mes (para gráfico de barras)
final executiveMonthlyProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final filter = ref.watch(executiveFilterProvider);
  final sb = SupabaseConfig.client;
  final monthData = <String, int>{};

  final types = filter.tipo == null
      ? (filter.marca != null ? ['trade'] : ['merchandising', 'trade'])
      : [filter.tipo!];

  for (final type in types) {
    final tables = _getTablesForFilter(filter, type);
    for (final table in tables) {
      try {
        var query = sb.from(table).select('fecha').eq('source', 'app').not('email', 'in', _testEmails);
        if (filter.startDate != null) {
          query = query.gte('fecha', filter.startDate!.toIso8601String());
        }
        if (filter.endDate != null) {
          query = query.lte('fecha', filter.endDate!.add(const Duration(days: 1)).toIso8601String());
        }
        if (filter.ciudad != null) query = query.eq('sucursal', filter.ciudad!);
        if (filter.mercaderista != null) query = query.eq('email', filter.mercaderista!);
        if (filter.marca != null && type == 'trade') {
          query = query.ilike('marca_promocionada', '%${filter.marca == 'SHELL' ? 'Shell' : 'Qualid'}%');
        }
        final data = await query;
        for (final row in (data as List)) {
          final fecha = DateTime.tryParse(row['fecha'] ?? '');
          if (fecha != null) {
            final key = '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}';
            monthData[key] = (monthData[key] ?? 0) + 1;
          }
        }
      } catch (_) {}
    }
  }

  final sorted = monthData.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
  return sorted.map((e) => {'month': e.key, 'count': e.value}).toList();
});

/// Visitas por región (para gráfico de barras)
final executiveByRegionProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final filter = ref.watch(executiveFilterProvider);
  final sb = SupabaseConfig.client;
  final regionData = <String, int>{};

  final sedeNames = {
    'blitz': 'Centro-Llanos',
    'grupo_victoria': 'Occidente',
    'oriente': 'Oriente',
    'grupo_disbattery': 'Centro-Capital',
  };

  final types = filter.tipo == null
      ? (filter.marca != null ? ['trade'] : ['merchandising', 'trade'])
      : [filter.tipo!];

  for (final type in types) {
    final tables = _getTablesForFilter(filter, type);
    for (final table in tables) {
      try {
        var query = sb.from(table).select('fecha').eq('source', 'app').not('email', 'in', _testEmails);
        if (filter.startDate != null) query = query.gte('fecha', filter.startDate!.toIso8601String());
        if (filter.endDate != null) query = query.lte('fecha', filter.endDate!.add(const Duration(days: 1)).toIso8601String());
        if (filter.ciudad != null) query = query.eq('sucursal', filter.ciudad!);
        if (filter.marca != null && type == 'trade') {
          query = query.ilike('marca_promocionada', '%${filter.marca == 'SHELL' ? 'Shell' : 'Qualid'}%');
        }
        final data = await query;
        final prefix = table.replaceAll('_merchandising', '').replaceAll('_trade', '');
        final name = sedeNames[prefix] ?? prefix;
        regionData[name] = (regionData[name] ?? 0) + (data as List).length;
      } catch (_) {}
    }
  }

  return regionData.entries.map((e) => {'region': e.key, 'count': e.value}).toList()
    ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
});

/// Registros por ciudad (para gráfico pie)
final executiveByCityProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final filter = ref.watch(executiveFilterProvider);
  final sb = SupabaseConfig.client;
  final cityData = <String, int>{};

  final types = filter.tipo == null
      ? (filter.marca != null ? ['trade'] : ['merchandising', 'trade'])
      : [filter.tipo!];

  for (final type in types) {
    final tables = _getTablesForFilter(filter, type);
    for (final table in tables) {
      try {
        var query = sb.from(table).select('sucursal').eq('source', 'app').not('email', 'in', _testEmails);
        if (filter.startDate != null) query = query.gte('fecha', filter.startDate!.toIso8601String());
        if (filter.endDate != null) query = query.lte('fecha', filter.endDate!.add(const Duration(days: 1)).toIso8601String());
        if (filter.mercaderista != null) query = query.eq('email', filter.mercaderista!);
        if (filter.marca != null && type == 'trade') {
          query = query.ilike('marca_promocionada', '%${filter.marca == 'SHELL' ? 'Shell' : 'Qualid'}%');
        }
        final data = await query;
        for (final row in (data as List)) {
          var city = (row['sucursal'] as String?) ?? 'Sin ciudad';
          // Mapear valores internos a nombres geográficos
          final cityMap = {
            'grupo_victoria': 'Occidente',
            'oceano_pacifico': 'Oriente',
            'blitz_2000': 'Centro-Llanos',
            'grupo_disbattery': 'Centro-Capital',
            '': 'Sin ciudad',
          };
          city = cityMap[city] ?? city;
          cityData[city] = (cityData[city] ?? 0) + 1;
        }
      } catch (_) {}
    }
  }

  return cityData.entries.map((e) => {'city': e.key, 'count': e.value}).toList()
    ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
});

// ============================================
// SCREEN
// ============================================

class ExecutiveDashboardScreen extends ConsumerStatefulWidget {
  const ExecutiveDashboardScreen({super.key});

  @override
  ConsumerState<ExecutiveDashboardScreen> createState() => _ExecutiveDashboardScreenState();
}

class _ExecutiveDashboardScreenState extends ConsumerState<ExecutiveDashboardScreen> {
  int _selectedSection = 0;

  static const _sections = [
    'Consultas',
    'Inventario POP',
    'Artículos Entregados',
    'Detalles Mercha',
    'Detalles Trade',
    'Resumen Material',
  ];

  static const _sedes = {
    'blitz_2000': 'Centro-Llanos',
    'grupo_victoria': 'Occidente',
    'oceano_pacifico': 'Oriente',
    'grupo_disbattery': 'Centro-Capital',
  };

  static const Map<String, List<String>> _ciudadesPorSede = {
    'grupo_disbattery': ['Caracas', 'Falcón', 'Lara', 'Aragua', 'Miranda', 'Portuguesa', 'Yaracuy'],
    'oceano_pacifico': ['Puerto La Cruz', 'Puerto Ordaz', 'Maturín', 'Margarita', 'El Tigre'],
    'blitz_2000': ['Valencia', 'Calabozo'],
    'grupo_victoria': ['San Cristóbal', 'Maracaibo', 'Barinas', 'Mérida', 'El Vigía', 'Santa Bárbara', 'Valera'],
  };

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          if (isWide)
            SizedBox(
              width: 200,
              child: _buildSidebar(),
            ),
          // Content
          Expanded(
            child: Column(
              children: [
                // Filtros globales
                _buildFilters(context),
                // Contenido de la sección seleccionada
                Expanded(
                  child: _buildSection(),
                ),
              ],
            ),
          ),
        ],
      ),
      drawer: isWide ? null : Drawer(child: _buildSidebar()),
    );
  }

  Widget _buildSidebar() {
    return Container(
      color: Colors.grey[50],
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Dashboard Ejecutivo',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: ThemeConfig.primaryColor,
              ),
            ),
          ),
          const Divider(height: 1),
          ...List.generate(_sections.length, (i) {
            final selected = _selectedSection == i;
            return ListTile(
              dense: true,
              selected: selected,
              selectedTileColor: ThemeConfig.primaryColor.withValues(alpha: 0.1),
              leading: Icon(
                _getSectionIcon(i),
                size: 18,
                color: selected ? ThemeConfig.primaryColor : Colors.grey[600],
              ),
              title: Text(
                _sections[i],
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: selected ? ThemeConfig.primaryColor : Colors.grey[800],
                ),
              ),
              onTap: () => setState(() => _selectedSection = i),
            );
          }),
        ],
      ),
    );
  }

  IconData _getSectionIcon(int index) {
    switch (index) {
      case 0: return Icons.dashboard;
      case 1: return Icons.inventory_2;
      case 2: return Icons.card_giftcard;
      case 3: return Icons.store;
      case 4: return Icons.campaign;
      case 5: return Icons.summarize;
      default: return Icons.circle;
    }
  }

  Widget _buildFilters(BuildContext context) {
    // Solo muestra el nombre de la sección seleccionada
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: ThemeConfig.primaryColor,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)],
      ),
      child: Row(
        children: [
          Icon(_getSectionIcon(_selectedSection), color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(
            _sections[_selectedSection],
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildSection() {
    switch (_selectedSection) {
      case 0: return _ConsultasSection();
      case 1: return const _InventarioPopSection();
      case 2: return const _ArticulosEntregadosSection();
      case 3: return const _DetallesMerchaSection();
      case 4: return const _DetallesTradeSection();
      case 5: return const _ResumenMaterialSection();
      default: return const SizedBox.shrink();
    }
  }
}

// ============================================
// SECTION FILTERS WIDGET (reutilizable por sección)
// ============================================
class _SectionFilters extends ConsumerWidget {
  final bool showPeriodo;
  final bool showRegion;
  final bool showSucursal;
  final bool showTipo;
  final bool showMarca;

  const _SectionFilters({
    this.showPeriodo = true,
    this.showRegion = true,
    this.showSucursal = true,
    this.showTipo = false,
    this.showMarca = true,
  });

  static const _sedes = {
    'blitz_2000': 'Centro-Llanos',
    'grupo_victoria': 'Occidente',
    'oceano_pacifico': 'Oriente',
    'grupo_disbattery': 'Centro-Capital',
  };

  static const Map<String, List<String>> _ciudadesPorSede = {
    'grupo_disbattery': ['Caracas', 'Falcón', 'Lara', 'Aragua', 'Miranda', 'Portuguesa', 'Yaracuy'],
    'oceano_pacifico': ['Puerto La Cruz', 'Puerto Ordaz', 'Maturín', 'Margarita', 'El Tigre'],
    'blitz_2000': ['Valencia', 'Calabozo'],
    'grupo_victoria': ['San Cristóbal', 'Maracaibo', 'Barinas', 'Mérida', 'El Vigía', 'Santa Bárbara', 'Valera'],
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(executiveFilterProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (showPeriodo) ...[
            _FilterDropdown(
              label: 'Período',
              value: _getPeriodLabel(filter),
              items: const [
                DropdownMenuItem(value: 'este_mes', child: Text('Este mes', style: TextStyle(fontSize: 12))),
                DropdownMenuItem(value: 'mes_pasado', child: Text('Mes pasado', style: TextStyle(fontSize: 12))),
                DropdownMenuItem(value: 'ultimos_3m', child: Text('Últimos 3 meses', style: TextStyle(fontSize: 12))),
                DropdownMenuItem(value: 'ultimos_6m', child: Text('Últimos 6 meses', style: TextStyle(fontSize: 12))),
                DropdownMenuItem(value: 'este_ano', child: Text('Este año', style: TextStyle(fontSize: 12))),
                DropdownMenuItem(value: 'ano_pasado', child: Text('Año pasado', style: TextStyle(fontSize: 12))),
                DropdownMenuItem(value: 'todo', child: Text('Todo', style: TextStyle(fontSize: 12))),
                DropdownMenuItem(value: 'personalizado', child: Text('Personalizado...', style: TextStyle(fontSize: 12))),
              ],
              onChanged: (v) => _applyPeriodPreset(v, context, ref),
              onClear: () => ref.read(executiveFilterProvider.notifier).state = filter.copyWith(
                startDate: DateTime(2024, 1, 1), endDate: DateTime.now(),
              ),
            ),
          ],
          if (showRegion)
            _FilterDropdown(
              label: 'Región',
              value: filter.region != null ? (_sedes[filter.region] ?? filter.region!) : null,
              items: _sedes.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 12)))).toList(),
              onChanged: (v) => ref.read(executiveFilterProvider.notifier).state = filter.copyWith(region: v, clearCiudad: true),
              onClear: () => ref.read(executiveFilterProvider.notifier).state = filter.copyWith(clearRegion: true, clearCiudad: true),
            ),
          if (showSucursal)
            Consumer(
              builder: (context, ref, _) {
                final sucursalesAsync = ref.watch(_realSucursalesProvider);
                return sucursalesAsync.when(
                  data: (sucursales) => _FilterDropdown(
                    label: 'Sucursal',
                    value: filter.ciudad != null ? _sucursalToDisplay(filter.ciudad!) : null,
                    items: sucursales.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12)))).toList(),
                    onChanged: (v) => ref.read(executiveFilterProvider.notifier).state = filter.copyWith(ciudad: v != null ? _sucursalToDbValue(v) : null),
                    onClear: () => ref.read(executiveFilterProvider.notifier).state = filter.copyWith(clearCiudad: true),
                  ),
                  loading: () => const SizedBox(width: 120, height: 32, child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))),
                  error: (_, __) => const SizedBox.shrink(),
                );
              },
            ),
          if (showTipo)
            _FilterDropdown(
              label: 'Tipo',
              value: filter.tipo != null ? (filter.tipo == 'merchandising' ? 'Merchandising' : 'Trade') : null,
              items: const [
                DropdownMenuItem(value: 'merchandising', child: Text('Merchandising', style: TextStyle(fontSize: 12))),
                DropdownMenuItem(value: 'trade', child: Text('Trade', style: TextStyle(fontSize: 12))),
              ],
              onChanged: (v) => ref.read(executiveFilterProvider.notifier).state = filter.copyWith(tipo: v),
              onClear: () => ref.read(executiveFilterProvider.notifier).state = filter.copyWith(clearTipo: true),
            ),
          if (showMarca)
            _FilterDropdown(
              label: 'Marca',
              value: filter.marca,
              items: const [
                DropdownMenuItem(value: 'SHELL', child: Text('Shell', style: TextStyle(fontSize: 12))),
                DropdownMenuItem(value: 'QUALID', child: Text('Qualid', style: TextStyle(fontSize: 12))),
              ],
              onChanged: (v) => ref.read(executiveFilterProvider.notifier).state = filter.copyWith(marca: v),
              onClear: () => ref.read(executiveFilterProvider.notifier).state = filter.copyWith(clearMarca: true),
            ),
          // Reset
          GestureDetector(
            onTap: () {
              final now = DateTime.now();
              ref.read(executiveFilterProvider.notifier).state = ExecutiveFilter(
                startDate: DateTime(2024, 1, 1), endDate: now,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
              child: const Text('Reset', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  String? _getPeriodLabel(ExecutiveFilter filter) {
    if (filter.startDate == null) return null;
    final s = filter.startDate!;
    final e = filter.endDate ?? DateTime.now();
    if (s.year == 2024 && s.month == 1 && s.day == 1) return null;
    return '${s.day}/${s.month}/${s.year} - ${e.day}/${e.month}/${e.year}';
  }

  void _applyPeriodPreset(String? preset, BuildContext context, WidgetRef ref) {
    if (preset == null) return;
    final now = DateTime.now();
    final filter = ref.read(executiveFilterProvider);
    DateTime start;
    DateTime end = now;

    switch (preset) {
      case 'este_mes': start = DateTime(now.year, now.month, 1); break;
      case 'mes_pasado': start = DateTime(now.year, now.month - 1, 1); end = DateTime(now.year, now.month, 0); break;
      case 'ultimos_3m': start = DateTime(now.year, now.month - 3, 1); break;
      case 'ultimos_6m': start = DateTime(now.year, now.month - 6, 1); break;
      case 'este_ano': start = DateTime(now.year, 1, 1); break;
      case 'ano_pasado': start = DateTime(now.year - 1, 1, 1); end = DateTime(now.year - 1, 12, 31); break;
      case 'todo': start = DateTime(2024, 1, 1); break;
      case 'personalizado':
        _showCalendarDialog(context, ref);
        return;
      default: start = DateTime(2024, 1, 1);
    }
    ref.read(executiveFilterProvider.notifier).state = filter.copyWith(startDate: start, endDate: end);
  }

  void _showCalendarDialog(BuildContext context, WidgetRef ref) {
    final filter = ref.read(executiveFilterProvider);
    DateTime? rangeStart = filter.startDate;
    DateTime? rangeEnd = filter.endDate;
    DateTime focusedStart = rangeStart ?? DateTime.now().subtract(const Duration(days: 30));
    DateTime focusedEnd = rangeEnd ?? DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          child: Container(
            width: 700,
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text('Seleccionar rango de fechas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                if (rangeStart != null && rangeEnd != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: ThemeConfig.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${rangeStart!.day}/${rangeStart!.month}/${rangeStart!.year}  →  ${rangeEnd!.day}/${rangeEnd!.month}/${rangeEnd!.year}',
                      style: TextStyle(fontSize: 14, color: ThemeConfig.primaryColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                // Dos calendarios lado a lado
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Calendario izquierdo (Fecha inicio)
                    Expanded(
                      child: Column(
                        children: [
                          Text('Fecha de inicio', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey[600])),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 340,
                            child: TableCalendar(
                              firstDay: DateTime(2024, 1, 1),
                              lastDay: DateTime.now(),
                              focusedDay: focusedStart,
                              rangeStartDay: rangeStart,
                              rangeEndDay: rangeEnd,
                              rangeSelectionMode: RangeSelectionMode.toggledOn,
                              onRangeSelected: (start, end, focused) {
                                setDialogState(() {
                                  rangeStart = start;
                                  rangeEnd = end;
                                  if (start != null) focusedStart = start;
                                });
                              },
                              onPageChanged: (focused) => setDialogState(() => focusedStart = focused),
                              calendarStyle: CalendarStyle(
                                rangeHighlightColor: ThemeConfig.primaryColor.withValues(alpha: 0.15),
                                rangeStartDecoration: BoxDecoration(color: ThemeConfig.primaryColor, shape: BoxShape.circle),
                                rangeEndDecoration: BoxDecoration(color: ThemeConfig.primaryColor, shape: BoxShape.circle),
                                todayDecoration: BoxDecoration(color: ThemeConfig.primaryColor.withValues(alpha: 0.3), shape: BoxShape.circle),
                                outsideDaysVisible: false,
                                cellMargin: const EdgeInsets.all(2),
                              ),
                              headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true, titleTextStyle: TextStyle(fontSize: 14)),
                              calendarFormat: CalendarFormat.month,
                              daysOfWeekStyle: const DaysOfWeekStyle(weekdayStyle: TextStyle(fontSize: 11), weekendStyle: TextStyle(fontSize: 11)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 360, color: Colors.grey[300], margin: const EdgeInsets.symmetric(horizontal: 8)),
                    // Calendario derecho (Fecha fin)
                    Expanded(
                      child: Column(
                        children: [
                          Text('Fecha de fin', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey[600])),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 340,
                            child: TableCalendar(
                              firstDay: DateTime(2024, 1, 1),
                              lastDay: DateTime.now(),
                              focusedDay: focusedEnd,
                              rangeStartDay: rangeStart,
                              rangeEndDay: rangeEnd,
                              rangeSelectionMode: RangeSelectionMode.toggledOn,
                              onRangeSelected: (start, end, focused) {
                                setDialogState(() {
                                  rangeStart = start;
                                  rangeEnd = end;
                                  if (end != null) focusedEnd = end;
                                });
                              },
                              onPageChanged: (focused) => setDialogState(() => focusedEnd = focused),
                              calendarStyle: CalendarStyle(
                                rangeHighlightColor: ThemeConfig.primaryColor.withValues(alpha: 0.15),
                                rangeStartDecoration: BoxDecoration(color: ThemeConfig.primaryColor, shape: BoxShape.circle),
                                rangeEndDecoration: BoxDecoration(color: ThemeConfig.primaryColor, shape: BoxShape.circle),
                                todayDecoration: BoxDecoration(color: ThemeConfig.primaryColor.withValues(alpha: 0.3), shape: BoxShape.circle),
                                outsideDaysVisible: false,
                                cellMargin: const EdgeInsets.all(2),
                              ),
                              headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true, titleTextStyle: TextStyle(fontSize: 14)),
                              calendarFormat: CalendarFormat.month,
                              daysOfWeekStyle: const DaysOfWeekStyle(weekdayStyle: TextStyle(fontSize: 11), weekendStyle: TextStyle(fontSize: 11)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: rangeStart != null && rangeEnd != null
                          ? () {
                              ref.read(executiveFilterProvider.notifier).state = ref.read(executiveFilterProvider).copyWith(
                                startDate: rangeStart, endDate: rangeEnd,
                              );
                              Navigator.pop(ctx);
                            }
                          : null,
                      style: ElevatedButton.styleFrom(backgroundColor: ThemeConfig.primaryColor, foregroundColor: Colors.white),
                      child: const Text('Aplicar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================
// FILTER DROPDOWN WIDGET
// ============================================
class _FilterDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<DropdownMenuItem<String>>? items;
  final ValueChanged<String?>? onChanged;
  final VoidCallback? onClear;
  final VoidCallback? onTap;

  const _FilterDropdown({
    required this.label,
    this.value,
    this.items,
    this.onChanged,
    this.onClear,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value ?? label,
                style: TextStyle(fontSize: 12, color: value != null ? Colors.black : Colors.grey[600]),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.calendar_today, size: 14),
            ],
          ),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxWidth: 180),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: items?.any((i) => i.value == value) == true ? value : null,
                hint: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                isDense: true,
                isExpanded: true,
                items: items,
                onChanged: onChanged,
                style: const TextStyle(fontSize: 12, color: Colors.black),
              ),
            ),
          ),
          if (value != null && onClear != null)
            GestureDetector(
              onTap: onClear,
              child: const Icon(Icons.close, size: 14, color: Colors.grey),
            ),
        ],
      ),
    );
  }
}

// ============================================
// SECCIÓN: CONSULTAS (Dashboard Principal)
// ============================================
class _ConsultasSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kpisAsync = ref.watch(executiveKpisProvider);
    final monthlyAsync = ref.watch(executiveMonthlyProvider);
    final regionAsync = ref.watch(executiveByRegionProvider);
    final cityAsync = ref.watch(executiveByCityProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filtros de Consultas
          const _SectionFilters(showPeriodo: true, showRegion: true, showSucursal: true, showTipo: true, showMarca: true),
          const SizedBox(height: 16),
          // KPIs
          kpisAsync.when(
            data: (kpis) => _buildKpis(context, kpis),
            loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
            error: (e, _) => Text('Error: $e'),
          ),
          const SizedBox(height: 24),

          // Gráficos en grid responsivo
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 800;
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildMonthlyChart(context, ref, monthlyAsync),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: _buildCityPieChart(context, ref, cityAsync),
                    ),
                  ],
                );
              }
              return Column(
                children: [
                  _buildMonthlyChart(context, ref, monthlyAsync),
                  const SizedBox(height: 16),
                  _buildCityPieChart(context, ref, cityAsync),
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // Visitas por región
          _buildRegionChart(context, ref, regionAsync),
          const SizedBox(height: 16),

          // Mapa + KPIs de coordenadas
          kpisAsync.when(
            data: (kpis) => _buildMapSection(context, kpis),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildMapSection(BuildContext context, Map<String, dynamic> kpis) {
    final conCoords = kpis['clientesConCoords'] as int? ?? 0;
    final sinCoords = kpis['clientesSinCoords'] as int? ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // KPIs de coordenadas
        Row(
          children: [
            Expanded(
              child: Card(
                color: Colors.green[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.location_on, color: Colors.green[700], size: 28),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$conCoords', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green[700])),
                          Text('Clientes con coordenadas', style: TextStyle(fontSize: 11, color: Colors.green[600])),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Card(
                color: Colors.orange[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.location_off, color: Colors.orange[700], size: 28),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$sinCoords', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orange[700])),
                          Text('Sin coordenadas', style: TextStyle(fontSize: 11, color: Colors.orange[600])),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Mapa
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Mapa de clientes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 400,
                  child: _ClientsMap(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKpis(BuildContext context, Map<String, dynamic> kpis) {
    return Row(
      children: [
        Expanded(
          child: _KpiCard(
            title: 'Visitas Totales',
            value: _formatNumber(kpis['totalVisitas'] as int),
            color: ThemeConfig.primaryColor,
            icon: Icons.visibility,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _KpiCard(
            title: 'Clientes Visitados',
            value: _formatNumber(kpis['clientesVisitados'] as int),
            color: Colors.blue,
            icon: Icons.store,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _KpiCard(
            title: 'Inversión',
            value: '\$${_formatNumber(kpis['inversion'] as int? ?? 0)}',
            color: Colors.red[700]!,
            icon: Icons.attach_money,
          ),
        ),
      ],
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  Widget _buildMonthlyChart(BuildContext context, WidgetRef ref, AsyncValue<List<Map<String, dynamic>>> async) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Visitas por mes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: async.when(
                data: (data) {
                  if (data.isEmpty) return const Center(child: Text('Sin datos'));
                  final months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: data.length * 50.0 < 500 ? 500 : data.length * 50.0,
                      height: 280,
                      child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: data.map((d) => (d['count'] as int).toDouble()).reduce((a, b) => a > b ? a : b) * 1.2,
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final monthStr = data[groupIndex]['month'] as String;
                            return BarTooltipItem(
                              '$monthStr\n${rod.toY.toInt()}',
                              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 36,
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt();
                              if (idx >= 0 && idx < data.length) {
                                final monthStr = data[idx]['month'] as String;
                                final parts = monthStr.split('-');
                                final y = parts[0].substring(2); // "24", "25", "26"
                                final m = int.tryParse(parts[1]) ?? 1;
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(months[m - 1], style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w500)),
                                      Text("'$y", style: TextStyle(fontSize: 8, color: Colors.grey[500])),
                                    ],
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: true, reservedSize: 40,
                            getTitlesWidget: (v, _) => Text('${v.toInt()}', style: const TextStyle(fontSize: 10)),
                          ),
                        ),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: data.map((d) => (d['count'] as int).toDouble()).reduce((a, b) => a > b ? a : b) / 5,
                      ),
                      barGroups: List.generate(data.length, (i) {
                        return BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: (data[i]['count'] as int).toDouble(),
                              color: ThemeConfig.primaryColor,
                              width: 28,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(4),
                                topRight: Radius.circular(4),
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCityPieChart(BuildContext context, WidgetRef ref, AsyncValue<List<Map<String, dynamic>>> async) {
    final colors = [
      Colors.amber, Colors.red, Colors.blue, Colors.green, Colors.purple,
      Colors.orange, Colors.teal, Colors.pink, Colors.indigo, Colors.cyan,
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Registros por ciudad', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            SizedBox(
              height: 350,
              child: async.when(
                data: (data) {
                  if (data.isEmpty) return const Center(child: Text('Sin datos'));
                  final total = data.fold<int>(0, (sum, d) => sum + (d['count'] as int));
                  return Row(
                    children: [
                      Expanded(
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 30,
                            sections: List.generate(data.length.clamp(0, 10), (i) {
                              final pct = (data[i]['count'] as int) / total * 100;
                              return PieChartSectionData(
                                value: (data[i]['count'] as int).toDouble(),
                                title: pct > 5 ? '${pct.toStringAsFixed(1)}%' : '',
                                titleStyle: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                                color: colors[i % colors.length],
                                radius: 80,
                              );
                            }),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: List.generate(data.length.clamp(0, 8), (i) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(width: 10, height: 10, color: colors[i % colors.length]),
                                const SizedBox(width: 4),
                                Text(data[i]['city'] as String, style: const TextStyle(fontSize: 10)),
                              ],
                            ),
                          );
                        }),
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegionChart(BuildContext context, WidgetRef ref, AsyncValue<List<Map<String, dynamic>>> async) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Visitas por región', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: async.when(
                data: (data) {
                  if (data.isEmpty) return const Center(child: Text('Sin datos'));
                  final regionColors = {
                    'Centro-Llanos': Colors.amber[700]!,
                    'Occidente': Colors.red[700]!,
                    'Oriente': Colors.blue[700]!,
                    'Centro-Capital': Colors.green[700]!,
                  };
                  return BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: data.map((d) => (d['count'] as int).toDouble()).reduce((a, b) => a > b ? a : b) * 1.2,
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            return BarTooltipItem(
                              '${data[groupIndex]['region']}\n${rod.toY.toInt()}',
                              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, _) {
                              final idx = value.toInt();
                              if (idx >= 0 && idx < data.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    data[idx]['region'] as String,
                                    style: const TextStyle(fontSize: 10),
                                    textAlign: TextAlign.center,
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: true, reservedSize: 40,
                            getTitlesWidget: (v, _) => Text('${v.toInt()}', style: const TextStyle(fontSize: 10)),
                          ),
                        ),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      gridData: const FlGridData(show: true, drawVerticalLine: false),
                      barGroups: List.generate(data.length, (i) {
                        final region = data[i]['region'] as String;
                        return BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: (data[i]['count'] as int).toDouble(),
                              color: regionColors[region] ?? Colors.grey,
                              width: 40,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(4),
                                topRight: Radius.circular(4),
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// SECCIÓN: INVENTARIO POP
// ============================================

/// Provider: stock completo de todas las sedes
final _allStockProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final sb = SupabaseConfig.client;
  final data = await sb
      .from('pop_stock')
      .select('*, pop_materials(*)')
      .order('sede_app');
  return (data as List).map((e) => e as Map<String, dynamic>).toList();
});

/// Provider: movimientos con ciudad
final _allMovementsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final sb = SupabaseConfig.client;
  final data = await sb
      .from('pop_movements')
      .select('*, pop_materials(*)')
      .order('created_at', ascending: false)
      .limit(500);
  return (data as List).map((e) => e as Map<String, dynamic>).toList();
});

class _InventarioPopSection extends ConsumerStatefulWidget {
  const _InventarioPopSection();

  @override
  ConsumerState<_InventarioPopSection> createState() => _InventarioPopSectionState();
}

class _InventarioPopSectionState extends ConsumerState<_InventarioPopSection> {
  String? _filterRegion;
  String? _filterMarca;
  String _searchText = '';
  String _vista = 'sucursal'; // sucursal, region, global

  static const _sedeNames = {
    'grupo_disbattery': 'Centro-Capital',
    'oceano_pacifico': 'Oriente',
    'blitz_2000': 'Centro-Llanos',
    'grupo_victoria': 'Occidente',
  };

  @override
  Widget build(BuildContext context) {
    final stockAsync = ref.watch(_allStockProvider);

    return Column(
      children: [
        // Vista selector + filtros
        Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // Vista
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'sucursal', label: Text('Por Sucursal', style: TextStyle(fontSize: 11))),
                  ButtonSegment(value: 'region', label: Text('Por Región', style: TextStyle(fontSize: 11))),
                  ButtonSegment(value: 'global', label: Text('Global', style: TextStyle(fontSize: 11))),
                ],
                selected: {_vista},
                onSelectionChanged: (v) => setState(() => _vista = v.first),
                style: ButtonStyle(visualDensity: VisualDensity.compact),
              ),
              const SizedBox(width: 8),
              // Marca
              ChoiceChip(label: const Text('Shell', style: TextStyle(fontSize: 11)), selected: _filterMarca == 'SHELL',
                  onSelected: (v) => setState(() => _filterMarca = v ? 'SHELL' : null)),
              ChoiceChip(label: const Text('Qualid', style: TextStyle(fontSize: 11)), selected: _filterMarca == 'QUALID',
                  onSelected: (v) => setState(() => _filterMarca = v ? 'QUALID' : null)),
              // Buscador
              SizedBox(
                width: 200,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Buscar material...',
                    isDense: true,
                    prefixIcon: const Icon(Icons.search, size: 16),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                  onChanged: (v) => setState(() => _searchText = v.toLowerCase()),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),

        // Contenido
        Expanded(
          child: stockAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (allStock) {
              // Aplicar filtros globales
              final globalFilter = ref.watch(executiveFilterProvider);
              final globalRegion = globalFilter.region;

              var filtered = allStock.where((s) {
                final mat = s['pop_materials'] as Map<String, dynamic>?;
                if (mat == null) return false;
                if (_filterMarca != null && mat['marca'] != _filterMarca) return false;
                if (_searchText.isNotEmpty && !(mat['nombre'] as String).toLowerCase().contains(_searchText)) return false;
                // Filtro global de región
                if (globalRegion != null && s['sede_app'] != globalRegion) return false;
                return true;
              }).toList();

              if (_vista == 'region') {
                return _buildRegionView(filtered);
              } else if (_vista == 'global') {
                return _buildGlobalView(filtered);
              }
              return _buildSucursalView(filtered);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSucursalView(List<Map<String, dynamic>> stock) {
    // Agrupar por sede
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final s in stock) {
      final sede = _sedeNames[s['sede_app']] ?? s['sede_app'] as String;
      grouped.putIfAbsent(sede, () => []).add(s);
    }

    if (grouped.isEmpty) return const Center(child: Text('Sin stock'));

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        // Gráficos pie
        _buildPieCharts(stock),
        const SizedBox(height: 16),
        // Tabla por sucursal
        ...grouped.entries.map((entry) {
          final total = entry.value.fold<int>(0, (sum, s) => sum + (s['cantidad'] as int? ?? 0));
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                  ),
                  child: Row(
                    children: [
                      Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const Spacer(),
                      Text('Total: $total', style: TextStyle(fontWeight: FontWeight.bold, color: total < 0 ? Colors.red : Colors.green[700])),
                    ],
                  ),
                ),
                _buildStockTable(entry.value),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildRegionView(List<Map<String, dynamic>> stock) {
    // Agrupar por sede y sumar
    final regionTotals = <String, Map<String, int>>{};
    for (final s in stock) {
      final sede = _sedeNames[s['sede_app']] ?? s['sede_app'] as String;
      final mat = s['pop_materials'] as Map<String, dynamic>?;
      if (mat == null) continue;
      final nombre = mat['nombre'] as String;
      regionTotals.putIfAbsent(sede, () => {});
      regionTotals[sede]![nombre] = (regionTotals[sede]![nombre] ?? 0) + (s['cantidad'] as int? ?? 0);
    }

    if (regionTotals.isEmpty) return const Center(child: Text('Sin stock'));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildPieCharts(stock),
        const SizedBox(height: 16),
        ...regionTotals.entries.map((entry) {
          final total = entry.value.values.fold<int>(0, (a, b) => a + b);
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.grey[100],
                  child: Row(
                    children: [
                      Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Text('Total: $total', style: TextStyle(fontWeight: FontWeight.bold, color: total < 0 ? Colors.red : Colors.green[700])),
                    ],
                  ),
                ),
                ...entry.value.entries.map((mat) => ListTile(
                  dense: true,
                  title: Text(mat.key, style: const TextStyle(fontSize: 12)),
                  trailing: Text('${mat.value}', style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: mat.value < 0 ? Colors.red : mat.value <= 5 ? Colors.orange : Colors.green[700],
                  )),
                )),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildGlobalView(List<Map<String, dynamic>> stock) {
    // Sumar todo sin agrupar por sede
    final globalTotals = <String, Map<String, dynamic>>{};
    for (final s in stock) {
      final mat = s['pop_materials'] as Map<String, dynamic>?;
      if (mat == null) continue;
      final nombre = mat['nombre'] as String;
      if (!globalTotals.containsKey(nombre)) {
        globalTotals[nombre] = {
          'nombre': nombre,
          'marca': mat['marca'],
          'tipo': mat['tipo_material'],
          'unidad': mat['unidad_medida'] ?? 'unidad',
          'costo': (mat['costo_unitario'] as num?)?.toDouble() ?? 0,
          'stock': 0,
        };
      }
      globalTotals[nombre]!['stock'] = (globalTotals[nombre]!['stock'] as int) + (s['cantidad'] as int? ?? 0);
    }

    final sorted = globalTotals.values.toList()..sort((a, b) => (a['nombre'] as String).compareTo(b['nombre'] as String));

    if (sorted.isEmpty) return const Center(child: Text('Sin stock'));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildPieCharts(stock),
        const SizedBox(height: 16),
        Card(
          child: DataTable(
            columnSpacing: 16,
            headingRowColor: WidgetStateProperty.all(ThemeConfig.primaryColor),
            headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
            dataTextStyle: const TextStyle(fontSize: 11),
            columns: const [
              DataColumn(label: Text('MATERIAL')),
              DataColumn(label: Text('MARCA')),
              DataColumn(label: Text('TIPO')),
              DataColumn(label: Text('STOCK'), numeric: true),
            ],
            rows: sorted.map((m) {
              final stock = m['stock'] as int;
              return DataRow(cells: [
                DataCell(Text(m['nombre'] as String)),
                DataCell(Text(m['marca'] as String)),
                DataCell(Text(m['tipo'] as String)),
                DataCell(Text('$stock', style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: stock < 0 ? Colors.red : stock <= 5 ? Colors.orange : Colors.green[700],
                ))),
              ]);
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildStockTable(List<Map<String, dynamic>> items) {
    return Column(
      children: items.map((s) {
        final mat = s['pop_materials'] as Map<String, dynamic>?;
        if (mat == null) return const SizedBox.shrink();
        final qty = s['cantidad'] as int? ?? 0;
        return ListTile(
          dense: true,
          leading: Icon(
            mat['marca'] == 'SHELL' ? Icons.local_gas_station : Icons.build,
            color: mat['marca'] == 'SHELL' ? Colors.red[300] : Colors.blue[300],
            size: 16,
          ),
          title: Text(mat['nombre'] as String, style: const TextStyle(fontSize: 12)),
          subtitle: Text(mat['tipo_material'] as String, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
          trailing: Text(
            '$qty',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: qty < 0 ? Colors.red : qty <= 5 ? Colors.orange : Colors.green[700],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPieCharts(List<Map<String, dynamic>> stock) {
    // Materiales por región
    final regionCounts = <String, int>{};
    final typeCounts = <String, int>{};
    for (final s in stock) {
      final sede = _sedeNames[s['sede_app']] ?? s['sede_app'] as String;
      final mat = s['pop_materials'] as Map<String, dynamic>?;
      if (mat == null) continue;
      final qty = (s['cantidad'] as int? ?? 0).abs();
      regionCounts[sede] = (regionCounts[sede] ?? 0) + qty;
      final tipo = mat['tipo_material'] as String;
      typeCounts[tipo] = (typeCounts[tipo] ?? 0) + qty;
    }

    final regionColors = {
      'Centro-Llanos': Colors.amber[700]!,
      'Occidente': Colors.red[400]!,
      'Oriente': Colors.blue[400]!,
      'Centro-Capital': Colors.green[400]!,
    };
    final typeColors = {'MERCHANDISING': Colors.teal, 'TRADE': Colors.orange};

    return Row(
      children: [
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  const Text('Materiales por región', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 150,
                    child: _buildMiniPie(regionCounts, regionColors),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  const Text('Tipo de materiales', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 150,
                    child: _buildMiniPie(typeCounts, typeColors),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniPie(Map<String, int> data, Map<String, Color> colors) {
    if (data.isEmpty) return const Center(child: Text('Sin datos'));
    final total = data.values.fold<int>(0, (a, b) => a + b);
    if (total == 0) return const Center(child: Text('Sin datos'));

    final defaultColors = [Colors.amber, Colors.red, Colors.blue, Colors.green, Colors.purple, Colors.teal];

    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 20,
              sections: data.entries.toList().asMap().entries.map((entry) {
                final i = entry.key;
                final e = entry.value;
                final pct = e.value / total * 100;
                return PieChartSectionData(
                  value: e.value.toDouble(),
                  title: pct > 8 ? '${pct.toStringAsFixed(0)}%' : '',
                  titleStyle: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                  color: colors[e.key] ?? defaultColors[i % defaultColors.length],
                  radius: 40,
                );
              }).toList(),
            ),
          ),
        ),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: data.entries.toList().asMap().entries.map((entry) {
            final i = entry.key;
            final e = entry.value;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 8, height: 8, color: colors[e.key] ?? defaultColors[i % defaultColors.length]),
                  const SizedBox(width: 4),
                  Text(e.key, style: const TextStyle(fontSize: 9)),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ============================================
// SECCIÓN: ARTÍCULOS ENTREGADOS
// ============================================

/// Columnas de materiales en tablas de merchandising
const _merchMaterialColumns = {
  'total_cenefas_shell': {'name': 'Cenefas Shell', 'marca': 'SHELL'},
  'total_papel_bobina_shell': {'name': 'Papel Bobina Shell', 'marca': 'SHELL'},
  'total_stickers_cambio_lubricante': {'name': 'Stickers Cambio Lubricante', 'marca': 'SHELL'},
  'total_ambientadores_shell': {'name': 'Ambientadores Shell', 'marca': 'SHELL'},
  'total_bolsas_shell': {'name': 'Bolsas Shell', 'marca': 'SHELL'},
  'total_banderines_shell': {'name': 'Banderines Shell', 'marca': 'SHELL'},
  'coloco_sticker_shell': {'name': 'Sticker Autorizado Shell', 'marca': 'SHELL'},
  'total_cenefas_qualid': {'name': 'Cenefas Qualid', 'marca': 'QUALID'},
  'total_bolsas_qualid': {'name': 'Bolsas Qualid', 'marca': 'QUALID'},
  'total_exhibidor_caucho_pequeno': {'name': 'Exhibidor Caucho Peq.', 'marca': 'QUALID'},
  'total_exhibidor_caucho_grande': {'name': 'Exhibidor Caucho Grande', 'marca': 'QUALID'},
};

/// Columnas de materiales en tablas de trade
const _tradeMaterialColumns = {
  'total_ambientadores_shell': {'name': 'Ambientadores Shell', 'marca': 'SHELL'},
  'total_bolsas_shell': {'name': 'Bolsas Shell', 'marca': 'SHELL'},
  'total_llaveros_tela_shell': {'name': 'Llaveros Tela Shell', 'marca': 'SHELL'},
  'total_gorras_shell': {'name': 'Gorras Shell', 'marca': 'SHELL'},
  'total_bolsas_boutique_negro': {'name': 'Bolsas Boutique Negro', 'marca': 'SHELL'},
  'total_bolsas_boutique_blanco': {'name': 'Bolsas Boutique Blanco', 'marca': 'SHELL'},
  'total_tapasol': {'name': 'Tapasol Shell/Qualid', 'marca': 'SHELL'},
  'total_globos_shell': {'name': 'Globos Shell', 'marca': 'SHELL'},
  'total_vasos_shell': {'name': 'Vasos Shell', 'marca': 'SHELL'},
  'total_agendas': {'name': 'Agendas', 'marca': 'SHELL'},
  'total_bolsas_qualid': {'name': 'Bolsas Qualid', 'marca': 'QUALID'},
  'total_esponjas_qualid': {'name': 'Esponjas Qualid', 'marca': 'QUALID'},
  'total_globos_qualid': {'name': 'Globos Qualid', 'marca': 'QUALID'},
  'total_gorras_qualid': {'name': 'Gorras Qualid', 'marca': 'QUALID'},
  'total_llavero_caucho_qualid': {'name': 'Llavero Caucho Qualid', 'marca': 'QUALID'},
  'total_llaveros_tela_qualid': {'name': 'Llaveros Tela Qualid', 'marca': 'QUALID'},
  'total_panos_qualid': {'name': 'Paños Qualid', 'marca': 'QUALID'},
  'total_vasos_qualid': {'name': 'Vasos Qualid', 'marca': 'QUALID'},
};

/// Provider: artículos entregados agregados
final _articulosEntregadosProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final filter = ref.watch(executiveFilterProvider);
  final sb = SupabaseConfig.client;

  final materialTotals = <String, int>{};
  final regionTotals = <String, int>{};
  final cityTotals = <String, int>{};
  final clientTotals = <String, Map<String, int>>{}; // cliente -> {material: qty}

  final sedeNames = {
    'blitz': 'Centro-Llanos',
    'grupo_victoria': 'Occidente',
    'oriente': 'Oriente',
    'grupo_disbattery': 'Centro-Capital',
  };

  // Procesar merchandising
  final merchTables = _getTablesForFilter(filter, 'merchandising');
  for (final table in merchTables) {
    try {
      final cols = ['sucursal', 'nombre_establecimiento', ..._merchMaterialColumns.keys].join(',');
      var query = sb.from(table).select(cols).eq('source', 'app').not('email', 'in', _testEmails);
      if (filter.startDate != null) query = query.gte('fecha', filter.startDate!.toIso8601String());
      if (filter.endDate != null) query = query.lte('fecha', filter.endDate!.add(const Duration(days: 1)).toIso8601String());
      if (filter.ciudad != null) query = query.eq('sucursal', filter.ciudad!);
      if (filter.mercaderista != null) query = query.eq('email', filter.mercaderista!);
      final data = await query;
      final prefix = table.replaceAll('_merchandising', '').replaceAll('_trade', '');
      final regionName = sedeNames[prefix] ?? prefix;

      for (final row in (data as List)) {
        final ciudad = (row['sucursal'] as String?) ?? 'Sin ciudad';
        var cliente = (row['nombre_establecimiento'] as String?) ?? '';
        if (cliente.isEmpty || cliente == '-') cliente = 'Sin nombre';

        for (final entry in _merchMaterialColumns.entries) {
          final meta = entry.value as Map<String, String>;
          if (filter.marca != null && meta['marca'] != filter.marca) continue;
          final val = (row[entry.key] as num?)?.toInt() ?? 0;
          if (val > 0) {
            final name = meta['name']!;
            materialTotals[name] = (materialTotals[name] ?? 0) + val;
            regionTotals[regionName] = (regionTotals[regionName] ?? 0) + val;
            cityTotals[ciudad] = (cityTotals[ciudad] ?? 0) + val;
            clientTotals.putIfAbsent(cliente, () => {});
            clientTotals[cliente]![name] = (clientTotals[cliente]![name] ?? 0) + val;
          }
        }
      }
    } catch (_) {}
  }

  // Procesar trade
  final tradeTables = _getTablesForFilter(filter, 'trade');
  for (final table in tradeTables) {
    try {
      final cols = ['sucursal', 'nombre_establecimiento', ..._tradeMaterialColumns.keys].join(',');
      var query = sb.from(table).select(cols).eq('source', 'app').not('email', 'in', _testEmails);
      if (filter.startDate != null) query = query.gte('fecha', filter.startDate!.toIso8601String());
      if (filter.endDate != null) query = query.lte('fecha', filter.endDate!.add(const Duration(days: 1)).toIso8601String());
      if (filter.ciudad != null) query = query.eq('sucursal', filter.ciudad!);
      if (filter.mercaderista != null) query = query.eq('email', filter.mercaderista!);
      final data = await query;
      final prefix = table.replaceAll('_trade', '');
      final regionName = sedeNames[prefix] ?? prefix;

      for (final row in (data as List)) {
        final ciudad = (row['sucursal'] as String?) ?? 'Sin ciudad';
        var cliente = (row['nombre_establecimiento'] as String?) ?? '';
        if (cliente.isEmpty || cliente == '-') cliente = 'Sin nombre';

        for (final entry in _tradeMaterialColumns.entries) {
          final meta = entry.value as Map<String, String>;
          if (filter.marca != null && meta['marca'] != filter.marca) continue;
          final val = (row[entry.key] as num?)?.toInt() ?? 0;
          if (val > 0) {
            final name = meta['name']!;
            materialTotals[name] = (materialTotals[name] ?? 0) + val;
            regionTotals[regionName] = (regionTotals[regionName] ?? 0) + val;
            cityTotals[ciudad] = (cityTotals[ciudad] ?? 0) + val;
            clientTotals.putIfAbsent(cliente, () => {});
            clientTotals[cliente]![name] = (clientTotals[cliente]![name] ?? 0) + val;
          }
        }
      }
    } catch (_) {}
  }

  return {
    'materials': materialTotals,
    'regions': regionTotals,
    'cities': cityTotals,
    'clients': clientTotals,
  };
});

class _ArticulosEntregadosSection extends ConsumerWidget {
  const _ArticulosEntregadosSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(_articulosEntregadosProvider);

    return dataAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (data) {
        final materials = data['materials'] as Map<String, int>;
        final regions = data['regions'] as Map<String, int>;
        final cities = data['cities'] as Map<String, int>;
        final clients = data['clients'] as Map<String, Map<String, int>>;

        final totalEntregado = materials.values.fold<int>(0, (a, b) => a + b);

        final pieColors = [
          Colors.red, Colors.amber, Colors.blue, Colors.green, Colors.purple,
          Colors.orange, Colors.teal, Colors.pink, Colors.indigo, Colors.cyan,
          Colors.brown, Colors.lime,
        ];

        final regionColors = {
          'Centro-Llanos': Colors.amber[700]!,
          'Occidente': Colors.red[400]!,
          'Oriente': Colors.blue[400]!,
          'Centro-Capital': Colors.green[400]!,
        };

        final sortedMaterials = materials.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final sortedCities = cities.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Filtros de Artículos Entregados
              const _SectionFilters(showPeriodo: true, showRegion: true, showSucursal: true, showMarca: true),
              const SizedBox(height: 16),
              // 3 Gráficos pie
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 900;
                  final pies = [
                    _buildPieCard('Artículos', sortedMaterials.take(10).toList(), pieColors, totalEntregado),
                    _buildPieCard('Regiones', regions.entries.toList(), regionColors.values.toList(), totalEntregado, colorMap: regionColors),
                    _buildPieCard('Ciudades', sortedCities.take(10).toList(), pieColors, totalEntregado),
                  ];

                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: pies.map((p) => Expanded(child: p)).toList(),
                    );
                  }
                  return Column(children: pies);
                },
              ),
              const SizedBox(height: 16),

              // Tablas lado a lado con scroll propio
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 800;
                  final materialTable = SizedBox(
                    height: 400,
                    child: _buildMaterialTable(sortedMaterials, totalEntregado),
                  );
                  final clientTable = SizedBox(
                    height: 400,
                    child: _buildClientTable(clients),
                  );

                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: Padding(padding: const EdgeInsets.only(right: 4), child: materialTable)),
                        Expanded(child: Padding(padding: const EdgeInsets.only(left: 4), child: clientTable)),
                      ],
                    );
                  }
                  return Column(children: [
                    materialTable,
                    const SizedBox(height: 16),
                    clientTable,
                  ]);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPieCard(String title, List<MapEntry<String, int>> entries, List<Color> colors, int total, {Map<String, Color>? colorMap}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: entries.isEmpty
                  ? const Center(child: Text('Sin datos'))
                  : Row(
                      children: [
                        Expanded(
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 2,
                              centerSpaceRadius: 25,
                              sections: entries.asMap().entries.map((e) {
                                final i = e.key;
                                final entry = e.value;
                                final pct = total > 0 ? entry.value / total * 100 : 0;
                                return PieChartSectionData(
                                  value: entry.value.toDouble(),
                                  title: pct > 5 ? '${pct.toStringAsFixed(0)}%' : '',
                                  titleStyle: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                                  color: colorMap?[entry.key] ?? colors[i % colors.length],
                                  radius: 50,
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: entries.asMap().entries.take(8).map((e) {
                            final i = e.key;
                            final entry = e.value;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 1),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(width: 8, height: 8, color: colorMap?[entry.key] ?? colors[i % colors.length]),
                                  const SizedBox(width: 4),
                                  SizedBox(
                                    width: 100,
                                    child: Text(entry.key, style: const TextStyle(fontSize: 8), overflow: TextOverflow.ellipsis),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialTable(List<MapEntry<String, int>> materials, int total) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Cantidad entregada', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: DataTable(
                columnSpacing: 16,
                headingRowColor: WidgetStateProperty.all(Colors.amber[700]),
                headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                dataTextStyle: const TextStyle(fontSize: 11),
                columns: const [
                  DataColumn(label: Text('ARTÍCULO')),
                  DataColumn(label: Text('CANTIDAD'), numeric: true),
                ],
                rows: [
                  ...materials.map((m) => DataRow(cells: [
                    DataCell(Text(m.key)),
                    DataCell(Text('${m.value}')),
                  ])),
                  DataRow(
                    color: WidgetStateProperty.all(Colors.red[50]),
                    cells: [
                      const DataCell(Text('Total', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red))),
                      DataCell(Text('$total', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red))),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClientTable(Map<String, Map<String, int>> clients) {
    // Top 20 clientes por total de entregas
    final sorted = clients.entries.map((e) {
      final totalQty = e.value.values.fold<int>(0, (a, b) => a + b);
      return MapEntry(e.key, {'items': e.value, 'total': totalQty});
    }).toList()
      ..sort((a, b) => (b.value['total'] as int).compareTo(a.value['total'] as int));

    final top = sorted.take(20).toList();
    final grandTotal = top.fold<int>(0, (sum, e) => sum + (e.value['total'] as int));

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Cantidad de entregas por cliente', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: DataTable(
              columnSpacing: 12,
              headingRowColor: WidgetStateProperty.all(Colors.red[700]),
              headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
              dataTextStyle: const TextStyle(fontSize: 10),
              columns: const [
                DataColumn(label: Text('CLIENTE')),
                DataColumn(label: Text('ARTÍCULO')),
                DataColumn(label: Text('CANT.'), numeric: true),
              ],
              rows: [
                ...top.expand((client) {
                  final items = client.value['items'] as Map<String, int>;
                  final sortedItems = items.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
                  return sortedItems.take(3).map((item) => DataRow(cells: [
                    DataCell(SizedBox(width: 120, child: Text(client.key, overflow: TextOverflow.ellipsis))),
                    DataCell(Text(item.key)),
                    DataCell(Text('${item.value}')),
                  ]));
                }),
                DataRow(
                  color: WidgetStateProperty.all(Colors.red[50]),
                  cells: [
                    const DataCell(Text('Total', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red))),
                    const DataCell(Text('')),
                    DataCell(Text('$grandTotal', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red))),
                  ],
                ),
              ],
            ),
          ),
          ),
        ],
      ),
    );
  }
}

// ============================================
// SECCIÓN: DETALLES MERCHANDISING
// ============================================

final _detallesMerchaProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final filter = ref.watch(executiveFilterProvider);
  final sb = SupabaseConfig.client;

  final rows = <Map<String, dynamic>>[];
  int totalClientes = 0;
  int clientesConSticker = 0;
  int clientesConExhibidor = 0;

  final sedeNames = {
    'blitz': 'Centro-Llanos',
    'grupo_victoria': 'Occidente',
    'oriente': 'Oriente',
    'grupo_disbattery': 'Centro-Capital',
  };

  final tables = _getTablesForFilter(filter, 'merchandising');
  for (final table in tables) {
    try {
      var query = sb.from(table).select(
        'sucursal, nombre_establecimiento, email, fecha, '
        'coloco_sticker_shell, total_stickers_cambio_lubricante, '
        'total_cenefas_shell, total_papel_bobina_shell, total_banderines_shell, '
        'total_ambientadores_shell, total_bolsas_shell, '
        'cliente_tiene_exhibidores_shell, cliente_tiene_aviso_acrilico_shell, '
        'afiches_campana_hx8, afiches_campana_shell_familia_2023, '
        'afiches_campana_shell_hx7_10w40, afiches_campana_tabla_aplicacion_shell, '
        'afiche_shell_helix, afiche_shell_rimula, afiche_shell_advance'
      ).eq('source', 'app').not('email', 'in', _testEmails);
      if (filter.startDate != null) query = query.gte('fecha', filter.startDate!.toIso8601String());
      if (filter.endDate != null) query = query.lte('fecha', filter.endDate!.add(const Duration(days: 1)).toIso8601String());
      if (filter.ciudad != null) query = query.eq('sucursal', filter.ciudad!);
      if (filter.mercaderista != null) query = query.eq('email', filter.mercaderista!);
      final data = await query;
      final prefix = table.replaceAll('_merchandising', '');
      final regionName = sedeNames[prefix] ?? prefix;

      for (final row in (data as List)) {
        final sticker = (row['coloco_sticker_shell'] as num?)?.toInt() ?? 0;
        final exhibidor = (row['cliente_tiene_exhibidores_shell'] as String?) == 'Si';
        final afiches = [
          (row['afiches_campana_hx8'] as num?)?.toInt() ?? 0,
          (row['afiches_campana_shell_familia_2023'] as num?)?.toInt() ?? 0,
          (row['afiches_campana_shell_hx7_10w40'] as num?)?.toInt() ?? 0,
          (row['afiches_campana_tabla_aplicacion_shell'] as num?)?.toInt() ?? 0,
          (row['afiche_shell_helix'] as num?)?.toInt() ?? 0,
          (row['afiche_shell_rimula'] as num?)?.toInt() ?? 0,
          (row['afiche_shell_advance'] as num?)?.toInt() ?? 0,
        ].fold<int>(0, (a, b) => a + b);

        totalClientes++;
        if (sticker > 0) clientesConSticker++;
        if (exhibidor) clientesConExhibidor++;

        rows.add({
          'region': regionName,
          'sucursal': row['sucursal'] ?? '',
          'cliente': row['nombre_establecimiento'] ?? 'Sin nombre',
          'mercaderista': row['email'] ?? '',
          'fecha': row['fecha'] ?? '',
          'sticker_autorizado': sticker,
          'sticker_cambio': (row['total_stickers_cambio_lubricante'] as num?)?.toInt() ?? 0,
          'afiches': afiches,
          'avisos': (row['cliente_tiene_aviso_acrilico_shell'] as String?) == 'Si' ? 1 : 0,
          'banderines': (row['total_banderines_shell'] as num?)?.toInt() ?? 0,
          'cenefas': (row['total_cenefas_shell'] as num?)?.toInt() ?? 0,
          'exhibidores': exhibidor ? 1 : 0,
          'papel_bobina': (row['total_papel_bobina_shell'] as num?)?.toInt() ?? 0,
        });
      }
    } catch (_) {}
  }

  return {
    'rows': rows,
    'totalClientes': totalClientes,
    'clientesConSticker': clientesConSticker,
    'clientesConExhibidor': clientesConExhibidor,
  };
});

class _DetallesMerchaSection extends ConsumerWidget {
  const _DetallesMerchaSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(_detallesMerchaProvider);

    return dataAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (data) {
        final rows = data['rows'] as List<Map<String, dynamic>>;
        final totalClientes = data['totalClientes'] as int;
        final clientesConSticker = data['clientesConSticker'] as int;
        final clientesConExhibidor = data['clientesConExhibidor'] as int;

        return Column(
          children: [
            // Filtros
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _SectionFilters(showPeriodo: true, showRegion: true, showSucursal: true, showMarca: true),
            ),
            // KPIs
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: _KpiCard(
                      title: 'Clientes Totales',
                      value: '$totalClientes',
                      color: ThemeConfig.primaryColor,
                      icon: Icons.store,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _KpiCard(
                      title: 'Clientes con Sticker',
                      value: '$clientesConSticker',
                      color: Colors.amber[700]!,
                      icon: Icons.verified,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _KpiCard(
                      title: 'Clientes con Exhibidor',
                      value: '$clientesConExhibidor',
                      color: Colors.blue,
                      icon: Icons.storefront,
                    ),
                  ),
                ],
              ),
            ),

            // Tabla detallada con scroll propio
            Expanded(
              child: Card(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Text('Material POP & Detalle de los clientes',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const Spacer(),
                          Text('${rows.length} registros',
                              style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: 1400,
                          child: SingleChildScrollView(
                            child: DataTable(
                              columnSpacing: 10,
                              dataRowMinHeight: 36,
                              dataRowMaxHeight: 52,
                              headingRowColor: WidgetStateProperty.all(ThemeConfig.primaryColor),
                              headingTextStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                              dataTextStyle: const TextStyle(fontSize: 10),
                              columns: const [
                                DataColumn(label: Text('REGIÓN')),
                                DataColumn(label: Text('SUCURSAL')),
                                DataColumn(label: Text('CLIENTE')),
                                DataColumn(label: Text('MERCADERISTA')),
                                DataColumn(label: Text('FECHA')),
                                DataColumn(label: Text('STICKER\nAUTORIZADO'), numeric: true),
                                DataColumn(label: Text('STICKER\nCAMBIO LUB.'), numeric: true),
                                DataColumn(label: Text('AFICHES'), numeric: true),
                                DataColumn(label: Text('AVISOS'), numeric: true),
                                DataColumn(label: Text('BANDERINES'), numeric: true),
                                DataColumn(label: Text('CENEFAS'), numeric: true),
                                DataColumn(label: Text('EXHIBIDORES'), numeric: true),
                                DataColumn(label: Text('PAPEL\nBOBINA'), numeric: true),
                              ],
                              rows: rows.take(500).map((r) {
                                final fecha = DateTime.tryParse(r['fecha'] as String? ?? '');
                                final fechaStr = fecha != null
                                    ? '${fecha.day}/${fecha.month}/${fecha.year}'
                                    : '';
                                return DataRow(cells: [
                                  DataCell(Text(r['region'] as String)),
                                  DataCell(Text(r['sucursal'] as String)),
                                  DataCell(SizedBox(
                                    width: 180,
                                    child: Text(r['cliente'] as String,
                                        overflow: TextOverflow.ellipsis, maxLines: 2),
                                  )),
                                  DataCell(SizedBox(
                                    width: 150,
                                    child: Text(r['mercaderista'] as String,
                                        overflow: TextOverflow.ellipsis),
                                  )),
                                  DataCell(Text(fechaStr)),
                                  DataCell(Text('${r['sticker_autorizado']}')),
                                  DataCell(Text('${r['sticker_cambio']}')),
                                  DataCell(Text('${r['afiches']}')),
                                  DataCell(Text('${r['avisos']}')),
                                  DataCell(Text('${r['banderines']}')),
                                  DataCell(Text('${r['cenefas']}')),
                                  DataCell(Text('${r['exhibidores']}')),
                                  DataCell(Text('${r['papel_bobina']}')),
                                ]);
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }
}

// ============================================
// SECCIÓN: DETALLES TRADE
// ============================================

final _detallesTradeProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final filter = ref.watch(executiveFilterProvider);
  final sb = SupabaseConfig.client;

  final rows = <Map<String, dynamic>>[];
  int totalActivaciones = 0;
  double totalVentasShell = 0;
  double totalVentasQualid = 0;

  final sedeNames = {
    'blitz': 'Centro-Llanos',
    'grupo_victoria': 'Occidente',
    'oriente': 'Oriente',
    'grupo_disbattery': 'Centro-Capital',
  };

  final tables = _getTablesForFilter(filter, 'trade');
  for (final table in tables) {
    try {
      var query = sb.from(table).select(
        'sucursal, nombre_establecimiento, email, fecha, tipo_registro, marca_promocionada, '
        'uniformes_promotoras_shell, banderolas_shell, igloo_shell, toldo_shell, exhibidores_shell, '
        'uniformes_promotoras_qualid, banderolas_qualid, igloo_qualid, toldo_qualid, '
        'total_ambientadores_shell, total_bolsas_shell, total_gorras_shell, total_vasos_shell, '
        'total_llaveros_tela_shell, total_tapasol, total_agendas, '
        'total_bolsas_qualid, total_esponjas_qualid, total_gorras_qualid, total_vasos_qualid, '
        'total_llavero_caucho_qualid, total_llaveros_tela_qualid, total_panos_qualid, '
        'reporto_venta_shell, litros_shell_advance, litros_shell_hx5, litros_shell_hx7, '
        'litros_shell_hx8, litros_shell_ultra, litros_shell_rimula, litros_shell_spirax, '
        'cartuchos_shell_gadus, litros_shell_otros, '
        'reporto_venta_qualid, litros_qualid_fluidos, unidades_qualid_spray, '
        'unidades_qualid_filtro_automotriz, unidades_qualid_servicio_pesado, unidades_qualid_cauchos, '
        'source'
      ).eq('source', 'app').not('email', 'in', _testEmails);
      if (filter.startDate != null) query = query.gte('fecha', filter.startDate!.toIso8601String());
      if (filter.endDate != null) query = query.lte('fecha', filter.endDate!.add(const Duration(days: 1)).toIso8601String());
      if (filter.ciudad != null) query = query.eq('sucursal', filter.ciudad!);
      if (filter.mercaderista != null) query = query.eq('email', filter.mercaderista!);
      final data = await query;
      final prefix = table.replaceAll('_trade', '');
      final regionName = sedeNames[prefix] ?? prefix;

      for (final row in (data as List)) {
        totalActivaciones++;

        // Calcular totales material de apoyo
        final apoyoShell = [
          (row['uniformes_promotoras_shell'] as num?)?.toInt() ?? 0,
          (row['banderolas_shell'] as num?)?.toInt() ?? 0,
          (row['igloo_shell'] as num?)?.toInt() ?? 0,
          (row['toldo_shell'] as num?)?.toInt() ?? 0,
          (row['exhibidores_shell'] as num?)?.toInt() ?? 0,
        ].fold<int>(0, (a, b) => a + b);

        final apoyoQualid = [
          (row['uniformes_promotoras_qualid'] as num?)?.toInt() ?? 0,
          (row['banderolas_qualid'] as num?)?.toInt() ?? 0,
          (row['igloo_qualid'] as num?)?.toInt() ?? 0,
          (row['toldo_qualid'] as num?)?.toInt() ?? 0,
        ].fold<int>(0, (a, b) => a + b);

        // Entregables
        final entregShell = [
          (row['total_ambientadores_shell'] as num?)?.toInt() ?? 0,
          (row['total_bolsas_shell'] as num?)?.toInt() ?? 0,
          (row['total_gorras_shell'] as num?)?.toInt() ?? 0,
          (row['total_vasos_shell'] as num?)?.toInt() ?? 0,
          (row['total_llaveros_tela_shell'] as num?)?.toInt() ?? 0,
          (row['total_tapasol'] as num?)?.toInt() ?? 0,
          (row['total_agendas'] as num?)?.toInt() ?? 0,
        ].fold<int>(0, (a, b) => a + b);

        final entregQualid = [
          (row['total_bolsas_qualid'] as num?)?.toInt() ?? 0,
          (row['total_esponjas_qualid'] as num?)?.toInt() ?? 0,
          (row['total_gorras_qualid'] as num?)?.toInt() ?? 0,
          (row['total_vasos_qualid'] as num?)?.toInt() ?? 0,
          (row['total_llavero_caucho_qualid'] as num?)?.toInt() ?? 0,
          (row['total_llaveros_tela_qualid'] as num?)?.toInt() ?? 0,
          (row['total_panos_qualid'] as num?)?.toInt() ?? 0,
        ].fold<int>(0, (a, b) => a + b);

        // Ventas
        final ventasShell = [
          (row['litros_shell_advance'] as num?)?.toDouble() ?? 0,
          (row['litros_shell_hx5'] as num?)?.toDouble() ?? 0,
          (row['litros_shell_hx7'] as num?)?.toDouble() ?? 0,
          (row['litros_shell_hx8'] as num?)?.toDouble() ?? 0,
          (row['litros_shell_ultra'] as num?)?.toDouble() ?? 0,
          (row['litros_shell_rimula'] as num?)?.toDouble() ?? 0,
          (row['litros_shell_spirax'] as num?)?.toDouble() ?? 0,
          (row['cartuchos_shell_gadus'] as num?)?.toDouble() ?? 0,
          (row['litros_shell_otros'] as num?)?.toDouble() ?? 0,
        ].fold<double>(0, (a, b) => a + b);

        final ventasQualid = [
          (row['litros_qualid_fluidos'] as num?)?.toDouble() ?? 0,
          (row['unidades_qualid_spray'] as num?)?.toDouble() ?? 0,
          (row['unidades_qualid_filtro_automotriz'] as num?)?.toDouble() ?? 0,
          (row['unidades_qualid_servicio_pesado'] as num?)?.toDouble() ?? 0,
          (row['unidades_qualid_cauchos'] as num?)?.toDouble() ?? 0,
        ].fold<double>(0, (a, b) => a + b);

        totalVentasShell += ventasShell;
        totalVentasQualid += ventasQualid;

        // Filtro de marca
        if (filter.marca == 'SHELL' && apoyoShell == 0 && entregShell == 0 && ventasShell == 0) continue;
        if (filter.marca == 'QUALID' && apoyoQualid == 0 && entregQualid == 0 && ventasQualid == 0) continue;

        rows.add({
          'region': regionName,
          'sucursal': row['sucursal'] ?? '',
          'tipo': row['tipo_registro'] ?? '',
          'cliente': row['nombre_establecimiento'] ?? 'Sin nombre',
          'mercaderista': row['email'] ?? '',
          'fecha': row['fecha'] ?? '',
          'marca': (row['marca_promocionada'] == null || (row['marca_promocionada'] as String).isEmpty) ? 'Shell, Qualid' : row['marca_promocionada'],
          'apoyo_shell': apoyoShell,
          'apoyo_qualid': apoyoQualid,
          'entreg_shell': entregShell,
          'entreg_qualid': entregQualid,
          'ventas_shell': ventasShell,
          'ventas_qualid': ventasQualid,
        });
      }
    } catch (_) {}
  }

  return {
    'rows': rows,
    'totalActivaciones': totalActivaciones,
    'totalVentasShell': totalVentasShell,
    'totalVentasQualid': totalVentasQualid,
  };
});

class _DetallesTradeSection extends ConsumerWidget {
  const _DetallesTradeSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(_detallesTradeProvider);

    return dataAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (data) {
        final rows = data['rows'] as List<Map<String, dynamic>>;
        final totalActivaciones = data['totalActivaciones'] as int;
        final totalVentasShell = data['totalVentasShell'] as double;
        final totalVentasQualid = data['totalVentasQualid'] as double;

        return Column(
          children: [
            // Filtros
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _SectionFilters(showPeriodo: true, showRegion: true, showSucursal: true, showMarca: true),
            ),
            // KPIs
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: _KpiCard(
                      title: 'Activaciones',
                      value: '$totalActivaciones',
                      color: ThemeConfig.primaryColor,
                      icon: Icons.campaign,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _KpiCard(
                      title: 'Ventas Shell (L)',
                      value: totalVentasShell.toStringAsFixed(0),
                      color: Colors.amber[700]!,
                      icon: Icons.local_gas_station,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _KpiCard(
                      title: 'Ventas Qualid (ud)',
                      value: totalVentasQualid.toStringAsFixed(0),
                      color: Colors.blue,
                      icon: Icons.build,
                    ),
                  ),
                ],
              ),
            ),

            // Tabla detallada
            Expanded(
              child: Card(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Text('Detalles Trade Marketing',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const Spacer(),
                          Text('${rows.length} registros',
                              style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: 1600,
                          child: SingleChildScrollView(
                            child: DataTable(
                              columnSpacing: 10,
                              dataRowMinHeight: 36,
                              dataRowMaxHeight: 52,
                              headingRowColor: WidgetStateProperty.all(ThemeConfig.primaryColor),
                              headingTextStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                              dataTextStyle: const TextStyle(fontSize: 10),
                              columns: const [
                                DataColumn(label: Text('REGIÓN')),
                                DataColumn(label: Text('SUCURSAL')),
                                DataColumn(label: Text('TIPO')),
                                DataColumn(label: Text('CLIENTE')),
                                DataColumn(label: Text('MERCADERISTA')),
                                DataColumn(label: Text('FECHA')),
                                DataColumn(label: Text('MARCA')),
                                DataColumn(label: Text('APOYO\nSHELL'), numeric: true),
                                DataColumn(label: Text('APOYO\nQUALID'), numeric: true),
                                DataColumn(label: Text('ENTREG.\nSHELL'), numeric: true),
                                DataColumn(label: Text('ENTREG.\nQUALID'), numeric: true),
                                DataColumn(label: Text('VENTAS\nSHELL'), numeric: true),
                                DataColumn(label: Text('VENTAS\nQUALID'), numeric: true),
                              ],
                              rows: rows.take(500).map((r) {
                                final fecha = DateTime.tryParse(r['fecha'] as String? ?? '');
                                final fechaStr = fecha != null
                                    ? '${fecha.day}/${fecha.month}/${fecha.year}'
                                    : '';
                                return DataRow(cells: [
                                  DataCell(Text(r['region'] as String)),
                                  DataCell(Text(r['sucursal'] as String)),
                                  DataCell(Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: (r['tipo'] as String) == 'Impulso'
                                          ? Colors.orange.withValues(alpha: 0.2)
                                          : Colors.purple.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(r['tipo'] as String,
                                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w500,
                                            color: (r['tipo'] as String) == 'Impulso' ? Colors.orange[800] : Colors.purple)),
                                  )),
                                  DataCell(SizedBox(
                                    width: 180,
                                    child: Text(r['cliente'] as String,
                                        overflow: TextOverflow.ellipsis, maxLines: 2),
                                  )),
                                  DataCell(SizedBox(
                                    width: 150,
                                    child: Text(r['mercaderista'] as String,
                                        overflow: TextOverflow.ellipsis),
                                  )),
                                  DataCell(Text(fechaStr)),
                                  DataCell(Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: (r['marca'] as String) == 'Shell'
                                          ? Colors.red.withValues(alpha: 0.1)
                                          : (r['marca'] as String) == 'Qualid'
                                              ? Colors.blue.withValues(alpha: 0.1)
                                              : Colors.grey.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(r['marca'] as String, style: const TextStyle(fontSize: 9)),
                                  )),
                                  DataCell(Text('${r['apoyo_shell']}')),
                                  DataCell(Text('${r['apoyo_qualid']}')),
                                  DataCell(Text('${r['entreg_shell']}')),
                                  DataCell(Text('${r['entreg_qualid']}')),
                                  DataCell(Text('${(r['ventas_shell'] as double).toStringAsFixed(0)}')),
                                  DataCell(Text('${(r['ventas_qualid'] as double).toStringAsFixed(0)}')),
                                ]);
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }
}

// ============================================
// SECCIÓN: RESUMEN MATERIAL
// ============================================

final _resumenMaterialProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final filter = ref.watch(executiveFilterProvider);
  final sb = SupabaseConfig.client;

  // Merchandising por mes
  final merchMonthly = <String, Map<String, int>>{}; // "2026-03" -> {"Cenefas Shell": 50, ...}
  // Trade por mes
  final tradeMonthly = <String, Map<String, int>>{};

  final sedeNames = {
    'blitz': 'Centro-Llanos',
    'grupo_victoria': 'Occidente',
    'oriente': 'Oriente',
    'grupo_disbattery': 'Centro-Capital',
  };

  // Merchandising
  final merchTables = _getTablesForFilter(filter, 'merchandising');
  for (final table in merchTables) {
    try {
      final cols = ['fecha', 'sucursal', ..._merchMaterialColumns.keys].join(',');
      var query = sb.from(table).select(cols).eq('source', 'app').not('email', 'in', _testEmails);
      if (filter.startDate != null) query = query.gte('fecha', filter.startDate!.toIso8601String());
      if (filter.endDate != null) query = query.lte('fecha', filter.endDate!.add(const Duration(days: 1)).toIso8601String());
      if (filter.ciudad != null) query = query.eq('sucursal', filter.ciudad!);
      if (filter.mercaderista != null) query = query.eq('email', filter.mercaderista!);
      final data = await query;

      for (final row in (data as List)) {
        final fecha = DateTime.tryParse(row['fecha'] ?? '');
        if (fecha == null) continue;
        final monthKey = '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}';

        for (final entry in _merchMaterialColumns.entries) {
          final meta = entry.value as Map<String, String>;
          if (filter.marca != null && meta['marca'] != filter.marca) continue;
          final val = (row[entry.key] as num?)?.toInt() ?? 0;
          if (val > 0) {
            merchMonthly.putIfAbsent(monthKey, () => {});
            final name = meta['name']!;
            merchMonthly[monthKey]![name] = (merchMonthly[monthKey]![name] ?? 0) + val;
          }
        }
      }
    } catch (_) {}
  }

  // Trade
  final tradeTables = _getTablesForFilter(filter, 'trade');
  for (final table in tradeTables) {
    try {
      final cols = ['fecha', 'sucursal', ..._tradeMaterialColumns.keys].join(',');
      var query = sb.from(table).select(cols).eq('source', 'app').not('email', 'in', _testEmails);
      if (filter.startDate != null) query = query.gte('fecha', filter.startDate!.toIso8601String());
      if (filter.endDate != null) query = query.lte('fecha', filter.endDate!.add(const Duration(days: 1)).toIso8601String());
      if (filter.ciudad != null) query = query.eq('sucursal', filter.ciudad!);
      if (filter.mercaderista != null) query = query.eq('email', filter.mercaderista!);
      final data = await query;

      for (final row in (data as List)) {
        final fecha = DateTime.tryParse(row['fecha'] ?? '');
        if (fecha == null) continue;
        final monthKey = '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}';

        for (final entry in _tradeMaterialColumns.entries) {
          final meta = entry.value as Map<String, String>;
          if (filter.marca != null && meta['marca'] != filter.marca) continue;
          final val = (row[entry.key] as num?)?.toInt() ?? 0;
          if (val > 0) {
            tradeMonthly.putIfAbsent(monthKey, () => {});
            final name = meta['name']!;
            tradeMonthly[monthKey]![name] = (tradeMonthly[monthKey]![name] ?? 0) + val;
          }
        }
      }
    } catch (_) {}
  }

  return {
    'merch': merchMonthly,
    'trade': tradeMonthly,
  };
});

class _ResumenMaterialSection extends ConsumerWidget {
  const _ResumenMaterialSection();

  static const _months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(_resumenMaterialProvider);

    return dataAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (data) {
        final merch = data['merch'] as Map<String, Map<String, int>>;
        final trade = data['trade'] as Map<String, Map<String, int>>;

        return DefaultTabController(
          length: 2,
          child: Column(
            children: [
              // Filtros
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _SectionFilters(showPeriodo: true, showRegion: true, showMarca: true, showSucursal: false),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const TabBar(
                  labelColor: Colors.black,
                  unselectedLabelColor: Colors.grey,
                  indicatorSize: TabBarIndicatorSize.tab,
                  tabs: [
                    Tab(text: 'Merchandising'),
                    Tab(text: 'Trade'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildMonthlyTable(context, merch, 'Resumen Material Merchandising'),
                    _buildMonthlyTable(context, trade, 'Resumen Material Trade'),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMonthlyTable(BuildContext context, Map<String, Map<String, int>> monthlyData, String title) {
    if (monthlyData.isEmpty) {
      return const Center(child: Text('Sin datos de la app para este período'));
    }

    final sortedMonths = monthlyData.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedMonths.length,
      itemBuilder: (context, index) {
        final monthKey = sortedMonths[index];
        final materials = monthlyData[monthKey]!;
        final parts = monthKey.split('-');
        final year = parts[0];
        final monthNum = int.parse(parts[1]);
        final monthName = _months[monthNum - 1];
        final totalMes = materials.values.fold<int>(0, (a, b) => a + b);

        final sortedMaterials = materials.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ThemeConfig.primaryColor.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_month, size: 18, color: ThemeConfig.primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      '$monthName $year',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: ThemeConfig.primaryColor,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: ThemeConfig.primaryColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Total: $totalMes',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              DataTable(
                columnSpacing: 16,
                headingRowColor: WidgetStateProperty.all(Colors.grey[50]),
                headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87),
                dataTextStyle: const TextStyle(fontSize: 11),
                columns: const [
                  DataColumn(label: Text('MATERIAL')),
                  DataColumn(label: Text('CANTIDAD'), numeric: true),
                  DataColumn(label: Text('%'), numeric: true),
                ],
                rows: sortedMaterials.map((m) {
                  final pct = totalMes > 0 ? (m.value / totalMes * 100) : 0;
                  return DataRow(cells: [
                    DataCell(Text(m.key)),
                    DataCell(Text('${m.value}')),
                    DataCell(Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 50,
                          child: LinearProgressIndicator(
                            value: pct / 100,
                            backgroundColor: Colors.grey[200],
                            color: ThemeConfig.primaryColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text('${pct.toStringAsFixed(1)}%', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                      ],
                    )),
                  ]);
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================
// MAPA DE CLIENTES
// ============================================
class _ClientsMap extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadClientCoords(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('Sin datos de ubicación'));
        }

        final clients = snapshot.data!;
        final markers = clients.map((c) {
          final lat = (c['latitude'] as num).toDouble();
          final lng = (c['longitude'] as num).toDouble();
          final name = c['cli_des'] as String? ?? '';
          return Marker(
            markerId: MarkerId(c['co_cli'] as String),
            position: LatLng(lat, lng),
            infoWindow: InfoWindow(title: name),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          );
        }).toSet();

        return GoogleMap(
          initialCameraPosition: const CameraPosition(
            target: LatLng(8.0, -66.0), // Venezuela centro
            zoom: 6,
          ),
          markers: markers,
          mapType: MapType.normal,
          zoomControlsEnabled: true,
          myLocationEnabled: false,
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _loadClientCoords() async {
    final sb = SupabaseConfig.client;
    final data = await sb
        .from('clients')
        .select('co_cli, cli_des, latitude, longitude, sede_app')
        .eq('inactivo', false)
        .not('latitude', 'is', null)
        .neq('latitude', 0)
        .limit(2000);
    return (data as List).map((e) => e as Map<String, dynamic>).toList();
  }
}

// ============================================
// KPI CARD WIDGET
// ============================================
class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.white.withValues(alpha: 0.8), size: 20),
                const SizedBox(width: 8),
                Text(title, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
