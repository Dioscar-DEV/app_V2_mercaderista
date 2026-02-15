import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../core/models/route.dart';
import '../../../core/models/event.dart';
import '../../../core/enums/route_status.dart';
import '../../../config/theme_config.dart';
import '../../providers/auth_provider.dart';
import '../../providers/route_provider.dart';
import '../../providers/event_provider.dart';

/// Pantalla principal del mercaderista
class MercaderistaHomeScreen extends ConsumerStatefulWidget {
  const MercaderistaHomeScreen({super.key});

  @override
  ConsumerState<MercaderistaHomeScreen> createState() => _MercaderistaHomeScreenState();
}

class _MercaderistaHomeScreenState extends ConsumerState<MercaderistaHomeScreen> {
  int _retryCount = 0;
  static const int _maxRetries = 3;
  bool _isOffline = false;
  bool _hasAutoDownloaded = false;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _autoDownloadRoutesOnInit();
    Connectivity().onConnectivityChanged.listen((result) {
      final hasConnection = result == ConnectivityResult.wifi ||
          result == ConnectivityResult.mobile ||
          result == ConnectivityResult.ethernet;
      if (mounted && _isOffline != !hasConnection) {
        setState(() => _isOffline = !hasConnection);
      }
    });
  }

  /// Descarga automática de rutas al iniciar (silencioso)
  Future<void> _autoDownloadRoutesOnInit() async {
    if (_hasAutoDownloaded) return;
    _hasAutoDownloaded = true;
    
    // Esperar a que el usuario se cargue
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (!mounted) return;
    
    try {
      final user = await ref.read(currentUserProvider.future);
      if (user != null) {
        // Forzar descarga silenciosa
        await ref.read(offlineFirstRouteRepositoryProvider).getRoutesForToday(
          user: user,
          forceRefresh: true,
        );
      }
    } catch (_) {
      // Silencioso - no importa si falla
    }
  }

  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    final hasConnection = result == ConnectivityResult.wifi ||
        result == ConnectivityResult.mobile ||
        result == ConnectivityResult.ethernet;
    if (mounted) {
      setState(() => _isOffline = !hasConnection);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final todayRoutesAsync = ref.watch(todayRoutesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Mi Ruta'),
            if (_isOffline) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_off, size: 14, color: Colors.white),
                    SizedBox(width: 4),
                    Text('Offline', style: TextStyle(fontSize: 12, color: Colors.white)),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notificaciones próximamente')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () {
              // TODO: Navegar a perfil
            },
          ),
        ],
      ),
      body: userAsync.when(
        data: (user) {
          if (user == null) {
            // Reintentar cargar el usuario automáticamente
            if (_retryCount < _maxRetries) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _retryCount++;
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (mounted) {
                    ref.invalidate(currentUserProvider);
                  }
                });
              });
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Cargando perfil...'),
                  ],
                ),
              );
            }
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.orange),
                  const SizedBox(height: 16),
                  const Text('No se pudo cargar el usuario'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _retryCount = 0;
                      });
                      ref.invalidate(currentUserProvider);
                    },
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }

          // Reset retry count on success
          if (_retryCount > 0) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _retryCount = 0;
                });
              }
            });
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(todayRoutesProvider);
              ref.invalidate(yesterdayPendingRoutesProvider);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tarjeta de bienvenida
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '¡Hola, ${user.fullName.split(' ').first}!',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Sede: ${user.sede ?? 'N/A'} • Región: ${user.region ?? 'N/A'}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Ruta del día
                  Text(
                    'Ruta del Día',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Cargar rutas de hoy
                  todayRoutesAsync.when(
                    data: (routes) {
                      if (routes.isEmpty) {
                        return _buildNoRoutesCard(context);
                      }
                      return Column(
                        children: routes.map((route) => _buildRouteCard(context, ref, route)).toList(),
                      );
                    },
                    loading: () => const Card(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                    error: (error, _) {
                      // Modo silencioso: mostrar card vacía sin error intrusivo
                      // Los datos locales se cargarán automáticamente
                      return _buildOfflineCard(context);
                    },
                  ),
                  
                  const SizedBox(height: 20),

                  // Eventos del día
                  _buildEventsSection(context, ref),

                  const SizedBox(height: 20),

                  // Pendientes de ayer
                  _buildYesterdayPendingSection(context, ref),

                  const SizedBox(height: 20),

                  // Accesos rápidos
                  Text(
                    'Accesos Rápidos',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.5,
                    children: [
                      _QuickAccessCard(
                        icon: Icons.history,
                        title: 'Historial',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Historial próximamente')),
                          );
                        },
                      ),
                      _QuickAccessCard(
                        icon: Icons.download_for_offline,
                        title: 'Descargar\nOffline',
                        onTap: () => _downloadForOffline(context, ref),
                      ),
                      _QuickAccessCard(
                        icon: Icons.settings,
                        title: 'Configuración',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Configuración próximamente')),
                          );
                        },
                      ),
                      _QuickAccessCard(
                        icon: Icons.logout,
                        title: 'Cerrar Sesión',
                        onTap: () => _handleLogout(context, ref),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error: $error'),
        ),
      ),
    );
  }

  Widget _buildNoRoutesCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Icon(
              Icons.calendar_today,
              size: 48,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              'No tienes rutas asignadas para hoy',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Contacta a tu administrador para que te asigne una ruta',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(
              Icons.cloud_off,
              size: 48,
              color: Colors.orange[400],
            ),
            const SizedBox(height: 16),
            const Text(
              'Modo Offline',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Trabajando con datos locales. La sincronización se realizará automáticamente cuando vuelva la conexión.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => ref.invalidate(todayRoutesProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('Intentar conectar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteCard(BuildContext context, WidgetRef ref, AppRoute route) {
    final clients = route.clients ?? [];
    final totalClients = clients.isNotEmpty ? clients.length : route.totalClients;
    final completed = clients.where((c) => c.isCompleted).length;
    final pending = clients.where((c) => c.isPending || c.isInProgress).length;
    final closed = clients.where((c) => c.isClosedTemp).length;
    final skipped = clients.where((c) => c.isSkipped).length;
    final done = completed + closed + skipped;
    final progress = totalClients > 0 ? done / totalClients : 0.0;

    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (route.status) {
      case RouteStatus.planned:
        statusColor = Colors.blue;
        statusText = 'Planificada';
        statusIcon = Icons.schedule;
        break;
      case RouteStatus.inProgress:
        statusColor = Colors.orange;
        statusText = 'En Progreso';
        statusIcon = Icons.play_arrow;
        break;
      case RouteStatus.completed:
        statusColor = Colors.green;
        statusText = 'Completada';
        statusIcon = Icons.check_circle;
        break;
      case RouteStatus.cancelled:
        statusColor = Colors.red;
        statusText = 'Cancelada';
        statusIcon = Icons.cancel;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: route.status != RouteStatus.cancelled
            ? () => context.push('/mercaderista/route/${route.id}')
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      route.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 16, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (route.routeType != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: ThemeConfig.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    route.routeType!.name,
                    style: const TextStyle(
                      fontSize: 12,
                      color: ThemeConfig.primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

              // Status breakdown
              if (route.status == RouteStatus.cancelled) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Ruta cancelada',
                        style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.w500),
                      ),
                      if (route.cancellationReason != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          route.cancellationReason!,
                          style: TextStyle(color: Colors.red[400], fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ] else ...[
                // Client status breakdown row
                Row(
                  children: [
                    _buildStatusBadge(Icons.check_circle, Colors.green, completed, 'Visitados'),
                    const SizedBox(width: 12),
                    _buildStatusBadge(Icons.schedule, Colors.grey, pending, 'Pendientes'),
                    if (closed > 0) ...[
                      const SizedBox(width: 12),
                      _buildStatusBadge(Icons.store_mall_directory, Colors.red, closed, 'Cerrados'),
                    ],
                    if (skipped > 0) ...[
                      const SizedBox(width: 12),
                      _buildStatusBadge(Icons.skip_next, Colors.orange, skipped, 'Omitidos'),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
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
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      context.push('/mercaderista/route/${route.id}');
                    },
                    icon: Icon(
                      route.status == RouteStatus.planned
                          ? Icons.play_arrow
                          : Icons.visibility,
                    ),
                    label: Text(
                      route.status == RouteStatus.planned
                          ? 'Iniciar Ruta'
                          : 'Ver Ruta',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ThemeConfig.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(IconData icon, Color color, int count, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: color),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventsSection(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(mercaderistaEventsProvider);

    return eventsAsync.when(
      data: (events) {
        if (events.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Eventos del Día',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            ...events.map((event) => _buildEventCard(context, event)),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildEventCard(BuildContext context, AppEvent event) {
    final currentDay = event.currentDay;
    final checkInAsync = ref.watch(eventTodayCheckInProvider(event.id));
    final hasCheckedIn = checkInAsync.valueOrNull ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => context.push('/mercaderista/event/${event.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: hasCheckedIn
                          ? Colors.green.withValues(alpha: 0.15)
                          : Colors.teal.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      hasCheckedIn ? Icons.check_circle : Icons.event,
                      color: hasCheckedIn ? Colors.green : Colors.teal,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (event.locationName != null)
                          Text(
                            event.locationName!,
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 13),
                          ),
                      ],
                    ),
                  ),
                  if (currentDay != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Día $currentDay/${event.totalDays}',
                        style: const TextStyle(
                          color: Colors.teal,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (hasCheckedIn)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 18),
                      SizedBox(width: 6),
                      Text(
                        'Check-in completado hoy',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        context.push('/mercaderista/event/${event.id}'),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Hacer Check-in'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildYesterdayPendingSection(BuildContext context, WidgetRef ref) {
    final yesterdayAsync = ref.watch(yesterdayPendingRoutesProvider);

    return yesterdayAsync.when(
      data: (routes) {
        if (routes.isEmpty) return const SizedBox.shrink();

        // Count total pending clients across all yesterday routes
        int totalPending = 0;
        for (final route in routes) {
          totalPending += route.clients
                  ?.where((c) => c.isPending || c.isInProgress)
                  .length ??
              0;
        }

        if (totalPending == 0) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber, size: 20, color: Colors.orange[700]),
                const SizedBox(width: 6),
                Text(
                  'Pendientes de Ayer',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Card(
              color: Colors.orange[50],
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$totalPending cliente(s) no visitados ayer',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.orange[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...routes.map((route) {
                      final pendingClients = route.clients
                              ?.where(
                                  (c) => c.isPending || c.isInProgress)
                              .toList() ??
                          [];
                      if (pendingClients.isEmpty) {
                        return const SizedBox.shrink();
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              route.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.orange[900],
                              ),
                            ),
                            const SizedBox(height: 4),
                            ...pendingClients.map((rc) => Padding(
                                  padding: const EdgeInsets.only(
                                      left: 8, bottom: 2),
                                  child: Row(
                                    children: [
                                      Icon(Icons.store,
                                          size: 14,
                                          color: Colors.orange[400]),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          rc.client?.cliDes ??
                                              rc.clientId,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.orange[700],
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Future<void> _downloadForOffline(BuildContext context, WidgetRef ref) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 16),
            Text('Descargando rutas para modo offline...'),
          ],
        ),
        duration: Duration(seconds: 2),
      ),
    );
    
    try {
      // Forzar refresh desde el servidor
      final offlineRepo = ref.read(offlineFirstRouteRepositoryProvider);
      final user = await ref.read(currentUserProvider.future);
      
      if (user != null) {
        await offlineRepo.getRoutesForToday(user: user, forceRefresh: true);
      }
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rutas descargadas correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo descargar. Verifica tu conexión.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final authController = ref.read(authControllerProvider.notifier);
      await authController.signOut();
      ref.invalidate(currentUserProvider);
      ref.invalidate(authStateProvider);
      if (context.mounted) {
        context.go('/login');
      }
    }
  }
}

class _QuickAccessCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _QuickAccessCard({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 32,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
