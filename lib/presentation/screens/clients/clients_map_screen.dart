import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/models/client.dart';
import '../../providers/auth_provider.dart';
import '../../providers/client_provider.dart';

/// Pantalla de mapa con todos los clientes que tienen coordenadas
class ClientsMapScreen extends ConsumerStatefulWidget {
  const ClientsMapScreen({super.key});

  @override
  ConsumerState<ClientsMapScreen> createState() => _ClientsMapScreenState();
}

class _ClientsMapScreenState extends ConsumerState<ClientsMapScreen> {
  GoogleMapController? _mapController;
  String _filter = 'all'; // all, with_gps, without_gps

  // Centro por defecto: Venezuela
  static const LatLng _defaultCenter = LatLng(10.4806, -66.9036);

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(clientsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa de Clientes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(clientsProvider),
          ),
        ],
      ),
      body: clientsAsync.when(
        data: (clients) => _buildMapView(context, clients),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildMapView(BuildContext context, List<Client> allClients) {
    final clientsWithGps = allClients.where((c) => c.hasGPS).toList();
    final clientsWithoutGps = allClients.where((c) => !c.hasGPS).toList();
    final totalActive = allClients.where((c) => c.isActive).length;
    final withGpsActive =
        clientsWithGps.where((c) => c.isActive).length;
    final percentage =
        totalActive > 0 ? (withGpsActive / totalActive * 100) : 0.0;

    // Crear markers
    final markers = <Marker>{};
    for (final client in clientsWithGps) {
      final isActive = client.isActive;
      final hasRecentVisit = client.diasDesdeUltimaVisita != null &&
          client.diasDesdeUltimaVisita! <= 7;

      // Color: verde = visitado recientemente, naranja = activo sin visita reciente, rojo = inactivo
      final hue = !isActive
          ? BitmapDescriptor.hueRed
          : hasRecentVisit
              ? BitmapDescriptor.hueGreen
              : BitmapDescriptor.hueOrange;

      markers.add(
        Marker(
          markerId: MarkerId(client.coCli),
          position: LatLng(client.latitude!, client.longitude!),
          icon: BitmapDescriptor.defaultMarkerWithHue(hue),
          infoWindow: InfoWindow(
            title: client.cliDes,
            snippet: _buildSnippet(client),
            onTap: () => context.push('/admin/clients/${client.coCli}'),
          ),
        ),
      );
    }

    // Calcular bounds para centrar el mapa
    LatLng center = _defaultCenter;
    double zoom = 8;
    if (clientsWithGps.isNotEmpty) {
      double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
      for (final c in clientsWithGps) {
        if (c.latitude! < minLat) minLat = c.latitude!;
        if (c.latitude! > maxLat) maxLat = c.latitude!;
        if (c.longitude! < minLng) minLng = c.longitude!;
        if (c.longitude! > maxLng) maxLng = c.longitude!;
      }
      center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
      if (clientsWithGps.length == 1) {
        zoom = 15;
      }
    }

    return Column(
      children: [
        // Stats bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Row(
            children: [
              _buildStatChip(
                Icons.location_on,
                Colors.green,
                '$withGpsActive',
                'Con GPS',
              ),
              const SizedBox(width: 8),
              _buildStatChip(
                Icons.location_off,
                Colors.red,
                '${clientsWithoutGps.where((c) => c.isActive).length}',
                'Sin GPS',
              ),
              const SizedBox(width: 8),
              _buildStatChip(
                Icons.percent,
                Colors.blue,
                '${percentage.toStringAsFixed(1)}%',
                'Cobertura',
              ),
              const Spacer(),
              // Botón para ver lista sin GPS
              TextButton.icon(
                onPressed: () => _showClientsWithoutGps(
                    context, clientsWithoutGps.where((c) => c.isActive).toList()),
                icon: const Icon(Icons.list, size: 18),
                label: const Text('Sin GPS', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
          ),
        ),

        // Leyenda
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              _buildLegendItem(Colors.green, 'Visitado (-7d)'),
              const SizedBox(width: 12),
              _buildLegendItem(Colors.orange, 'Sin visita reciente'),
              const SizedBox(width: 12),
              _buildLegendItem(Colors.red, 'Inactivo'),
            ],
          ),
        ),

        // Mapa
        Expanded(
          child: GoogleMap(
            initialCameraPosition: CameraPosition(
              target: center,
              zoom: zoom,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              // Si hay múltiples markers, ajustar bounds
              if (clientsWithGps.length > 1) {
                double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
                for (final c in clientsWithGps) {
                  if (c.latitude! < minLat) minLat = c.latitude!;
                  if (c.latitude! > maxLat) maxLat = c.latitude!;
                  if (c.longitude! < minLng) minLng = c.longitude!;
                  if (c.longitude! > maxLng) maxLng = c.longitude!;
                }
                controller.animateCamera(
                  CameraUpdate.newLatLngBounds(
                    LatLngBounds(
                      southwest: LatLng(minLat - 0.01, minLng - 0.01),
                      northeast: LatLng(maxLat + 0.01, maxLng + 0.01),
                    ),
                    50,
                  ),
                );
              }
            },
            markers: markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            mapToolbarEnabled: true,
          ),
        ),
      ],
    );
  }

  String _buildSnippet(Client client) {
    final parts = <String>[];
    if (client.ciudad != null) parts.add(client.ciudad!);
    if (client.diasDesdeUltimaVisita != null) {
      parts.add('Última visita: ${client.diasDesdeUltimaVisita}d');
    } else {
      parts.add('Sin visitas');
    }
    return parts.join(' | ');
  }

  Widget _buildStatChip(
      IconData icon, Color color, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 13, color: color),
          ),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }

  void _showClientsWithoutGps(BuildContext context, List<Client> clients) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
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
                      const Icon(Icons.location_off, color: Colors.red),
                      const SizedBox(width: 8),
                      Text(
                        'Clientes sin GPS (${clients.length})',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    controller: controller,
                    itemCount: clients.length,
                    itemBuilder: (_, i) {
                      final c = clients[i];
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.red.withValues(alpha: 0.1),
                          child: const Icon(Icons.store,
                              size: 16, color: Colors.red),
                        ),
                        title: Text(c.cliDes,
                            style: const TextStyle(fontSize: 13)),
                        subtitle: Text(
                          '${c.coCli} | ${c.ciudad ?? 'Sin ciudad'}',
                          style:
                              TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 18),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          context.push('/admin/clients/${c.coCli}');
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
  }
}
