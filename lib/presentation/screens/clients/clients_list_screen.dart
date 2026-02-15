import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/enums/sede.dart';
import '../../../core/models/client.dart';
import '../../../data/repositories/client_repository.dart';
import '../../providers/auth_provider.dart';
import '../../providers/client_provider.dart';

/// Pantalla de lista de clientes
class ClientsListScreen extends ConsumerStatefulWidget {
  const ClientsListScreen({super.key});

  @override
  ConsumerState<ClientsListScreen> createState() => _ClientsListScreenState();
}

class _ClientsListScreenState extends ConsumerState<ClientsListScreen> {
  final _searchController = TextEditingController();
  bool _showFilters = false;
  String? _initError;

  @override
  void initState() {
    super.initState();
    debugPrint('ClientsListScreen: initState called');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('ClientsListScreen: build called');
    
    // Verificar primero si hay usuario autenticado
    final currentUserAsync = ref.watch(currentUserProvider);
    
    return currentUserAsync.when(
      data: (user) {
        if (user == null) {
          debugPrint('ClientsListScreen: user is null');
          return Scaffold(
            appBar: AppBar(title: const Text('Clientes')),
            body: const Center(
              child: Text('Debes iniciar sesión para ver los clientes'),
            ),
          );
        }
        debugPrint('ClientsListScreen: user loaded - ${user.email}');
        return _buildMainContent(context);
      },
      loading: () {
        debugPrint('ClientsListScreen: loading user...');
        return Scaffold(
          appBar: AppBar(title: const Text('Clientes')),
          body: const Center(child: CircularProgressIndicator()),
        );
      },
      error: (error, stack) {
        debugPrint('ClientsListScreen: error loading user - $error');
        return Scaffold(
          appBar: AppBar(title: const Text('Clientes')),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: $error'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(currentUserProvider),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildMainContent(BuildContext context) {
    final clientsAsync = ref.watch(searchedClientsProvider);
    final statsAsync = ref.watch(clientStatsProvider);
    final filters = ref.watch(clientFiltersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clientes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.map),
            tooltip: 'Ver en Mapa',
            onPressed: () => context.push('/admin/clients/map'),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle),
            tooltip: 'Nuevo Cliente',
            onPressed: () => _showCreateClientDialog(context),
          ),
          IconButton(
            icon: Icon(_showFilters ? Icons.filter_list_off : Icons.filter_list),
            onPressed: () => setState(() => _showFilters = !_showFilters),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(clientsProvider);
              ref.invalidate(clientStatsProvider);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Estadísticas rápidas
          statsAsync.when(
            data: (stats) => _buildStatsRow(stats),
            loading: () => const SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // Barra de búsqueda
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, RIF, ciudad o dirección...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(clientSearchQueryProvider.notifier).state = '';
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
              onChanged: (value) {
                ref.read(clientSearchQueryProvider.notifier).state = value;
              },
            ),
          ),

          // Filtros expandibles
          if (_showFilters) _buildFiltersSection(context, ref, filters),

          // Chips de filtros activos
          if (filters.hasFilters)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: _buildActiveFilterChips(context, ref, filters),
              ),
            ),

