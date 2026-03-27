import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/models/pop_material.dart';
import '../../../../config/supabase_config.dart';
import '../../../../config/theme_config.dart';
import '../../../providers/pop_provider.dart';
import '../../../providers/auth_provider.dart';

class RegisterMovementScreen extends ConsumerStatefulWidget {
  const RegisterMovementScreen({super.key});

  @override
  ConsumerState<RegisterMovementScreen> createState() =>
      _RegisterMovementScreenState();
}

class _RegisterMovementScreenState
    extends ConsumerState<RegisterMovementScreen> {
  String _tipoMovimiento = 'ingreso'; // ingreso o egreso
  String? _filterMarca;
  String? _selectedSede;
  String? _selectedCiudad;
  final Map<String, int> _selectedMaterials = {}; // materialId -> cantidad
  final _observacionesController = TextEditingController();
  final _rifController = TextEditingController();
  final _searchController = TextEditingController();
  bool _isSubmitting = false;

  static const Map<String, List<String>> _ciudadesPorSede = {
    'grupo_disbattery': ['Caracas', 'Falcón', 'Lara', 'Aragua', 'Miranda', 'Portuguesa', 'Yaracuy'],
    'oceano_pacifico': ['Puerto La Cruz', 'Puerto Ordaz', 'Maturín', 'Margarita', 'El Tigre'],
    'blitz_2000': ['Valencia', 'Calabozo'],
    'grupo_victoria': ['San Cristóbal', 'Maracaibo', 'Barinas', 'Mérida', 'El Vigía', 'Santa Bárbara', 'Valera'],
  };

  static const Map<String, String> _sedeDisplayNames = {
    'grupo_disbattery': 'Centro-Capital',
    'oceano_pacifico': 'Oriente',
    'blitz_2000': 'Centro-Llanos',
    'grupo_victoria': 'Occidente',
  };

  @override
  void dispose() {
    _observacionesController.dispose();
    _rifController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final materialsAsync = ref.watch(popMaterialsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_tipoMovimiento == 'ingreso'
            ? 'Registrar Ingreso'
            : 'Registrar Egreso'),
        backgroundColor: _tipoMovimiento == 'ingreso' ? Colors.green : Colors.red,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Toggle ingreso/egreso
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey[100],
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _tipoMovimiento = 'ingreso'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: _tipoMovimiento == 'ingreso'
                            ? Colors.green
                            : Colors.transparent,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.arrow_downward,
                              color: _tipoMovimiento == 'ingreso'
                                  ? Colors.white
                                  : Colors.grey,
                              size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Ingreso',
                            style: TextStyle(
                              color: _tipoMovimiento == 'ingreso'
                                  ? Colors.white
                                  : Colors.grey[600],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _tipoMovimiento = 'egreso'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: _tipoMovimiento == 'egreso'
                            ? Colors.red
                            : Colors.transparent,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.arrow_upward,
                              color: _tipoMovimiento == 'egreso'
                                  ? Colors.white
                                  : Colors.grey,
                              size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Egreso',
                            style: TextStyle(
                              color: _tipoMovimiento == 'egreso'
                                  ? Colors.white
                                  : Colors.grey[600],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Sede y ciudad
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Builder(
              builder: (context) {
                final user = ref.watch(currentUserProvider).valueOrNull;
                final isOwner = user?.isOwner ?? false;

                // Si es supervisor, su sede se fija automáticamente
                if (!isOwner && user?.sede != null) {
                  _selectedSede ??= user!.sede!.value;
                }

                return Row(
                  children: [
                    // Sede: solo owners eligen, supervisores tienen la suya fija
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedSede,
                        decoration: const InputDecoration(
                          labelText: 'Sede',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: isOwner
                            ? _sedeDisplayNames.entries
                                .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                                .toList()
                            : [
                                if (_selectedSede != null)
                                  DropdownMenuItem(
                                    value: _selectedSede,
                                    child: Text(_sedeDisplayNames[_selectedSede] ?? _selectedSede!),
                                  ),
                              ],
                        onChanged: isOwner
                            ? (v) => setState(() {
                                  _selectedSede = v;
                                  _selectedCiudad = null;
                                })
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Ciudad
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedCiudad,
                        decoration: const InputDecoration(
                          labelText: 'Ciudad',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: (_ciudadesPorSede[_selectedSede] ?? [])
                            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedCiudad = v),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // Filtros por marca + buscador
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildChip('Todas', _filterMarca == null, () => setState(() => _filterMarca = null)),
                const SizedBox(width: 8),
                _buildChip('Shell', _filterMarca == 'SHELL', () => setState(() => _filterMarca = 'SHELL'), color: Colors.red),
                const SizedBox(width: 8),
                _buildChip('Qualid', _filterMarca == 'QUALID', () => setState(() => _filterMarca = 'QUALID'), color: Colors.blue),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar...',
                      isDense: true,
                      prefixIcon: const Icon(Icons.search, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Lista de materiales con cantidad
          Expanded(
            child: materialsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (materials) {
                var filtered = _filterMarca == null
                    ? materials
                    : materials.where((m) => m.marca == _filterMarca).toList();
                final search = _searchController.text.trim().toLowerCase();
                if (search.isNotEmpty) {
                  filtered = filtered.where((m) => m.nombre.toLowerCase().contains(search)).toList();
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final mat = filtered[index];
                    final qty = _selectedMaterials[mat.id] ?? 0;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            // Icono marca
                            Icon(
                              mat.marca == 'SHELL' ? Icons.local_gas_station : Icons.build,
                              color: mat.marca == 'SHELL' ? Colors.red[300] : Colors.blue[300],
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            // Nombre
                            Expanded(
                              child: Text(
                                mat.nombre,
                                style: const TextStyle(fontSize: 12),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Controles de cantidad
                            if (qty > 0)
                              IconButton(
                                onPressed: () => setState(() {
                                  if (qty <= 1) {
                                    _selectedMaterials.remove(mat.id);
                                  } else {
                                    _selectedMaterials[mat.id] = qty - 1;
                                  }
                                }),
                                icon: const Icon(Icons.remove_circle_outline, size: 20),
                                color: Colors.red,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              ),
                            if (qty > 0)
                              GestureDetector(
                                onTap: () => _editQuantity(mat, qty),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _tipoMovimiento == 'ingreso'
                                        ? Colors.green.withValues(alpha: 0.1)
                                        : Colors.red.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '$qty',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _tipoMovimiento == 'ingreso' ? Colors.green : Colors.red,
                                    ),
                                  ),
                                ),
                              ),
                            IconButton(
                              onPressed: () => setState(() {
                                _selectedMaterials[mat.id] = qty + 1;
                              }),
                              icon: const Icon(Icons.add_circle_outline, size: 20),
                              color: Colors.green,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Observaciones y botón
          if (_selectedMaterials.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_selectedMaterials.length} material(es) seleccionado(s)',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  // Ciudad
                  DropdownButtonFormField<String>(
                    value: _selectedCiudad,
                    decoration: InputDecoration(
                      labelText: 'Ciudad *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: (_ciudadesPorSede[_selectedSede] ?? [])
                        .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13))))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedCiudad = v),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _observacionesController,
                    decoration: InputDecoration(
                      hintText: 'Observaciones (opcional)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      isDense: true,
                      contentPadding: const EdgeInsets.all(12),
                    ),
                    maxLines: 1,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _tipoMovimiento == 'ingreso' ? Colors.green : Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(_tipoMovimiento == 'ingreso'
                              ? Icons.arrow_downward
                              : Icons.arrow_upward),
                      label: Text(
                        _isSubmitting
                            ? 'Registrando...'
                            : 'Registrar ${_tipoMovimiento == 'ingreso' ? 'Ingreso' : 'Egreso'}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _editQuantity(PopMaterial mat, int currentQty) {
    final controller = TextEditingController(text: currentQty.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(mat.nombre, style: const TextStyle(fontSize: 14)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Cantidad'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = int.tryParse(controller.text) ?? 0;
              setState(() {
                if (val <= 0) {
                  _selectedMaterials.remove(mat.id);
                } else {
                  _selectedMaterials[mat.id] = val;
                }
              });
              Navigator.pop(ctx);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  Future<void> _submit() async {
    if (_selectedMaterials.isEmpty) return;
    if (_selectedSede == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una sede'), backgroundColor: Colors.orange),
      );
      return;
    }
    if (_selectedCiudad == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una ciudad'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final userId = SupabaseConfig.currentUser?.id;

      final movements = _selectedMaterials.entries.map((entry) => {
            'material_id': entry.key,
            'sede_app': _selectedSede,
            'tipo': _tipoMovimiento,
            'cantidad': entry.value,
            'observaciones': _observacionesController.text.trim().isEmpty
                ? null
                : _observacionesController.text.trim(),
            'registrado_por': userId,
            'ciudad': _selectedCiudad,
          }).toList();

      await SupabaseConfig.client.from('pop_movements').insert(movements);

      ref.invalidate(popStockProvider);
      ref.invalidate(popMovementsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_tipoMovimiento == 'ingreso' ? 'Ingreso' : 'Egreso'} registrado correctamente (${_selectedMaterials.length} materiales)',
            ),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildChip(String label, bool selected, VoidCallback onTap, {Color? color}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? (color ?? ThemeConfig.primaryColor).withValues(alpha: 0.15)
              : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? (color ?? ThemeConfig.primaryColor) : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? (color ?? ThemeConfig.primaryColor) : Colors.grey[600],
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
