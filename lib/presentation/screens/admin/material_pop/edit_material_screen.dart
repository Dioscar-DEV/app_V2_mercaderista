import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/models/pop_material.dart';
import '../../../../config/supabase_config.dart';
import '../../../../config/theme_config.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/pop_provider.dart';

class EditMaterialScreen extends ConsumerStatefulWidget {
  final PopMaterial? material; // null = crear nuevo

  const EditMaterialScreen({super.key, this.material});

  @override
  ConsumerState<EditMaterialScreen> createState() => _EditMaterialScreenState();
}

class _EditMaterialScreenState extends ConsumerState<EditMaterialScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nombreController;
  late TextEditingController _linkedQuestionController;
  late TextEditingController _linkedOptionController;
  late TextEditingController _costoController;
  late String _marca;
  late String _tipoMaterial;
  late String _categoria;
  late String _unidadMedida;
  bool _isSubmitting = false;
  bool _isLinked = false;
  bool _isOwner = false;

  static const _questionOptions = [
    'Entregables Shell',
    'Entregables Qualid',
    'Recursos Utilizados (Shell)',
    'Recursos Utilizados (Qualid)',
    'Afiches Shell',
    'Afiches Qualid',
    'Cenefas Shell',
    'Cenefas Qualid',
    'Bolsas Shell',
    'Bolsas Qualid',
    'Stickers',
    'Ambientadores',
    'Papel Bobina',
    'Exhibidores',
  ];

  bool get _isEditing => widget.material != null;

  @override
  void initState() {
    super.initState();
    final mat = widget.material;
    _nombreController = TextEditingController(text: mat?.nombre ?? '');
    _linkedQuestionController = TextEditingController(text: mat?.linkedQuestionPattern ?? '');
    _linkedOptionController = TextEditingController(text: mat?.linkedOptionPattern ?? '');
    _costoController = TextEditingController(text: mat != null && mat.costoUnitario > 0 ? mat.costoUnitario.toString() : '');
    _marca = mat?.marca ?? 'SHELL';
    _tipoMaterial = mat?.tipoMaterial ?? 'TRADE';
    _categoria = mat?.categoria ?? 'ENTREGABLE';
    _unidadMedida = mat?.unidadMedida ?? 'unidad';
    _isLinked = mat?.isLinked ?? false;
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _linkedQuestionController.dispose();
    _linkedOptionController.dispose();
    _costoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    _isOwner = userAsync.valueOrNull?.isOwner ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Material' : 'Nuevo Material'),
        backgroundColor: ThemeConfig.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Nombre
            TextFormField(
              controller: _nombreController,
              decoration: const InputDecoration(
                labelText: 'Nombre del material',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.inventory_2),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: 16),

            // Marca
            DropdownButtonFormField<String>(
              value: _marca,
              decoration: const InputDecoration(
                labelText: 'Marca',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.branding_watermark),
              ),
              items: const [
                DropdownMenuItem(value: 'SHELL', child: Text('Shell')),
                DropdownMenuItem(value: 'QUALID', child: Text('Qualid')),
              ],
              onChanged: (v) => setState(() => _marca = v!),
            ),
            const SizedBox(height: 16),

            // Tipo de material
            DropdownButtonFormField<String>(
              value: _tipoMaterial,
              decoration: const InputDecoration(
                labelText: 'Tipo de material',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
              ),
              items: const [
                DropdownMenuItem(value: 'TRADE', child: Text('Trade')),
                DropdownMenuItem(value: 'MERCHANDISING', child: Text('Merchandising')),
              ],
              onChanged: (v) => setState(() => _tipoMaterial = v!),
            ),
            const SizedBox(height: 16),

            // Categoría
            DropdownButtonFormField<String>(
              value: _categoria,
              decoration: const InputDecoration(
                labelText: 'Categoría',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.label),
              ),
              items: const [
                DropdownMenuItem(value: 'ENTREGABLE', child: Text('Entregable')),
                DropdownMenuItem(value: 'MATERIAL DE APOYO', child: Text('Material de apoyo')),
                DropdownMenuItem(value: 'INTERIOR', child: Text('Interior')),
                DropdownMenuItem(value: 'EXTERIOR', child: Text('Exterior')),
              ],
              onChanged: (v) => setState(() => _categoria = v!),
            ),
            const SizedBox(height: 16),

            // Unidad de medida y costo
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _unidadMedida,
                    decoration: const InputDecoration(
                      labelText: 'Unidad de medida',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.straighten),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'unidad', child: Text('Unidad')),
                      DropdownMenuItem(value: 'metro', child: Text('Metro')),
                      DropdownMenuItem(value: 'litro', child: Text('Litro')),
                      DropdownMenuItem(value: 'kilogramo', child: Text('Kilogramo')),
                      DropdownMenuItem(value: 'rollo', child: Text('Rollo')),
                      DropdownMenuItem(value: 'caja', child: Text('Caja')),
                    ],
                    onChanged: (v) => setState(() => _unidadMedida = v!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _costoController,
                    enabled: _isOwner,
                    decoration: InputDecoration(
                      labelText: 'Costo unitario',
                      border: const OutlineInputBorder(),
                      helperText: !_isOwner ? 'Solo Owner' : null,
                      prefixIcon: Icon(Icons.attach_money),
                      hintText: '0.00',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Vinculación con formulario
            const Divider(),
            SwitchListTile(
              title: const Text('Vincular a formulario de visita'),
              subtitle: Text(
                _isLinked
                    ? 'Se descuenta automáticamente al completar visita'
                    : 'No se descuenta automáticamente',
                style: TextStyle(
                  color: _isLinked ? Colors.green : Colors.grey,
                  fontSize: 12,
                ),
              ),
              value: _isLinked,
              activeColor: Colors.green,
              onChanged: (v) => setState(() => _isLinked = v),
            ),

            if (_isLinked) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Configuración de vinculación',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Indica qué pregunta y opción del formulario descuenta este material',
                      style: TextStyle(color: Colors.grey[600], fontSize: 11),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _questionOptions.contains(_linkedQuestionController.text)
                          ? _linkedQuestionController.text
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Pregunta del formulario',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      isExpanded: true,
                      items: _questionOptions
                          .map((q) => DropdownMenuItem(value: q, child: Text(q, style: const TextStyle(fontSize: 13))))
                          .toList(),
                      onChanged: (v) {
                        setState(() {
                          _linkedQuestionController.text = v ?? '';
                          _linkedOptionController.text = '';
                        });
                      },
                      validator: (_) {
                        if (_isLinked && _linkedQuestionController.text.isEmpty) {
                          return 'Selecciona una pregunta';
                        }
                        return null;
                      },
                    ),
                    if (_linkedQuestionController.text.isNotEmpty &&
                        _isNumericQuestion(_linkedQuestionController.text)) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, size: 16, color: Colors.blue[400]),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Esta pregunta es numérica, no necesita opción. Se vincula directamente.',
                                style: TextStyle(fontSize: 11, color: Colors.blue),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (_linkedQuestionController.text.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _OptionDropdown(
                        questionPattern: _linkedQuestionController.text,
                        currentValue: _linkedOptionController.text.isEmpty
                            ? null
                            : _linkedOptionController.text,
                        onChanged: (v) {
                          setState(() {
                            _linkedOptionController.text = v ?? '';
                          });
                        },
                        validator: (_) {
                          if (_isLinked &&
                              !_isNumericQuestion(_linkedQuestionController.text) &&
                              _linkedOptionController.text.isEmpty) {
                            return 'Selecciona una opción';
                          }
                          return null;
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Botón guardar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThemeConfig.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save),
                label: Text(
                  _isSubmitting ? 'Guardando...' : (_isEditing ? 'Guardar Cambios' : 'Crear Material'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final questionText = _linkedQuestionController.text.trim();
      final isNumeric = _isNumericQuestion(questionText);
      final costo = double.tryParse(_costoController.text.trim()) ?? 0;
      final data = {
        'nombre': _nombreController.text.trim(),
        'marca': _marca,
        'tipo_material': _tipoMaterial,
        'categoria': _categoria,
        'unidad_medida': _unidadMedida,
        'costo_unitario': costo,
        'linked_question_pattern': _isLinked ? questionText : null,
        'linked_option_pattern': _isLinked
            ? (isNumeric ? questionText : _linkedOptionController.text.trim())
            : null,
      };

      if (_isEditing) {
        await SupabaseConfig.client
            .from('pop_materials')
            .update(data)
            .eq('id', widget.material!.id);
      } else {
        final insertData = <String, dynamic>{...data, 'is_active': true};
        await SupabaseConfig.client.from('pop_materials').insert(insertData);
      }

      ref.invalidate(popMaterialsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'Material actualizado' : 'Material creado'),
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

  bool _isNumericQuestion(String question) {
    final numeric = [
      'Cenefas Shell', 'Cenefas Qualid', 'Bolsas Shell', 'Bolsas Qualid',
      'Stickers', 'Ambientadores', 'Papel Bobina', 'Exhibidores',
    ];
    return numeric.any((n) => question.toLowerCase().contains(n.toLowerCase()));
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar material'),
        content: Text('¿Seguro que deseas eliminar "${widget.material!.nombre}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                // Primero eliminar stock y movimientos relacionados
                await SupabaseConfig.client
                    .from('pop_movements')
                    .delete()
                    .eq('material_id', widget.material!.id);
                await SupabaseConfig.client
                    .from('pop_stock')
                    .delete()
                    .eq('material_id', widget.material!.id);
                await SupabaseConfig.client
                    .from('pop_materials')
                    .delete()
                    .eq('id', widget.material!.id);
                ref.invalidate(popMaterialsProvider);
                ref.invalidate(popStockProvider);
                ref.invalidate(popMovementsProvider);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Material eliminado'), backgroundColor: Colors.green),
                  );
                  context.pop();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// Widget que carga opciones dinámicamente desde Supabase
class _OptionDropdown extends ConsumerWidget {
  final String questionPattern;
  final String? currentValue;
  final ValueChanged<String?> onChanged;
  final String? Function(String?)? validator;

  const _OptionDropdown({
    required this.questionPattern,
    this.currentValue,
    required this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final optionsAsync = ref.watch(popFormOptionsProvider(questionPattern));

    return optionsAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Error cargando opciones: $e', style: const TextStyle(color: Colors.red, fontSize: 12)),
      data: (options) {
        if (options.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'No se encontraron opciones para esta pregunta. Completa al menos una visita con esta pregunta para ver opciones.',
              style: TextStyle(fontSize: 11, color: Colors.orange),
            ),
          );
        }

        // Si el valor actual no está en las opciones, agregarlo
        final items = [...options];
        if (currentValue != null && currentValue!.isNotEmpty && !items.contains(currentValue)) {
          items.add(currentValue!);
        }

        return DropdownButtonFormField<String>(
          value: currentValue != null && items.contains(currentValue) ? currentValue : null,
          decoration: const InputDecoration(
            labelText: 'Opción del formulario',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          isExpanded: true,
          items: items
              .map((o) => DropdownMenuItem(value: o, child: Text(o, style: const TextStyle(fontSize: 13))))
              .toList(),
          onChanged: onChanged,
          validator: validator,
        );
      },
    );
  }
}
