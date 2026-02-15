import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/route.dart';
import '../../../core/models/route_type.dart';
import '../../../core/models/route_template.dart';
import '../../../core/models/client.dart';
import '../../../core/models/user.dart';
import '../../../core/enums/route_status.dart';
import '../../../config/theme_config.dart';
import '../../providers/auth_provider.dart';
import '../../providers/route_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/client_provider.dart';

/// Pantalla para crear o editar una ruta
class CreateEditRouteScreen extends ConsumerStatefulWidget {
  final String? routeId; // Si es null, es creación

  const CreateEditRouteScreen({super.key, this.routeId});

  @override
  ConsumerState<CreateEditRouteScreen> createState() => _CreateEditRouteScreenState();
}

class _CreateEditRouteScreenState extends ConsumerState<CreateEditRouteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  
  DateTime _selectedDate = DateTime.now();
  String? _selectedMercaderistaId;
  String? _selectedRouteTypeId;
  String? _selectedTemplateId;
  List<String> _selectedClientIds = [];
  bool _isLoading = false;
  bool _useTemplate = false;

  @override
  void initState() {
    super.initState();
    if (widget.routeId != null) {
      _loadRouteData();
    }
  }

  Future<void> _loadRouteData() async {
    final route = await ref.read(routeByIdProvider(widget.routeId!).future);
    if (route != null) {
      setState(() {
        _nameController.text = route.name;
        _notesController.text = route.notes ?? '';
        _selectedDate = route.scheduledDate;
        _selectedMercaderistaId = route.mercaderistaId;
        _selectedRouteTypeId = route.routeTypeId;
        _selectedClientIds = route.clients?.map((c) => c.clientId).toList() ?? [];
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final routeTypesAsync = ref.watch(routeTypesProvider);
    final templatesAsync = ref.watch(templatesProvider);
    final mercaderistasAsync = ref.watch(activeMercaderistasProvider);
    // final clientsAsync = ref.watch(clientsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.routeId == null ? 'Nueva Ruta' : 'Editar Ruta'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Toggle: Crear desde plantilla o manual
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Método de creación',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _SelectableCard(
                            title: 'Manual',
                            subtitle: 'Seleccionar clientes',
                            icon: Icons.edit,
                            isSelected: !_useTemplate,
                            onTap: () => setState(() => _useTemplate = false),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SelectableCard(
                            title: 'Plantilla',
                            subtitle: 'Usar ruta existente',
                            icon: Icons.copy,
                            isSelected: _useTemplate,
                            onTap: () => setState(() => _useTemplate = true),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Si usa plantilla, mostrar selector de plantilla
            if (_useTemplate) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Seleccionar Plantilla',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      templatesAsync.when(
                        data: (templates) => DropdownButtonFormField<String>(
                          value: _selectedTemplateId,
                          decoration: const InputDecoration(
                            labelText: 'Plantilla',
                            prefixIcon: Icon(Icons.copy),
                          ),
                          items: templates.map((t) => DropdownMenuItem(
                            value: t.id,
                            child: Text('${t.name} (${t.clients?.length ?? 0} clientes)'),
                          )).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedTemplateId = value;
                              // Auto-fill name from template
                              final template = templates.firstWhere((t) => t.id == value);
                              _nameController.text = template.name;
                            });
                          },
                          validator: _useTemplate 
                            ? (value) => value == null ? 'Seleccione una plantilla' : null
                            : null,
                        ),
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Text('Error cargando plantillas: $e'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Información básica
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Información de la Ruta',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Nombre de la ruta
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de la ruta *',
                        prefixIcon: Icon(Icons.route),
                        hintText: 'Ej: Ruta Norte - Lunes',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'El nombre es requerido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Fecha programada
                    InkWell(
                      onTap: () => _selectDate(context),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Fecha programada *',
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Tipo de ruta
                    routeTypesAsync.when(
                      data: (types) => DropdownButtonFormField<String>(
                        value: _selectedRouteTypeId,
                        decoration: const InputDecoration(
                          labelText: 'Tipo de Ruta',
                          prefixIcon: Icon(Icons.category),
                        ),
                        items: types.map((t) => DropdownMenuItem(
                          value: t.id,
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: _hexToColor(t.color),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(t.name),
                            ],
                          ),
                        )).toList(),
                        onChanged: (value) => setState(() => _selectedRouteTypeId = value),
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text('Error: $e'),
                    ),
                    const SizedBox(height: 16),

                    // Mercaderista asignado
                    mercaderistasAsync.when(
                      data: (mercaderistas) => DropdownButtonFormField<String>(
                        value: _selectedMercaderistaId,
                        decoration: const InputDecoration(
                          labelText: 'Mercaderista *',
                          prefixIcon: Icon(Icons.person),
                        ),
                        items: mercaderistas.map((m) => DropdownMenuItem(
                          value: m.id,
                          child: Text(m.fullName),
                        )).toList(),
                        onChanged: (value) => setState(() => _selectedMercaderistaId = value),
                        validator: (value) => value == null ? 'Seleccione un mercaderista' : null,
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text('Error: $e'),
                    ),
                    const SizedBox(height: 16),

                    // Notas
                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notas',
                        prefixIcon: Icon(Icons.notes),
                        hintText: 'Instrucciones adicionales...',
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Selección de clientes (solo si no usa plantilla)
            if (!_useTemplate)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Clientes de la Ruta',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => _selectClients(context),
                            icon: const Icon(Icons.add),
                            label: const Text('Agregar'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_selectedClientIds.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.store, size: 48, color: Colors.grey[400]),
                                const SizedBox(height: 8),
                                Text(
                                  'No hay clientes seleccionados',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: () => _selectClients(context),
                                  child: const Text('Seleccionar clientes'),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ReorderableListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _selectedClientIds.length,
                          onReorder: (oldIndex, newIndex) {
                            setState(() {
                              if (newIndex > oldIndex) newIndex--;
                              final item = _selectedClientIds.removeAt(oldIndex);
                              _selectedClientIds.insert(newIndex, item);
                            });
                          },
                          itemBuilder: (context, index) {
                            final clientId = _selectedClientIds[index];
                            return _ClientListItem(
                              key: ValueKey(clientId),
                              clientId: clientId,
                              orderNumber: index + 1,
                              onRemove: () {
                                setState(() {
                                  _selectedClientIds.remove(clientId);
                                });
                              },
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 80), // Space for FAB
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _saveRoute,
        icon: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.save),
        label: Text(_isLoading ? 'Guardando...' : 'Guardar Ruta'),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectClients(BuildContext context) async {
    final clients = await ref.read(clientsProvider.future);
    
    if (!mounted) return;

    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ClientSelectorSheet(
        availableClients: clients,
        selectedClientIds: _selectedClientIds,
      ),
    );

    if (result != null) {
      setState(() => _selectedClientIds = result);
    }
  }

  Future<void> _saveRoute() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_useTemplate && _selectedClientIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debe seleccionar al menos un cliente')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final currentUser = await ref.read(currentUserProvider.future);
      if (currentUser == null) throw Exception('Usuario no autenticado');

      final repository = ref.read(routeRepositoryProvider);
      
      AppRoute? createdRoute;

      if (_useTemplate && _selectedTemplateId != null) {
        // Crear desde plantilla
        createdRoute = await repository.createRouteFromTemplate(
          templateId: _selectedTemplateId!,
          mercaderistaId: _selectedMercaderistaId!,
          scheduledDate: _selectedDate,
          routeTypeId: _selectedRouteTypeId,
          sedeApp: currentUser.sede?.value ?? 'grupo_disbattery',
          createdBy: currentUser.id,
        );
      } else {
        // Crear manualmente
        final route = AppRoute(
          id: '',
          mercaderistaId: _selectedMercaderistaId!,
          name: _nameController.text.trim(),
          scheduledDate: _selectedDate,
          status: RouteStatus.planned,
          totalClients: _selectedClientIds.length,
          createdAt: DateTime.now(),
          sedeApp: currentUser.sede?.value ?? 'grupo_disbattery',
          routeTypeId: _selectedRouteTypeId,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          createdBy: currentUser.id,
        );

        createdRoute = await repository.createRoute(route);

        // Agregar clientes
        if (_selectedClientIds.isNotEmpty) {
          await repository.addClientsToRoute(
            routeId: createdRoute.id,
            clientIds: _selectedClientIds,
          );
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ruta creada exitosamente'),
          backgroundColor: Colors.green,
        ),
      );

      // Invalidar providers para refrescar
      ref.invalidate(routesForWeekProvider);
      ref.invalidate(routesProvider);

      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Color _hexToColor(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 6 || hex.length == 7) buffer.write('ff');
    buffer.write(hex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}

class _SelectableCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _SelectableCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? ThemeConfig.primaryColor : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected ? ThemeConfig.primaryColor.withValues(alpha: 0.1) : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? ThemeConfig.primaryColor : Colors.grey,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? ThemeConfig.primaryColor : Colors.black87,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClientListItem extends ConsumerWidget {
  final String clientId;
  final int orderNumber;
  final VoidCallback onRemove;

  const _ClientListItem({
    super.key,
    required this.clientId,
    required this.orderNumber,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientAsync = ref.watch(clientByIdProvider(clientId));

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: ThemeConfig.primaryColor.withValues(alpha: 0.1),
          child: Text(
            '$orderNumber',
            style: const TextStyle(
              color: ThemeConfig.primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: clientAsync.when(
          data: (client) => Text(client?.cliDes ?? 'Cliente no encontrado'),
          loading: () => const Text('Cargando...'),
          error: (e, _) => Text('Error: $e'),
        ),
        subtitle: clientAsync.when(
          data: (client) => Text(client?.direc1 ?? ''),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.drag_handle, color: Colors.grey),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}

class _ClientSelectorSheet extends ConsumerStatefulWidget {
  final List<Client> availableClients;
  final List<String> selectedClientIds;

  const _ClientSelectorSheet({
    required this.availableClients,
    required this.selectedClientIds,
  });

  @override
  ConsumerState<_ClientSelectorSheet> createState() => _ClientSelectorSheetState();
}

class _ClientSelectorSheetState extends ConsumerState<_ClientSelectorSheet> {
  late List<String> _selected;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _visitFilter = 'todos'; // todos, esta_semana, este_mes, sin_visita_90, nunca

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.selectedClientIds);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesVisitFilter(Client c) {
    switch (_visitFilter) {
      case 'esta_semana':
        return c.lastVisitAt == null || c.diasDesdeUltimaVisita! > 7;
      case 'este_mes':
        return c.lastVisitAt == null || c.diasDesdeUltimaVisita! > 30;
      case 'sin_visita_90':
        return c.lastVisitAt == null || c.diasDesdeUltimaVisita! > 90;
      case 'nunca':
        return c.lastVisitAt == null;
      default:
        return true;
    }
  }

  String _formatLastVisit(Client c) {
    if (c.lastVisitAt == null) return 'Nunca visitado';
    final dias = c.diasDesdeUltimaVisita!;
    if (dias == 0) return 'Hoy';
    if (dias == 1) return 'Ayer';
    return 'Hace $dias días';
  }

  Color _getVisitColor(Client c) {
    if (c.lastVisitAt == null) return Colors.grey;
    final dias = c.diasDesdeUltimaVisita!;
    if (dias <= 7) return Colors.green;
    if (dias <= 30) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final filteredClients = widget.availableClients.where((c) {
      // Filtro de búsqueda
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesSearch = c.cliDes.toLowerCase().contains(query) ||
            (c.direc1?.toLowerCase().contains(query) ?? false) ||
            c.coCli.toLowerCase().contains(query) ||
            (c.rif?.toLowerCase().contains(query) ?? false) ||
            (c.ciudad?.toLowerCase().contains(query) ?? false);
        if (!matchesSearch) return false;
      }
      // Filtro de última visita
      return _matchesVisitFilter(c);
    }).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Seleccionar Clientes',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, _selected),
                          child: Text('Listo (${_selected.length})'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Buscar por nombre, RIF, ciudad...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                      ),
                      onChanged: (value) => setState(() => _searchQuery = value),
                    ),
                    const SizedBox(height: 10),
                    // Filtros de última visita
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('todos', 'Todos'),
                          const SizedBox(width: 6),
                          _buildFilterChip('esta_semana', 'Sin visita +7d'),
                          const SizedBox(width: 6),
                          _buildFilterChip('este_mes', 'Sin visita +30d'),
                          const SizedBox(width: 6),
                          _buildFilterChip('sin_visita_90', 'Sin visita +90d'),
                          const SizedBox(width: 6),
                          _buildFilterChip('nunca', 'Nunca visitado'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Conteo de resultados
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                color: Colors.grey[50],
                child: Row(
                  children: [
                    Text(
                      '${filteredClients.length} clientes',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const Spacer(),
                    Text(
                      '${_selected.length} seleccionados',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Theme.of(context).primaryColor),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: filteredClients.length,
                  itemBuilder: (context, index) {
                    final client = filteredClients[index];
                    final isSelected = _selected.contains(client.coCli);

                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selected.add(client.coCli);
                          } else {
                            _selected.remove(client.coCli);
                          }
                        });
                      },
                      secondary: CircleAvatar(
                        backgroundColor: isSelected
                            ? ThemeConfig.primaryColor
                            : Colors.grey[200],
                        child: Icon(
                          Icons.store,
                          color: isSelected ? Colors.white : Colors.grey,
                        ),
                      ),
                      title: Text(client.cliDes, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Row(
                        children: [
                          Expanded(
                            child: Text(
                              client.direc1 ?? client.ciudad ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: _getVisitColor(client).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _formatLastVisit(client),
                              style: TextStyle(
                                fontSize: 10,
                                color: _getVisitColor(client),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      activeColor: ThemeConfig.primaryColor,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isActive = _visitFilter == value;
    return FilterChip(
      label: Text(label, style: TextStyle(fontSize: 11, color: isActive ? Colors.white : null)),
      selected: isActive,
      onSelected: (_) => setState(() => _visitFilter = value),
      selectedColor: Theme.of(context).primaryColor,
      checkmarkColor: Colors.white,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}
