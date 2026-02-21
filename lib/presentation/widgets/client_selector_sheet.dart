import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/client.dart';
import '../../config/theme_config.dart';

/// Bottom sheet reutilizable para seleccionar clientes
/// Usado en creación de rutas y para agregar clientes a rutas existentes
class ClientSelectorSheet extends ConsumerStatefulWidget {
  final List<Client> availableClients;
  final List<String> selectedClientIds;

  const ClientSelectorSheet({
    super.key,
    required this.availableClients,
    required this.selectedClientIds,
  });

  @override
  ConsumerState<ClientSelectorSheet> createState() => _ClientSelectorSheetState();
}

class _ClientSelectorSheetState extends ConsumerState<ClientSelectorSheet> {
  late List<String> _selected;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _visitFilter = 'todos';

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
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesSearch = c.cliDes.toLowerCase().contains(query) ||
            (c.direc1?.toLowerCase().contains(query) ?? false) ||
            c.coCli.toLowerCase().contains(query) ||
            (c.rif?.toLowerCase().contains(query) ?? false) ||
            (c.ciudad?.toLowerCase().contains(query) ?? false);
        if (!matchesSearch) return false;
      }
      return _matchesVisitFilter(c);
    }).toList()
      ..sort((a, b) {
        final baseCompare = a.coCliBase.compareTo(b.coCliBase);
        if (baseCompare != 0) return baseCompare;
        if (!a.isSucursal && b.isSucursal) return -1;
        if (a.isSucursal && !b.isSucursal) return 1;
        return a.coCli.compareTo(b.coCli);
      });

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
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(client.cliDes, maxLines: 1, overflow: TextOverflow.ellipsis),
                          if (client.isSucursal)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  border: Border.all(color: Colors.blue.shade200),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Sucursal',
                                  style: TextStyle(fontSize: 10, color: Colors.blue.shade700),
                                ),
                              ),
                            ),
                        ],
                      ),
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
