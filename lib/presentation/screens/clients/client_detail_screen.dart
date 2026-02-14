import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/client.dart';
import '../../../data/repositories/client_repository.dart';
import '../../../data/services/external_client_api_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/client_provider.dart';

/// Pantalla de detalle de cliente
class ClientDetailScreen extends ConsumerStatefulWidget {
  final String clientId;

  const ClientDetailScreen({
    super.key,
    required this.clientId,
  });

  @override
  ConsumerState<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends ConsumerState<ClientDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clientAsync = ref.watch(clientByIdProvider(widget.clientId));

    return clientAsync.when(
      data: (client) {
        if (client == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Cliente')),
            body: const Center(child: Text('Cliente no encontrado')),
          );
        }
        _notesController.text = client.notes ?? '';
        return _buildContent(context, client);
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Cargando...')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Client client) {
    return Scaffold(
      appBar: AppBar(
        title: Text(client.coCli.trim()),
        actions: [
          // Botón editar
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Editar cliente',
            onPressed: () => _showEditClientDialog(context, client),
          ),
          // Botón cambiar estado activo/inactivo
          IconButton(
            icon: Icon(
              client.inactivo ? Icons.toggle_off : Icons.toggle_on,
              color: client.inactivo ? Colors.grey : Colors.green,
            ),
            tooltip: client.inactivo ? 'Activar cliente' : 'Desactivar cliente',
            onPressed: () => _toggleClientStatus(context, client),
          ),
          if (client.telefonos != null && client.telefonos!.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.phone),
              onPressed: () => _launchPhone(client.telefonos!),
            ),
          if (client.email != null && client.email!.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.email),
              onPressed: () => _launchEmail(client.email!),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Información'),
            Tab(text: 'Visitas'),
            Tab(text: 'Notas'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildInfoTab(context, client),
          _buildVisitsTab(context, client),
          _buildNotesTab(context, client),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addToRoute(context, client),
        icon: const Icon(Icons.route),
        label: const Text('Generar Ruta'),
      ),
    );
  }

