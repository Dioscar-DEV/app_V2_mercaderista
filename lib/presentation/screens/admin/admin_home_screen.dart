import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../../core/models/user.dart';

/// Stats del dashboard admin
class AdminStats {
  final int routesToday;
  final int completedToday;
  final int activeMercaderistas;
  final int totalClients;

  const AdminStats({
    this.routesToday = 0,
    this.completedToday = 0,
    this.activeMercaderistas = 0,
    this.totalClients = 0,
  });
}

/// Provider que carga las estadísticas del dashboard
final adminStatsProvider = FutureProvider.family<AdminStats, AppUser>((ref, user) async {
  final sb = Supabase.instance.client;
  final today = DateTime.now().toIso8601String().split('T')[0];
  final filterBySede = user.role.isSupervisor && user.sede != null;
  final sede = user.sede?.value;

  debugPrint('[AdminStats] user=${user.fullName}, role=${user.role.value}, sede=$sede, today=$today, filterBySede=$filterBySede');

  try {
    // 1. Rutas hoy
    var rq = sb.from('routes').select('id').eq('scheduled_date', today);
    if (filterBySede) rq = rq.eq('sede_app', sede!);
    final List<dynamic> routesData = await rq;
    debugPrint('[AdminStats] Rutas hoy: ${routesData.length}');

    // 2. Completadas hoy
    var cq = sb.from('routes').select('id').eq('scheduled_date', today).eq('status', 'completed');
    if (filterBySede) cq = cq.eq('sede_app', sede!);
    final List<dynamic> completedData = await cq;
    debugPrint('[AdminStats] Completadas: ${completedData.length}');

    // 3. Mercaderistas activos
    var mq = sb.from('users').select('id').eq('role', 'mercaderista').eq('status', 'active');
    if (filterBySede) mq = mq.eq('sede', sede!);
    final List<dynamic> mercData = await mq;
    debugPrint('[AdminStats] Mercaderistas: ${mercData.length}');

    // 4. Total clientes (solo co_cli para minimizar data)
    var clq = sb.from('clients').select('co_cli');
    if (filterBySede) clq = clq.eq('sede_app', sede!);
    final List<dynamic> clientsData = await clq;
    debugPrint('[AdminStats] Clientes: ${clientsData.length}');

    return AdminStats(
      routesToday: routesData.length,
      completedToday: completedData.length,
      activeMercaderistas: mercData.length,
      totalClients: clientsData.length,
    );
  } catch (e, stack) {
    debugPrint('[AdminStats] ERROR: $e');
    debugPrint('[AdminStats] STACK: $stack');
    rethrow;
  }
});

/// Pantalla principal del administrador
class AdminHomeScreen extends ConsumerStatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  ConsumerState<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends ConsumerState<AdminHomeScreen> {
  int _retryCount = 0;
  static const int _maxRetries = 3;

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Administración'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // TODO: Implementar notificaciones
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
                      _retryCount = 0;
                      ref.invalidate(currentUserProvider);
                    },
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }
          // Reset retry count on success
          _retryCount = 0;

          return SingleChildScrollView(
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
                          'Rol: ${user.role.displayName}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Resumen de estadísticas
                Text(
                  'Resumen',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                _buildStatsSection(user),
                const SizedBox(height: 24),

                // Módulos de gestión
                Text(
                  'Módulos de Gestión',
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
                  childAspectRatio: 1.2,
                  children: [
                    _ModuleCard(
                      icon: Icons.route,
                      title: 'Gestión de Rutas',
                      subtitle: 'Crear y asignar rutas',
                      color: Colors.blue,
                      onTap: () {
                        context.push('/admin/routes');
                      },
                    ),
                    _ModuleCard(
                      icon: Icons.store,
                      title: 'Gestión de Clientes',
                      subtitle: 'Administrar clientes',
                      color: Colors.purple,
                      onTap: () {
                        try {
                          debugPrint('AdminHome: Navegando a /admin/clients');
                          GoRouter.of(context).push('/admin/clients');
                        } catch (e) {
                          debugPrint('Error navegando: $e');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      },
                    ),
                    _ModuleCard(
                      icon: Icons.people,
                      title: 'Gestión de Usuarios',
                      subtitle: 'Administrar usuarios',
                      color: Colors.orange,
                      onTap: () {
                        context.push('/admin/users');
                      },
                    ),
                    _ModuleCard(
                      icon: Icons.event,
                      title: 'Gestión de Eventos',
                      subtitle: 'Trade eventos',
                      color: Colors.teal,
                      onTap: () {
                        context.push('/admin/events');
                      },
                    ),
                    _ModuleCard(
                      icon: Icons.bar_chart,
                      title: 'Reportes',
                      subtitle: 'Analytics y reportes',
                      color: Colors.green,
                      onTap: () {
                        // TODO: Navegar a reportes
                      },
                    ),
                    _ModuleCard(
                      icon: Icons.logout,
                      title: 'Cerrar Sesión',
                      subtitle: 'Salir del sistema',
                      color: Colors.red,
                      onTap: () => _handleLogout(context),
                    ),
                  ],
                ),
              ],
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

  /// Maneja el cierre de sesión
  Future<void> _handleLogout(BuildContext context) async {
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
      // Invalidar providers para limpiar caché del usuario anterior
      ref.invalidate(currentUserProvider);
      ref.invalidate(authStateProvider);
      if (context.mounted) {
        context.go('/login');
      }
    }
  }

  /// Formatea números grandes: 2110 → "2.1K"
  String _formatNumber(int n) {
    if (n >= 1000) {
      final k = n / 1000;
      return k == k.truncateToDouble()
          ? '${k.toInt()}K'
          : '${k.toStringAsFixed(1)}K';
    }
    return n.toString();
  }

  Widget _buildStatsSection(AppUser user) {
    final statsAsync = ref.watch(adminStatsProvider(user));

    return statsAsync.when(
      data: (stats) => Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.route,
                  title: 'Rutas Hoy',
                  value: stats.routesToday.toString(),
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  icon: Icons.check_circle,
                  title: 'Completadas',
                  value: stats.completedToday.toString(),
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.people,
                  title: 'Mercaderistas',
                  value: stats.activeMercaderistas.toString(),
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  icon: Icons.store,
                  title: 'Clientes',
                  value: _formatNumber(stats.totalClients),
                  color: Colors.purple,
                ),
              ),
            ],
          ),
        ],
      ),
      loading: () => const SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _StatCard(icon: Icons.route, title: 'Rutas Hoy', value: '-', color: Colors.blue),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(icon: Icons.check_circle, title: 'Completadas', value: '-', color: Colors.green),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _StatCard(icon: Icons.people, title: 'Mercaderistas', value: '-', color: Colors.orange),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(icon: Icons.store, title: 'Clientes', value: '-', color: Colors.purple),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Widget de tarjeta de estadística
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget de tarjeta de módulo
class _ModuleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ModuleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 40),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