          // Lista de clientes
          Expanded(
            child: clientsAsync.when(
              data: (clients) => clients.isEmpty
                  ? _buildEmptyState(context)
                  : _buildClientsList(context, clients),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _buildErrorState(context, error),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateClientDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Cliente'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildStatsRow(Map<String, dynamic> stats) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _StatChip(
            label: 'Total',
            value: stats['total'].toString(),
            color: Colors.blue,
          ),
          _StatChip(
            label: 'Activos',
            value: stats['activos'].toString(),
            color: Colors.green,
          ),
          _StatChip(
            label: 'Sin visitar',
            value: stats['sin_visitar'].toString(),
            color: Colors.orange,
          ),
          _StatChip(
            label: 'Últ. 7 días',
            value: stats['visitados_7_dias'].toString(),
            color: Colors.purple,
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersSection(BuildContext context, WidgetRef ref, ClientFilters filters) {
    final currentUser = ref.watch(currentUserProvider);
    final canViewAllSedes = currentUser.valueOrNull?.role.canViewAllSedes ?? false;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filtro por sede (solo para Owner)
          if (canViewAllSedes) ...[
            const Text('Sede:', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('Todas'),
                  selected: filters.sedeApp == null,
                  onSelected: (_) {
                    ref.read(clientFiltersProvider.notifier).state =
                        filters.copyWith(sedeApp: null);
                  },
                ),
                ...Sede.values.map((sede) => FilterChip(
                      label: Text(sede.displayName),
                      selected: filters.sedeApp == sede.value,
                      onSelected: (_) {
                        ref.read(clientFiltersProvider.notifier).state =
                            filters.copyWith(sedeApp: sede.value);
                      },
                    )),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Filtro por estado
          const Text('Estado:', style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              FilterChip(
                label: const Text('Todos'),
                selected: filters.activo == null,
                onSelected: (_) {
                  ref.read(clientFiltersProvider.notifier).state =
                      ClientFilters(
                        sedeApp: filters.sedeApp,
                        ciudad: filters.ciudad,
                        sinVisitaReciente: filters.sinVisitaReciente,
                        diasSinVisita: filters.diasSinVisita,
                      );
                },
              ),
              FilterChip(
                label: const Text('Activos'),
                selected: filters.activo == true,
                onSelected: (_) {
                  ref.read(clientFiltersProvider.notifier).state =
                      filters.copyWith(activo: true);
                },
              ),
              FilterChip(
                label: const Text('Inactivos'),
                selected: filters.activo == false,
                onSelected: (_) {
                  ref.read(clientFiltersProvider.notifier).state =
                      filters.copyWith(activo: false);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Filtro por última visita
          const Text('Última visita:', style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              FilterChip(
                label: const Text('Todos'),
                selected: filters.sinVisitaReciente != true,
                onSelected: (_) {
                  ref.read(clientFiltersProvider.notifier).state =
                      ClientFilters(
                        sedeApp: filters.sedeApp,
                        ciudad: filters.ciudad,
                        activo: filters.activo,
                      );
                },
              ),
              FilterChip(
                label: const Text('Sin visita (+7 días)'),
                selected: filters.sinVisitaReciente == true && filters.diasSinVisita == 7,
                onSelected: (_) {
                  ref.read(clientFiltersProvider.notifier).state =
                      filters.copyWith(sinVisitaReciente: true, diasSinVisita: 7);
                },
              ),
              FilterChip(
                label: const Text('Sin visita (+30 días)'),
                selected: filters.sinVisitaReciente == true && filters.diasSinVisita == 30,
                onSelected: (_) {
                  ref.read(clientFiltersProvider.notifier).state =
                      filters.copyWith(sinVisitaReciente: true, diasSinVisita: 30);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildActiveFilterChips(BuildContext context, WidgetRef ref, ClientFilters filters) {
    final chips = <Widget>[];

    if (filters.sedeApp != null) {
      final sede = Sede.tryFromString(filters.sedeApp);
      chips.add(Chip(
        label: Text('Sede: ${sede?.displayName ?? filters.sedeApp}'),
        onDeleted: () {
          ref.read(clientFiltersProvider.notifier).state =
              ClientFilters(
                ciudad: filters.ciudad,
                activo: filters.activo,
                sinVisitaReciente: filters.sinVisitaReciente,
                diasSinVisita: filters.diasSinVisita,
              );
        },
      ));
    }

    if (filters.activo != null) {
      chips.add(Chip(
        label: Text(filters.activo! ? 'Activos' : 'Inactivos'),
        onDeleted: () {
          ref.read(clientFiltersProvider.notifier).state =
              ClientFilters(
                sedeApp: filters.sedeApp,
                ciudad: filters.ciudad,
                sinVisitaReciente: filters.sinVisitaReciente,
                diasSinVisita: filters.diasSinVisita,
              );
        },
      ));
    }

    if (filters.sinVisitaReciente == true) {
      chips.add(Chip(
        label: Text('Sin visita (+${filters.diasSinVisita} días)'),
        onDeleted: () {
          ref.read(clientFiltersProvider.notifier).state =
              ClientFilters(
                sedeApp: filters.sedeApp,
                ciudad: filters.ciudad,
                activo: filters.activo,
              );
        },
      ));
    }

    if (chips.isNotEmpty) {
      chips.add(
        TextButton(
          onPressed: () {
            ref.read(clientFiltersProvider.notifier).state = const ClientFilters();
          },
          child: const Text('Limpiar filtros'),
        ),
      );
    }

    return chips;
  }

  Widget _buildClientsList(BuildContext context, List<Client> clients) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 90),
      itemCount: clients.length,
      itemBuilder: (context, index) {
        final client = clients[index];
        return _ClientCard(
          client: client,
          onTap: () => context.push('/admin/clients/${client.coCli}'),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 80,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No hay clientes',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text('No se encontraron clientes con los filtros aplicados'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              ref.read(clientFiltersProvider.notifier).state = const ClientFilters();
              ref.read(clientSearchQueryProvider.notifier).state = '';
              _searchController.clear();
            },
            icon: const Icon(Icons.clear_all),
            label: const Text('Limpiar filtros'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 80,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Error al cargar clientes',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              ref.invalidate(clientsProvider);
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Color _getVisitColorForState(int? dias) {
    if (dias == null) return Colors.grey;
    if (dias <= 7) return Colors.green;
    if (dias <= 14) return Colors.orange;
    return Colors.red;
  }

  /// Muestra el diálogo para crear un nuevo cliente
  Future<void> _showCreateClientDialog(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final coCliController = TextEditingController();
    final nombreController = TextEditingController();
    final ciudadController = TextEditingController();
    final direccionController = TextEditingController();
    final telefonoController = TextEditingController();
    final rifController = TextEditingController();
    final emailController = TextEditingController();
    final responsableController = TextEditingController();
    
    // Generar código único automáticamente
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    coCliController.text = 'CLI$timestamp';

    final currentUser = ref.read(currentUserProvider).valueOrNull;
    final sedeApp = currentUser?.sede?.value ?? 'blitz_2000';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nuevo Cliente'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nombreController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del Cliente *',
                    prefixIcon: Icon(Icons.business),
                  ),
                  validator: (v) => v?.isEmpty == true ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: ciudadController,
                  decoration: const InputDecoration(
                    labelText: 'Ciudad',
                    prefixIcon: Icon(Icons.location_city),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: direccionController,
                  decoration: const InputDecoration(
                    labelText: 'Dirección',
                    prefixIcon: Icon(Icons.place),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: telefonoController,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono',
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: rifController,
                  decoration: const InputDecoration(
                    labelText: 'RIF',
                    prefixIcon: Icon(Icons.badge),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: responsableController,
                  decoration: const InputDecoration(
                    labelText: 'Responsable/Contacto',
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState?.validate() == true) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      try {
        final repository = ref.read(clientRepositoryProvider);
        await repository.createClient(
          coCli: coCliController.text,
          cliDes: nombreController.text,
          sedeApp: sedeApp,
          ciudad: ciudadController.text.isNotEmpty ? ciudadController.text : null,
          direc1: direccionController.text.isNotEmpty ? direccionController.text : null,
          telefonos: telefonoController.text.isNotEmpty ? telefonoController.text : null,
          rif: rifController.text.isNotEmpty ? rifController.text : null,
          email: emailController.text.isNotEmpty ? emailController.text : null,
          respons: responsableController.text.isNotEmpty ? responsableController.text : null,
        );
        
        // Refrescar lista de clientes
        ref.invalidate(clientsProvider);
        ref.invalidate(clientStatsProvider);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cliente creado exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al crear cliente: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

/// Widget de estadística
class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta de cliente
class _ClientCard extends StatelessWidget {
  final Client client;
  final VoidCallback onTap;

  const _ClientCard({
    required this.client,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Indicador de estado
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: client.isActive ? Colors.green : Colors.red,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Código del cliente
                  Text(
                    client.coCli.trim(),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  const Spacer(),
                  // Días desde última visita
                  if (client.lastVisitAt != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getVisitColor(client.diasDesdeUltimaVisita).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Hace ${client.diasDesdeUltimaVisita} días',
                        style: TextStyle(
                          fontSize: 11,
                          color: _getVisitColor(client.diasDesdeUltimaVisita),
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Sin visitar',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              // Nombre del cliente
              Text(
                client.cliDes,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              // Ciudad y dirección
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 14,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      client.ciudad ?? 'Sin ciudad',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (client.direc1 != null) ...[
                const SizedBox(height: 2),
                Text(
                  client.direccionPrincipal,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              // Días de visita programados
              if (client.diasVisita.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  children: client.diasVisita.map((dia) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        dia.substring(0, 3),
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getVisitColor(int? dias) {
    if (dias == null) return Colors.grey;
    if (dias <= 7) return Colors.green;
    if (dias <= 14) return Colors.orange;
    return Colors.red;
  }
}