  Widget _buildInfoTab(BuildContext context, Client client) {
    final sedeName = client.apiSedecodigo != null
        ? ExternalClientApiService.getSedeNameByCode(client.apiSedecodigo!)
        : 'No definida';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con nombre y estado
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: client.isActive
                              ? Colors.green.withValues(alpha: 0.1)
                              : Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          client.isActive ? 'ACTIVO' : 'INACTIVO',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: client.isActive ? Colors.green : Colors.red,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (client.tipCli != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            client.tipCli!.trim(),
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    client.cliDes,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  if (client.rif != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'RIF: ${client.rif}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Información de contacto
          _buildSectionCard(
            context,
            title: 'Contacto',
            icon: Icons.contact_phone,
            children: [
              if (client.respons != null)
                _buildInfoRow(context, 'Responsable', client.respons!),
              _buildInfoRow(context, 'Teléfono', client.telefonoFormateado,
                  onTap: client.telefonos != null
                      ? () => _launchPhone(client.telefonos!)
                      : null),
              if (client.email != null)
                _buildInfoRow(context, 'Email', client.email!,
                    onTap: () => _launchEmail(client.email!)),
              if (client.emailAlterno != null)
                _buildInfoRow(context, 'Email Alt.', client.emailAlterno!,
                    onTap: () => _launchEmail(client.emailAlterno!)),
            ],
          ),

          const SizedBox(height: 16),

          // Direcciones
          _buildSectionCard(
            context,
            title: 'Direcciones',
            icon: Icons.location_on,
            children: [
              _buildInfoRow(context, 'Principal', client.direccionPrincipal),
              if (client.dirEnt2 != null && client.dirEnt2 != client.direc1)
                _buildInfoRow(context, 'Entrega', client.direccionEntrega),
              _buildInfoRow(context, 'Ciudad', client.ciudad ?? 'No especificada'),
            ],
          ),

          const SizedBox(height: 16),

          // Información comercial
          _buildSectionCard(
            context,
            title: 'Información Comercial',
            icon: Icons.business,
            children: [
              _buildInfoRow(context, 'Sede API', sedeName),
              _buildInfoRow(context, 'Sede App', client.sede?.displayName ?? 'No asignada'),
              if (client.coZon != null)
                _buildInfoRow(context, 'Zona', client.coZon!.trim()),
              if (client.coVen != null)
                _buildInfoRow(context, 'Vendedor', client.coVen!.trim()),
              if (client.coSeg != null)
                _buildInfoRow(context, 'Segmento', client.coSeg!.trim()),
            ],
          ),

          const SizedBox(height: 16),

          // Programa de visitas
          _buildSectionCard(
            context,
            title: 'Programa de Visitas',
            icon: Icons.calendar_today,
            children: [
              if (client.diasVisita.isNotEmpty) ...[
                const Text(
                  'Días de visita:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: client.diasVisita
                      .map((dia) => Chip(
                            label: Text(dia),
                            backgroundColor:
                                Theme.of(context).colorScheme.primaryContainer,
                          ))
                      .toList(),
                ),
              ] else
                const Text('Sin días de visita programados'),
              if (client.frecuVist != null) ...[
                const SizedBox(height: 8),
                Text('Frecuencia: cada ${client.frecuVist} días'),
              ],
            ],
          ),

          const SizedBox(height: 16),

          // Estadísticas de visitas
          _buildSectionCard(
            context,
            title: 'Estadísticas',
            icon: Icons.analytics,
            children: [
              _buildInfoRow(
                context,
                'Total de visitas',
                client.visitCount.toString(),
              ),
              _buildInfoRow(
                context,
                'Última visita',
                client.lastVisitAt != null
                    ? _formatDate(client.lastVisitAt!)
                    : 'Nunca visitado',
              ),
              if (client.diasDesdeUltimaVisita != null)
                _buildInfoRow(
                  context,
                  'Días sin visitar',
                  '${client.diasDesdeUltimaVisita} días',
                ),
            ],
          ),

          const SizedBox(height: 80), // Espacio para el FAB
        ],
      ),
    );
  }

  Widget _buildVisitsTab(BuildContext context, Client client) {
    final visitsAsync = ref.watch(clientVisitsProvider(client.coCli));

    return visitsAsync.when(
      data: (visits) {
        if (visits.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.history,
                  size: 64,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 16),
                const Text('No hay visitas registradas'),
                const SizedBox(height: 8),
                Text(
                  'Las visitas se registran desde el módulo de rutas',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: visits.length,
          itemBuilder: (context, index) {
            final visit = visits[index];
            return _VisitCard(visit: visit);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: $error')),
    );
  }

  Widget _buildNotesTab(BuildContext context, Client client) {
    final actionsState = ref.watch(clientActionsProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: TextField(
              controller: _notesController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(
                hintText: 'Escribe notas sobre este cliente...',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: actionsState.isLoading
                ? null
                : () async {
                    await ref
                        .read(clientActionsProvider.notifier)
                        .updateNotes(client.coCli, _notesController.text);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Notas guardadas')),
                      );
                    }
                  },
            icon: actionsState.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: const Text('Guardar Notas'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value, {
    VoidCallback? onTap,
  }) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.outline,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: onTap != null
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
            ),
          ),
          if (onTap != null)
            Icon(
              Icons.chevron_right,
              size: 20,
              color: Theme.of(context).colorScheme.outline,
            ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        child: content,
      );
    }
    return content;
  }

  Future<void> _addToRoute(BuildContext context, Client client) async {
    // TODO: Implementar cuando esté el módulo de rutas
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Cliente "${client.cliDes}" agregado a la ruta'),
        action: SnackBarAction(
          label: 'Ver Ruta',
          onPressed: () {
            // TODO: Navegar al módulo de rutas
          },
        ),
      ),
    );
  }

  Future<void> _launchPhone(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchEmail(String email) async {
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  /// Cambia el estado activo/inactivo del cliente
  Future<void> _toggleClientStatus(BuildContext context, Client client) async {
    final newStatus = !client.inactivo;
    final action = newStatus ? 'desactivar' : 'activar';
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${newStatus ? 'Desactivar' : 'Activar'} Cliente'),
        content: Text('¿Estás seguro de que deseas $action este cliente?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: newStatus ? Colors.red : Colors.green,
            ),
            child: Text(newStatus ? 'Desactivar' : 'Activar'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final repository = ref.read(clientRepositoryProvider);
        await repository.toggleClientStatus(client.coCli, newStatus);
        
        // Refrescar datos
        ref.invalidate(clientByIdProvider(widget.clientId));
        ref.invalidate(clientsProvider);
        ref.invalidate(clientStatsProvider);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cliente ${newStatus ? 'desactivado' : 'activado'} exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
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
      }
    }
  }

  /// Muestra el diálogo para editar el cliente
  Future<void> _showEditClientDialog(BuildContext context, Client client) async {
    final formKey = GlobalKey<FormState>();
    final nombreController = TextEditingController(text: client.cliDes);
    final ciudadController = TextEditingController(text: client.ciudad ?? '');
    final direccionController = TextEditingController(text: client.direc1 ?? '');
    final telefonoController = TextEditingController(text: client.telefonos ?? '');
    final rifController = TextEditingController(text: client.rif ?? '');
    final emailController = TextEditingController(text: client.email ?? '');
    final responsableController = TextEditingController(text: client.respons ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Cliente'),
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
            onPressed: () {
              if (formKey.currentState?.validate() == true) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      try {
        final repository = ref.read(clientRepositoryProvider);
        await repository.updateClient(
          coCli: client.coCli,
          cliDes: nombreController.text,
          ciudad: ciudadController.text.isNotEmpty ? ciudadController.text : null,
          direc1: direccionController.text.isNotEmpty ? direccionController.text : null,
          telefonos: telefonoController.text.isNotEmpty ? telefonoController.text : null,
          rif: rifController.text.isNotEmpty ? rifController.text : null,
          email: emailController.text.isNotEmpty ? emailController.text : null,
          respons: responsableController.text.isNotEmpty ? responsableController.text : null,
        );
        
        // Refrescar datos
        ref.invalidate(clientByIdProvider(widget.clientId));
        ref.invalidate(clientsProvider);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cliente actualizado exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al actualizar: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

/// Tarjeta de visita
class _VisitCard extends StatelessWidget {
  final ClientVisit visit;

  const _VisitCard({required this.visit});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDateTime(visit.visitedAt),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            if (visit.notes != null && visit.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                visit.notes!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
            if (visit.latitude != null && visit.longitude != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 16,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${visit.latitude!.toStringAsFixed(4)}, ${visit.longitude!.toStringAsFixed(4)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
