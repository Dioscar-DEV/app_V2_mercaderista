import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/enums/event_status.dart';
import '../../../../core/models/event.dart';
import '../../../../core/models/user.dart';
import '../../../../core/models/route_type.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/event_provider.dart';
import 'map_location_picker_screen.dart';

/// Pantalla de creación/edición de evento
class CreateEditEventScreen extends ConsumerStatefulWidget {
  final String? eventId;

  const CreateEditEventScreen({super.key, this.eventId});

  @override
  ConsumerState<CreateEditEventScreen> createState() =>
      _CreateEditEventScreenState();
}

class _CreateEditEventScreenState extends ConsumerState<CreateEditEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  String? _selectedRouteTypeId;
  double? _latitude;
  double? _longitude;
  List<String> _selectedMercaderistaIds = [];
  bool _isSaving = false;

  // ID de Impulso como tipo de formulario por defecto
  static const String _impulsoRouteTypeId = 'ca89371f-8948-45e6-91d3-d259650c5a9e';

  bool get isEditing => widget.eventId != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _loadEvent();
    } else {
      // Pre-seleccionar Impulso como tipo de formulario por defecto
      _selectedRouteTypeId = _impulsoRouteTypeId;
    }
  }

  Future<void> _loadEvent() async {
    final repo = ref.read(eventRepositoryProvider);
    final event = await repo.getEventById(widget.eventId!);
    if (event != null && mounted) {
      setState(() {
        _nameController.text = event.name;
        _descriptionController.text = event.description ?? '';
        _locationController.text = event.locationName ?? '';
        _notesController.text = event.notes ?? '';
        _startDate = event.startDate;
        _endDate = event.endDate;
        _selectedRouteTypeId = event.routeTypeId;
        _latitude = event.latitude;
        _longitude = event.longitude;
        _selectedMercaderistaIds =
            event.mercaderistas?.map((m) => m.mercaderistaId).toList() ?? [];
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// Abre el selector de ubicación en mapa
  Future<void> _openMapPicker() async {
    final result = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) => MapLocationPickerScreen(
          initialLatitude: _latitude,
          initialLongitude: _longitude,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _latitude = result.latitude;
        _longitude = result.longitude;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Ubicación seleccionada: ${result.latitude.toStringAsFixed(4)}, ${result.longitude.toStringAsFixed(4)}'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  /// Guarda el evento
  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedMercaderistaIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona al menos un mercaderista'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = ref.read(currentUserProvider).valueOrNull;
      if (user == null) return;

      final repo = ref.read(eventRepositoryProvider);

      final event = AppEvent(
        id: widget.eventId ?? '',
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        routeTypeId: _selectedRouteTypeId,
        locationName: _locationController.text.trim().isNotEmpty
            ? _locationController.text.trim()
            : null,
        latitude: _latitude,
        longitude: _longitude,
        startDate: _startDate,
        endDate: _endDate,
        status: EventStatus.planned,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        sedeApp: user.sede?.value ?? 'grupo_disbattery',
        createdBy: user.id,
        createdAt: DateTime.now(),
      );

      if (isEditing) {
        await repo.updateEvent(event);
        await repo.assignMercaderistas(
          eventId: widget.eventId!,
          mercaderistaIds: _selectedMercaderistaIds,
          event: event,
          adminName: user.fullName,
        );
      } else {
        final created = await repo.createEvent(event);
        // Asignar mercaderistas y notificar
        await repo.assignMercaderistas(
          eventId: created.id,
          mercaderistaIds: _selectedMercaderistaIds,
          event: created,
          adminName: user.fullName,
        );
      }

      if (mounted) {
        // Invalidar provider para refrescar la lista
        ref.invalidate(eventsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing ? 'Evento actualizado' : 'Evento creado'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final sedeApp = user?.sede?.value;

    final mercaderistasAsync =
        ref.watch(availableMercaderistasProvider(sedeApp));

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Evento' : 'Crear Evento'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Nombre del evento
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del Evento *',
                  prefixIcon: Icon(Icons.event),
                  hintText: 'Ej: Expo Offroad Caracas 2026',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
              ),
              const SizedBox(height: 16),

              // Descripción
              TextFormField(
                controller: _descriptionController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  prefixIcon: Icon(Icons.description),
                ),
              ),
              const SizedBox(height: 16),

              // Fechas
              Row(
                children: [
                  Expanded(
                    child: _DateField(
                      label: 'Fecha Inicio *',
                      date: _startDate,
                      onChanged: (d) {
                        setState(() {
                          _startDate = d;
                          if (_endDate.isBefore(d)) _endDate = d;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DateField(
                      label: 'Fecha Fin *',
                      date: _endDate,
                      firstDate: _startDate,
                      onChanged: (d) => setState(() => _endDate = d),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${_endDate.difference(_startDate).inDays + 1} día(s)',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Ubicación
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del Lugar',
                  prefixIcon: Icon(Icons.location_on),
                  hintText: 'Ej: Centro Comercial Sambil',
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _openMapPicker,
                icon: const Icon(Icons.map),
                label: Text(_latitude != null
                    ? 'Ubicación: ${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}'
                    : 'Seleccionar en Mapa'),
              ),
              const SizedBox(height: 16),

              // Tipo de formulario (tipo de ruta)
              _buildRouteTypeSelector(),
              const SizedBox(height: 16),

              // Selección de mercaderistas
              const Text(
                'Mercaderistas Asignados *',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              mercaderistasAsync.when(
                data: (mercaderistas) =>
                    _buildMercaderistasSelector(mercaderistas),
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error cargando mercaderistas: $e'),
              ),
              const SizedBox(height: 16),

              // Notas
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notas',
                  prefixIcon: Icon(Icons.notes),
                ),
              ),
              const SizedBox(height: 24),

              // Botón guardar
              ElevatedButton(
                onPressed: _isSaving ? null : _saveEvent,
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(isEditing ? 'Actualizar Evento' : 'Crear Evento'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRouteTypeSelector() {
    return FutureBuilder<List<RouteType>>(
      future: __getRouteTypes(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const LinearProgressIndicator();
        }
        final types = snapshot.data!;
        return DropdownButtonFormField<String>(
          value: _selectedRouteTypeId,
          decoration: const InputDecoration(
            labelText: 'Tipo de Formulario',
            prefixIcon: Icon(Icons.assignment),
          ),
          items: [
            const DropdownMenuItem(
              value: null,
              child: Text('Sin formulario'),
            ),
            ...types.map((t) => DropdownMenuItem(
                  value: t.id,
                  child: Text(t.name),
                )),
          ],
          onChanged: (v) => setState(() => _selectedRouteTypeId = v),
        );
      },
    );
  }

  Future<List<RouteType>> __getRouteTypes() async {
    final response = await Supabase.instance.client
        .from('route_types')
        .select()
        .eq('is_active', true)
        .order('name');
    return (response as List)
        .map((json) => RouteType.fromJson(json))
        .toList();
  }

  Widget _buildMercaderistasSelector(List<AppUser> mercaderistas) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Chips de seleccionados
        if (_selectedMercaderistaIds.isNotEmpty) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _selectedMercaderistaIds.map((id) {
              final match = mercaderistas.where((u) => u.id == id);
              final name = match.isNotEmpty ? match.first.fullName : 'Desconocido';
              return Chip(
                label: Text(name, style: const TextStyle(fontSize: 12)),
                onDeleted: () {
                  setState(() => _selectedMercaderistaIds.remove(id));
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
        ],

        // Botón para agregar
        OutlinedButton.icon(
          onPressed: () => _showMercaderistaPicker(mercaderistas),
          icon: const Icon(Icons.person_add),
          label: Text('Agregar Mercaderistas (${_selectedMercaderistaIds.length})'),
        ),
      ],
    );
  }

  void _showMercaderistaPicker(List<AppUser> mercaderistas) {
    // Copia temporal
    final tempSelected = List<String>.from(_selectedMercaderistaIds);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              maxChildSize: 0.9,
              expand: false,
              builder: (_, controller) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Text(
                            'Seleccionar Mercaderistas',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              setState(
                                  () => _selectedMercaderistaIds = tempSelected);
                              Navigator.of(ctx).pop();
                            },
                            child: const Text('Listo'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        controller: controller,
                        itemCount: mercaderistas.length,
                        itemBuilder: (_, i) {
                          final m = mercaderistas[i];
                          final isSelected = tempSelected.contains(m.id);
                          return CheckboxListTile(
                            title: Text(m.fullName),
                            subtitle: Text(m.email),
                            value: isSelected,
                            onChanged: (v) {
                              setSheetState(() {
                                if (v == true) {
                                  tempSelected.add(m.id);
                                } else {
                                  tempSelected.remove(m.id);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

/// Widget de campo de fecha
class _DateField extends StatelessWidget {
  final String label;
  final DateTime date;
  final DateTime? firstDate;
  final ValueChanged<DateTime> onChanged;

  const _DateField({
    required this.label,
    required this.date,
    this.firstDate,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: firstDate ?? DateTime.now().subtract(const Duration(days: 30)),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today, size: 20),
        ),
        child: Text(
          '${date.day}/${date.month}/${date.year}',
          style: const TextStyle(fontSize: 14),
        ),
      ),
    );
  }
}
