import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/client.dart';
import '../../../core/models/route.dart';
import '../../../core/models/route_visit.dart';
import '../../../core/models/route_template.dart';
import '../../../config/theme_config.dart';
import '../../../config/supabase_config.dart';
import '../../../data/repositories/route_repository.dart';
import '../../../data/services/location_service.dart';
import '../../providers/route_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/client_provider.dart';
import '../../widgets/client_selector_sheet.dart';
import '../../widgets/route_visit_form.dart';
import '../../widgets/merchandising_visit_form.dart';
import '../../widgets/impulso_visit_form.dart';
import '../../widgets/evento_visit_form.dart';

/// Pantalla de ejecución de ruta para mercaderista
/// Diseñada para funcionar offline una vez cargada
class RouteExecutionScreen extends ConsumerStatefulWidget {
  final String routeId;

  const RouteExecutionScreen({super.key, required this.routeId});

  @override
  ConsumerState<RouteExecutionScreen> createState() =>
      _RouteExecutionScreenState();
}

class _RouteExecutionScreenState extends ConsumerState<RouteExecutionScreen> {
  bool _gpsAvailable = false;
  StreamSubscription<ConnectivityResult>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    // Limpiar estado de la ruta anterior
    final notifier = ref.read(routeExecutionProvider.notifier);
    notifier.clear();
    // Registrar callback para auto-complete (solo se dispara por accion real del usuario)
    notifier.onAutoComplete = _showAutoCompleteDialog;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(routeExecutionProvider.notifier).loadRoute(widget.routeId);
      _checkGPS();
    });
    // Escuchar cambios de conectividad para auto-sync y actualizar badge
    _connectivitySub = Connectivity().onConnectivityChanged.listen((result) {
      final isOnline = result == ConnectivityResult.wifi ||
          result == ConnectivityResult.mobile ||
          result == ConnectivityResult.ethernet;
      final notifier = ref.read(routeExecutionProvider.notifier);
      notifier.setOfflineMode(!isOnline);
      // Al volver online, sincronizar visitas pendientes automaticamente
      if (isOnline) {
        _autoSyncPendingVisits();
      }
    });
  }

  Future<void> _checkGPS() async {
    final hasPermission = await LocationService.instance.requestPermissions();
    if (mounted) {
      setState(() => _gpsAvailable = hasPermission);
    }
  }

  /// Sincroniza visitas pendientes automaticamente al volver online
  Future<void> _autoSyncPendingVisits() async {
    final state = ref.read(routeExecutionProvider);
    if (state.pendingVisits.isEmpty) return;
    try {
      await ref.read(routeExecutionProvider.notifier).syncPendingVisits();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Visitas sincronizadas automaticamente'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (_) {}
  }

  /// Dialog de auto-complete — solo se llama via callback cuando el usuario
  /// realmente procesa todos los clientes (no por estado residual)
  void _showAutoCompleteDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.celebration, color: Colors.green, size: 48),
        title: const Text('Ruta Finalizada'),
        content: const Text(
          'Todos los clientes cuentan con registro. Gracias por tu trabajo.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    final notifier = ref.read(routeExecutionProvider.notifier);
    notifier.onAutoComplete = null; // Limpiar callback
    notifier.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final executionState = ref.watch(routeExecutionProvider);
    final currentUserAsync = ref.watch(currentUserProvider);
    final currentUser = currentUserAsync.valueOrNull;
    final isMercaderista = currentUser?.isMercaderista ?? false;

    if (executionState.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cargando Ruta...')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Descargando datos de la ruta...'),
              SizedBox(height: 8),
              Text(
                'Una vez cargada, podrás trabajar sin internet',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    if (executionState.error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(executionState.error!),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref
                    .read(routeExecutionProvider.notifier)
                    .loadRoute(widget.routeId),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    // (auto-complete dialog se maneja via callback, no via state flag)

    final route = executionState.route;
    if (route == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ruta no encontrada')),
        body: const Center(child: Text('No se encontró la ruta')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(route.name),
        actions: [
          // GPS indicator
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: _gpsAvailable
                  ? Colors.green.withValues(alpha: 0.15)
                  : Colors.red.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _gpsAvailable ? Icons.gps_fixed : Icons.gps_off,
                  size: 16,
                  color: _gpsAvailable ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 2),
                Text(
                  _gpsAvailable ? 'GPS' : 'Sin GPS',
                  style: TextStyle(
                    color: _gpsAvailable ? Colors.green : Colors.red,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (executionState.isOfflineMode)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.wifi_off, size: 16, color: Colors.white),
                  SizedBox(width: 4),
                  Text('Offline',
                      style: TextStyle(color: Colors.white, fontSize: 11)),
                ],
              ),
            ),
          if (executionState.pendingVisits.isNotEmpty)
            IconButton(
              icon: Badge(
                label: Text('${executionState.pendingVisits.length}'),
                child: const Icon(Icons.sync),
              ),
              onPressed: () => _syncPendingVisits(),
              tooltip:
                  'Sincronizar ${executionState.pendingVisits.length} visitas',
            ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'complete':
                  _completeRoute();
                  break;
                case 'cancel':
                  _cancelRoute();
                  break;
                case 'template':
                  _convertToTemplate(route);
                  break;
                case 'add_clients':
                  _addClientsToRoute(route);
                  break;
              }
            },
            itemBuilder: (context) => [
              if (isMercaderista)
                const PopupMenuItem(
                  value: 'complete',
                  child: ListTile(
                    leading: Icon(Icons.check_circle, color: Colors.green),
                    title: Text('Finalizar ruta'),
                  ),
                ),
              if (isMercaderista)
                const PopupMenuItem(
                  value: 'cancel',
                  child: ListTile(
                    leading: Icon(Icons.cancel, color: Colors.red),
                    title: Text('Cancelar ruta'),
                  ),
                ),
              if (!isMercaderista)
                const PopupMenuItem(
                  value: 'add_clients',
                  child: ListTile(
                    leading: Icon(Icons.person_add, color: Colors.blue),
                    title: Text('Agregar clientes'),
                  ),
                ),
              if (!isMercaderista)
                const PopupMenuItem(
                  value: 'template',
                  child: ListTile(
                    leading: Icon(Icons.copy),
                    title: Text('Convertir en plantilla'),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _buildProgressBar(executionState),
          Expanded(
            child: route.clients == null || route.clients!.isEmpty
                ? const Center(child: Text('No hay clientes en esta ruta'))
                : _buildClientList(executionState, isMercaderista),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(RouteExecutionState state) {
    final route = state.route!;
    final clients = route.clients ?? [];
    final completed =
        clients.where((c) => c.isCompleted).length;
    final closed = clients.where((c) => c.isClosedTemp).length;
    final skipped = clients.where((c) => c.isSkipped).length;
    final total = clients.length;
    final done = completed + closed + skipped;
    final progress = total > 0 ? done / total : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Badge del tipo de ruta
              if (route.routeType != null)
                Container(
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _parseRouteTypeColor(route.routeType!.color).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: _parseRouteTypeColor(route.routeType!.color).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    route.routeType!.name,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _parseRouteTypeColor(route.routeType!.color),
                    ),
                  ),
                ),
              Expanded(
                child: Row(
                  children: [
                    _buildMiniStat(Icons.check_circle, Colors.green, '$completed'),
                    const SizedBox(width: 12),
                    _buildMiniStat(Icons.schedule, Colors.grey, '${total - done}'),
                    if (closed > 0) ...[
                      const SizedBox(width: 12),
                      _buildMiniStat(Icons.store_mall_directory, Colors.red, '$closed'),
                    ],
                    if (skipped > 0) ...[
                      const SizedBox(width: 12),
                      _buildMiniStat(Icons.skip_next, Colors.orange, '$skipped'),
                    ],
                  ],
                ),
              ),
              Text(
                '$done/$total',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                progress == 1.0 ? Colors.green : ThemeConfig.primaryColor,
              ),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Color _parseRouteTypeColor(String hexColor) {
    try {
      final hex = hexColor.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return ThemeConfig.primaryColor;
    }
  }

  Widget _buildMiniStat(IconData icon, Color color, String count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 2),
        Text(count, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildClientList(RouteExecutionState state, bool isMercaderista) {
    final clients = state.route!.clients!;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: clients.length,
      itemBuilder: (context, index) {
        final routeClient = clients[index];
        final isSelected = index == state.currentClientIndex;

        return _buildClientCard(
            routeClient, index, isSelected, state, isMercaderista);
      },
    );
  }

  Widget _buildClientCard(
    RouteClient routeClient,
    int index,
    bool isSelected,
    RouteExecutionState state,
    bool isMercaderista,
  ) {
    final client = routeClient.client;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: isSelected ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(color: ThemeConfig.primaryColor, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          ref.read(routeExecutionProvider.notifier).goToClient(index);
        },
        child: Column(
          children: [
            // Header: always visible
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: _getStatusColor(routeClient.status)
                        .withValues(alpha: 0.2),
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: _getStatusColor(routeClient.status),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          client?.cliDes ?? 'Cliente ${index + 1}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            decoration: routeClient.isCompleted ||
                                    routeClient.isSkipped ||
                                    routeClient.isClosedTemp
                                ? TextDecoration.lineThrough
                                : null,
                            color: routeClient.isCompleted ||
                                    routeClient.isSkipped ||
                                    routeClient.isClosedTemp
                                ? Colors.grey
                                : null,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (client?.isSucursal == true)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                'Sucursal',
                                style: TextStyle(fontSize: 10, color: Colors.blue.shade600),
                              ),
                            ),
                          ),
                        if (client?.direc1 != null)
                          Text(
                            client!.direc1!,
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildStatusChip(routeClient.status),
                ],
              ),
            ),

            // Expanded action area: only for selected client
            if (isSelected) ...[
              const Divider(height: 1),
              _buildClientActionArea(routeClient, state, isMercaderista),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildClientActionArea(
    RouteClient routeClient,
    RouteExecutionState state,
    bool isMercaderista,
  ) {
    final client = routeClient.client;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Client details
          if (client != null) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                client.cliDes,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (client.rif != null && client.rif!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Icon(Icons.assignment_ind, size: 14, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text('RIF: ${client.rif}',
                        style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                  ],
                ),
              ),
            if (client.isSucursal)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(Icons.account_tree, size: 14, color: Colors.blue.shade400),
                    const SizedBox(width: 6),
                    Text(
                      'Sucursal${client.sucursalNumero != null ? ' #${client.sucursalNumero}' : ''} · Base: ${client.coCliBase}',
                      style: TextStyle(fontSize: 12, color: Colors.blue.shade600, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            if (client.direc1 != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, size: 14, color: Colors.grey),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(client.direc1!,
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey[700])),
                    ),
                  ],
                ),
              ),
            if (client.telefonos != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Icon(Icons.phone, size: 14, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(client.telefonos!,
                        style:
                            TextStyle(fontSize: 13, color: Colors.grey[700])),
                  ],
                ),
              ),
            if (client.coCli.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    const Icon(Icons.badge, size: 14, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text('Código: ${client.coCli}',
                        style:
                            TextStyle(fontSize: 13, color: Colors.grey[700])),
                  ],
                ),
              ),
          ],

          // Open in Maps button (only if coordinates exist)
          if (_getClientCoordinates(routeClient) != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    final coords = _getClientCoordinates(routeClient)!;
                    _openInMaps(coords.$1, coords.$2);
                  },
                  icon: const Icon(Icons.map, size: 18),
                  label: const Text('Abrir en Mapa'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue[700],
                    side: BorderSide(color: Colors.blue[300]!),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),

          // Action area based on status and role
          if (!isMercaderista) ...[
            _buildReadOnlyStatus(routeClient),
          ] else if (routeClient.isPending) ...[
            _buildPendingActions(routeClient),
          ] else if (routeClient.isInProgress) ...[
            _buildInProgressActions(routeClient, state),
          ] else if (routeClient.isCompleted) ...[
            _buildCompletedStatus(routeClient),
          ] else if (routeClient.isSkipped) ...[
            _buildSkippedStatus(routeClient),
          ] else if (routeClient.isClosedTemp) ...[
            _buildClosedStatus(routeClient),
          ],
        ],
      ),
    );
  }

  Widget _buildReadOnlyStatus(RouteClient routeClient) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.visibility, color: Colors.blue[700], size: 20),
          const SizedBox(width: 8),
          Text(
            'Estado: ${_getStatusText(routeClient.status)}',
            style: TextStyle(
                color: Colors.blue[700], fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingActions(RouteClient routeClient) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _startVisit(routeClient),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Iniciar Visita'),
            style: ElevatedButton.styleFrom(
              backgroundColor: ThemeConfig.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _skipClient(routeClient),
                icon: const Icon(Icons.skip_next, size: 18),
                label: const Text('Omitir'),
                style:
                    OutlinedButton.styleFrom(foregroundColor: Colors.orange),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showClosedOptions(routeClient),
                icon: const Icon(Icons.store_mall_directory, size: 18),
                label: const Text('Cerrado'),
                style:
                    OutlinedButton.styleFrom(foregroundColor: Colors.red[700]),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInProgressActions(
      RouteClient routeClient, RouteExecutionState state) {
    return Column(
      children: [
        // Formulario según tipo de ruta
        if (state.route?.routeType?.name == 'Merchandising')
          MerchandisingVisitForm(
            questions: state.questions,
            onComplete: (answers, photoUrls, observations) {
              _completeVisit(routeClient, answers, photoUrls, observations);
            },
          )
        else if (state.route?.routeType?.name == 'Impulso')
          ImpulsoVisitForm(
            questions: state.questions,
            availableBrands: state.route!.availableBrands,
            onComplete: (answers, photoUrls, observations) {
              _completeVisit(routeClient, answers, photoUrls, observations);
            },
          )
        else if (state.route?.routeType?.name == 'Evento')
          EventoVisitForm(
            questions: state.questions,
            onComplete: (answers, photoUrls, observations) {
              _completeVisit(routeClient, answers, photoUrls, observations);
            },
          )
        else
          RouteVisitForm(
            questions: state.questions,
            onComplete: (answers, photoUrls, observations) {
              _completeVisit(routeClient, answers, photoUrls, observations);
            },
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _skipClient(routeClient),
                icon: const Icon(Icons.skip_next, size: 18),
                label: const Text('Omitir'),
                style:
                    OutlinedButton.styleFrom(foregroundColor: Colors.orange),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showClosedOptions(routeClient),
                icon: const Icon(Icons.store_mall_directory, size: 18),
                label: const Text('Cerrado'),
                style:
                    OutlinedButton.styleFrom(foregroundColor: Colors.red[700]),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCompletedStatus(RouteClient routeClient) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, color: Colors.green[700], size: 20),
          const SizedBox(width: 8),
          Text(
            routeClient.completedAt != null
                ? 'Completada a las ${_formatTime(routeClient.completedAt!)}'
                : 'Visita Completada',
            style: TextStyle(
                color: Colors.green[700], fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildSkippedStatus(RouteClient routeClient) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.skip_next, color: Colors.orange[700], size: 20),
              const SizedBox(width: 8),
              Text(
                'Visita Omitida',
                style: TextStyle(
                    color: Colors.orange[700], fontWeight: FontWeight.w500),
              ),
            ],
          ),
          if (routeClient.closureReason != null &&
              routeClient.closureReason!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              routeClient.closureReason!,
              style: TextStyle(color: Colors.orange[400], fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildClosedStatus(RouteClient routeClient) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.store_mall_directory,
                  color: Colors.red[700], size: 20),
              const SizedBox(width: 8),
              Text(
                'Negocio Cerrado',
                style: TextStyle(
                    color: Colors.red[700], fontWeight: FontWeight.w500),
              ),
            ],
          ),
          if (routeClient.closureReason != null &&
              routeClient.closureReason!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              routeClient.closureReason!,
              style: TextStyle(color: Colors.red[400], fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
          if (routeClient.closurePhotoUrl != null &&
              routeClient.closurePhotoUrl!.isNotEmpty) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _showFullScreenPhoto(routeClient.closurePhotoUrl!),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: routeClient.closurePhotoUrl!.startsWith('local:')
                    ? Image.file(
                        File(routeClient.closurePhotoUrl!.replaceFirst('local:', '')),
                        height: 120,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 60,
                          color: Colors.grey[200],
                          child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                        ),
                      )
                    : Image.network(
                        routeClient.closurePhotoUrl!,
                        height: 120,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 60,
                          color: Colors.grey[200],
                          child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                        ),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showFullScreenPhoto(String photoUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(8),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: photoUrl.startsWith('local:')
                    ? Image.file(File(photoUrl.replaceFirst('local:', '')))
                    : Image.network(photoUrl),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(RouteClientStatus status) {
    Color backgroundColor;
    Color textColor;
    String label;
    IconData icon;

    switch (status) {
      case RouteClientStatus.pending:
        backgroundColor = Colors.grey[200]!;
        textColor = Colors.grey[700]!;
        label = 'Pendiente';
        icon = Icons.schedule;
        break;
      case RouteClientStatus.inProgress:
        backgroundColor = Colors.blue[100]!;
        textColor = Colors.blue[700]!;
        label = 'En Progreso';
        icon = Icons.play_arrow;
        break;
      case RouteClientStatus.completed:
        backgroundColor = Colors.green[100]!;
        textColor = Colors.green[700]!;
        label = 'Completado';
        icon = Icons.check;
        break;
      case RouteClientStatus.skipped:
        backgroundColor = Colors.orange[100]!;
        textColor = Colors.orange[700]!;
        label = 'Omitido';
        icon = Icons.skip_next;
        break;
      case RouteClientStatus.closedTemp:
        backgroundColor = Colors.red[100]!;
        textColor = Colors.red[700]!;
        label = 'Cerrado';
        icon = Icons.store_mall_directory;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(RouteClientStatus status) {
    switch (status) {
      case RouteClientStatus.pending:
        return Colors.grey;
      case RouteClientStatus.inProgress:
        return Colors.blue;
      case RouteClientStatus.completed:
        return Colors.green;
      case RouteClientStatus.skipped:
        return Colors.orange;
      case RouteClientStatus.closedTemp:
        return Colors.red;
    }
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _getStatusText(RouteClientStatus status) {
    switch (status) {
      case RouteClientStatus.pending:
        return 'Pendiente';
      case RouteClientStatus.inProgress:
        return 'En Progreso';
      case RouteClientStatus.completed:
        return 'Completada';
      case RouteClientStatus.skipped:
        return 'Omitida';
      case RouteClientStatus.closedTemp:
        return 'Cerrado';
    }
  }

  // --- Maps ---

  /// Returns (lat, lng) from the client record (tabla clients).
  /// These are saved when a visit is completed with valid GPS.
  (double, double)? _getClientCoordinates(RouteClient routeClient) {
    final client = routeClient.client;
    if (client != null &&
        client.latitude != null &&
        client.longitude != null &&
        client.latitude != 0.0 &&
        client.longitude != 0.0) {
      return (client.latitude!, client.longitude!);
    }
    return null;
  }

  Future<void> _openInMaps(double lat, double lng) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir Google Maps')),
      );
    }
  }

  // --- Actions ---

  Future<void> _startVisit(RouteClient client) async {
    double? latitude;
    double? longitude;

    if (_gpsAvailable) {
      final coords = await LocationService.instance.getCoordinates();
      if (coords != null) {
        latitude = coords.latitude;
        longitude = coords.longitude;
      }
    }

    await ref.read(routeExecutionProvider.notifier).startCurrentClientVisit(
          latitude: latitude ?? 0.0,
          longitude: longitude ?? 0.0,
        );

    if (!_gpsAvailable && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('GPS no disponible. Ubicación no registrada.'),
          backgroundColor: Colors.orange[700],
          action: SnackBarAction(
            label: 'Activar',
            textColor: Colors.white,
            onPressed: () => LocationService.instance.openLocationSettings(),
          ),
        ),
      );
    }
  }

  Future<void> _completeVisit(
    RouteClient client,
    List<RouteVisitAnswer> answers,
    List<String> photoUrls,
    String? observations,
  ) async {
    double? latitude;
    double? longitude;

    if (_gpsAvailable) {
      final coords = await LocationService.instance.getCoordinates();
      if (coords != null) {
        latitude = coords.latitude;
        longitude = coords.longitude;
      }
    }

    final currentUser = ref.read(currentUserProvider).valueOrNull;

    await ref
        .read(routeExecutionProvider.notifier)
        .completeCurrentClientVisit(
          latitude: latitude ?? 0.0,
          longitude: longitude ?? 0.0,
          answers: answers,
          photoUrls: photoUrls,
          observations: observations,
          mercaderistaId: currentUser?.id,
        );
  }

  Future<void> _skipClient(RouteClient client) async {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Omitir Cliente'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('¿Por qué deseas omitir este cliente?'),
              const SizedBox(height: 16),
              TextFormField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Motivo *',
                  hintText: 'Ej: No se encontraba, dirección incorrecta...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El motivo es obligatorio';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Omitir'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(routeExecutionProvider.notifier).skipCurrentClient(
            reason: reasonController.text.trim(),
          );
    }
    reasonController.dispose();
  }

  void _showClosedOptions(RouteClient routeClient) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  'Marcar como cerrado',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(),
              ListTile(
                leading: Icon(Icons.access_time, color: Colors.orange[700]),
                title: const Text('Cerrado temporalmente'),
                subtitle: const Text('El negocio está cerrado hoy'),
                onTap: () {
                  Navigator.pop(context);
                  _markClientClosedTemp(routeClient);
                },
              ),
              ListTile(
                leading: Icon(Icons.block, color: Colors.red[700]),
                title: const Text('Cerrado permanentemente'),
                subtitle: const Text('El negocio cerró definitivamente'),
                onTap: () {
                  Navigator.pop(context);
                  _markClientClosedPermanent(routeClient);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _markClientClosedTemp(RouteClient routeClient) async {
    // 1. Abrir cámara para foto del local cerrado
    File? photoFile;
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 80,
      );
      if (pickedFile == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Debes tomar foto del local cerrado')),
        );
        return;
      }
      photoFile = await _compressClosurePhoto(File(pickedFile.path));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al capturar foto: $e'), backgroundColor: Colors.red),
      );
      return;
    }

    // 2. Mostrar dialog con preview + motivo obligatorio
    if (!mounted) return;
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrado Temporalmente'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    photoFile!,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Foto del local cerrado tomada correctamente.',
                    style: TextStyle(color: Colors.green, fontSize: 12)),
                const SizedBox(height: 16),
                TextFormField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Motivo *',
                    hintText: 'Ej: Horario reducido, día feriado...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'El motivo es obligatorio';
                    }
                    return null;
                  },
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
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // 3. Subir foto a Supabase Storage
      String? photoUrl;
      try {
        final userId = SupabaseConfig.currentUser?.id ?? 'unknown';
        final fileName = 'closure_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final storagePath = '$userId/$fileName';
        final bytes = await photoFile.readAsBytes();
        photoUrl = await SupabaseConfig.uploadFile(
          SupabaseConfig.visitPhotosBucket,
          storagePath,
          bytes,
        );
      } catch (e) {
        // Si falla la subida, guardar path local para sync posterior
        photoUrl = 'local:${photoFile.path}';
      }

      await ref
          .read(routeExecutionProvider.notifier)
          .markCurrentClientClosedTemp(
            reason: reasonController.text.trim(),
            photoUrl: photoUrl,
          );
    }
    reasonController.dispose();
  }

  /// Comprime imagen para foto de cierre
  Future<File> _compressClosurePhoto(File file) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final photoDir = Directory('${appDir.path}/visit_photos');
      if (!await photoDir.exists()) await photoDir.create(recursive: true);
      final targetPath = p.join(
          photoDir.path, 'closure_${DateTime.now().millisecondsSinceEpoch}.jpg');

      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 70,
        minWidth: 800,
        minHeight: 800,
      );

      if (result != null) return File(result.path);
    } catch (_) {}
    return file;
  }

  Future<void> _markClientClosedPermanent(RouteClient routeClient) async {
    // 1. Abrir cámara para foto del local cerrado
    File? photoFile;
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 80,
      );
      if (pickedFile == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Debes tomar foto del local cerrado')),
        );
        return;
      }
      photoFile = await _compressClosurePhoto(File(pickedFile.path));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al capturar foto: $e'), backgroundColor: Colors.red),
      );
      return;
    }

    // 2. Mostrar dialog con preview + motivo obligatorio
    if (!mounted) return;
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrado Permanentemente'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'ATENCION: Esto marcará el negocio como cerrado permanentemente en el sistema.',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    photoFile!,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Foto del local cerrado tomada correctamente.',
                    style: TextStyle(color: Colors.green, fontSize: 12)),
                const SizedBox(height: 16),
                TextFormField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Motivo *',
                    hintText: 'Ej: Negocio cerró, cambió de dueño...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'El motivo es obligatorio';
                    }
                    return null;
                  },
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
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Confirmar cierre'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // 3. Subir foto a Supabase Storage
      String? photoUrl;
      try {
        final userId = SupabaseConfig.currentUser?.id ?? 'unknown';
        final fileName = 'closure_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final storagePath = '$userId/$fileName';
        final bytes = await photoFile.readAsBytes();
        photoUrl = await SupabaseConfig.uploadFile(
          SupabaseConfig.visitPhotosBucket,
          storagePath,
          bytes,
        );
      } catch (e) {
        photoUrl = 'local:${photoFile.path}';
      }

      await ref
          .read(routeExecutionProvider.notifier)
          .markClientPermanentlyClosed(
            clientCoCli: routeClient.clientId,
            reason: reasonController.text.trim(),
          );
      // Also mark as closed temp in the current route
      await ref
          .read(routeExecutionProvider.notifier)
          .markCurrentClientClosedTemp(
            reason: 'Cerrado permanentemente: ${reasonController.text.trim()}',
            photoUrl: photoUrl,
          );
    }
    reasonController.dispose();
  }

  Future<void> _cancelRoute() async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar Ruta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                '¿Estás seguro de que deseas cancelar esta ruta?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Motivo de cancelación *',
                hintText: 'Ingresa el motivo...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Volver'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('El motivo es obligatorio')),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cancelar Ruta'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(routeExecutionProvider.notifier).cancelRoute(
            reason: reasonController.text,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ruta cancelada'),
            backgroundColor: Colors.red,
          ),
        );
        context.pop();
      }
    }
    reasonController.dispose();
  }

  Future<void> _addClientsToRoute(AppRoute route) async {
    // Cargar clientes disponibles
    final List<Client> allClients;
    try {
      allClients = await ref.read(clientsProvider.future);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudieron cargar los clientes')),
      );
      return;
    }
    if (allClients.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudieron cargar los clientes')),
      );
      return;
    }

    // Filtrar: excluir los que ya están en la ruta + cerrados permanentemente + inactivos
    final existingIds = route.clients?.map((c) => c.clientId).toSet() ?? {};
    final availableClients = allClients.where((c) {
      if (existingIds.contains(c.coCli)) return false;
      if (c.permanentlyClosed == true) return false;
      if (c.inactivo == true) return false;
      return true;
    }).toList();

    if (availableClients.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay clientes disponibles para agregar')),
      );
      return;
    }

    // Abrir selector de clientes
    if (!mounted) return;
    final selectedIds = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => ClientSelectorSheet(
        availableClients: availableClients,
        selectedClientIds: const [],
      ),
    );

    if (selectedIds == null || selectedIds.isEmpty) return;

    // Agregar clientes
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Agregando ${selectedIds.length} cliente(s)...')),
    );

    final success = await ref
        .read(routeExecutionProvider.notifier)
        .addClientsToRoute(selectedIds);

    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${selectedIds.length} cliente(s) agregado(s)'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al agregar clientes. Verifica tu conexión.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _convertToTemplate(AppRoute route) async {
    final nameController =
        TextEditingController(text: 'Plantilla - ${route.name}');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Convertir a Plantilla'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Esta ruta se guardará como plantilla para crear rutas futuras.'),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre de la plantilla',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Guardar Plantilla'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final currentUser = ref.read(currentUserProvider).valueOrNull;
        if (currentUser == null) throw Exception('Usuario no autenticado');

        final template = RouteTemplate(
          id: '',
          name: nameController.text,
          description: 'Basada en la ruta: ${route.name}',
          routeTypeId: route.routeTypeId,
          sedeApp: route.sedeApp,
          createdBy: currentUser.id,
          isActive: true,
        );

        final routeRepository = RouteRepository();
        final savedTemplate = await routeRepository.createTemplate(template);

        if (route.clients != null && route.clients!.isNotEmpty) {
          final clientIds = route.clients!.map((c) => c.clientId).toList();
          await routeRepository.addClientsToTemplate(
            templateId: savedTemplate.id,
            clientIds: clientIds,
          );
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Plantilla "${nameController.text}" guardada exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al guardar plantilla: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    nameController.dispose();
  }

  Future<void> _completeRoute() async {
    final state = ref.read(routeExecutionProvider);
    final pendingClients = state.route?.clients
            ?.where((c) => c.isPending || c.isInProgress)
            .length ??
        0;

    if (pendingClients > 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Finalizar Ruta'),
          content: Text(
            'Tienes $pendingClients cliente(s) sin completar. ¿Deseas finalizar la ruta de todos modos?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Finalizar'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    }

    try {
      await ref.read(routeExecutionProvider.notifier).completeRoute();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ruta finalizada exitosamente'),
          backgroundColor: Colors.green,
        ),
      );

      context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al finalizar ruta: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _syncPendingVisits() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sincronizando visitas...')),
    );

    await ref.read(routeExecutionProvider.notifier).syncPendingVisits();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Visitas sincronizadas'),
        backgroundColor: Colors.green,
      ),
    );
  }
}
