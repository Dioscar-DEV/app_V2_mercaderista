import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../config/supabase_config.dart';
import '../../../core/models/user.dart';
import '../../providers/auth_provider.dart';

/// Provider de métricas del usuario (varía por rol)
final userMetricsProvider = FutureProvider.family<Map<String, dynamic>, AppUser>((ref, user) async {
  final sb = SupabaseConfig.client;

  try {
    if (user.role.isMercaderista) {
      // === MÉTRICAS MERCADERISTA ===
      final routesTotal = (await sb.from('routes').select('id').eq('mercaderista_id', user.id) as List).length;
      final routesCompleted = (await sb.from('routes').select('id').eq('mercaderista_id', user.id).eq('status', 'completed') as List).length;
      final visitsTotal = (await sb.from('route_visits').select('id').eq('mercaderista_id', user.id) as List).length;
      final now = DateTime.now();
      final firstOfMonth = DateTime(now.year, now.month, 1);
      final visitsThisMonth = (await sb.from('route_visits').select('id').eq('mercaderista_id', user.id).gte('visited_at', firstOfMonth.toIso8601String()) as List).length;

      return {
        'type': 'mercaderista',
        'routesTotal': routesTotal,
        'routesCompleted': routesCompleted,
        'visitsTotal': visitsTotal,
        'visitsThisMonth': visitsThisMonth,
      };
    } else {
      // === MÉTRICAS SUPERVISOR / OWNER ===
      final now = DateTime.now();
      final firstOfMonth = DateTime(now.year, now.month, 1);

      // Filtrar por sede si es supervisor
      var routesQuery = sb.from('routes').select('id');
      var clientsQuery = sb.from('clients').select('co_cli').eq('inactivo', false);

      if (user.role.isSupervisor && user.sede != null) {
        clientsQuery = clientsQuery.eq('sede_app', user.sede!.value);
      }

      if (user.role.isSupervisor && user.sede != null) {
        routesQuery = routesQuery.eq('sede_app', user.sede!.value);
      }
      final allRoutesData = await routesQuery as List;
      final routesCompleted = allRoutesData.where((r) => true).length; // total filtered routes

      // Ahora filtrar completadas
      var routesCompletedQuery = sb.from('routes').select('id').eq('status', 'completed');
      if (user.role.isSupervisor && user.sede != null) {
        routesCompletedQuery = routesCompletedQuery.eq('sede_app', user.sede!.value);
      }
      final routesCompletedFinal = (await routesCompletedQuery as List).length;

      // Clientes activos de la sede
      final totalClients = (await clientsQuery as List).length;

      // Visitas este mes (de toda la sede)
      var visitsMonthQuery = sb.from('route_visits').select('id, routes!inner(sede_app)').gte('visited_at', firstOfMonth.toIso8601String());
      if (user.role.isSupervisor && user.sede != null) {
        visitsMonthQuery = visitsMonthQuery.eq('routes.sede_app', user.sede!.value);
      }
      List visitsThisMonthData;
      try {
        visitsThisMonthData = await visitsMonthQuery as List;
      } catch (_) {
        // Fallback sin join
        visitsThisMonthData = await sb.from('route_visits').select('id').gte('visited_at', firstOfMonth.toIso8601String()) as List;
      }
      final visitsThisMonth = visitsThisMonthData.length;

      // Clientes únicos visitados este mes
      List clientsVisitedData;
      try {
        var cvQuery = sb.from('route_visits').select('client_co_cli').gte('visited_at', firstOfMonth.toIso8601String());
        clientsVisitedData = await cvQuery as List;
      } catch (_) {
        clientsVisitedData = [];
      }
      final clientsVisited = clientsVisitedData.map((e) => e['client_co_cli']).toSet().length;

      return {
        'type': 'admin',
        'totalClients': totalClients,
        'clientsVisited': clientsVisited,
        'routesCompleted': routesCompletedFinal,
        'visitsThisMonth': visitsThisMonth,
      };
    }
  } catch (e) {
    return {
      'type': user.role.isMercaderista ? 'mercaderista' : 'admin',
      'routesTotal': 0,
      'routesCompleted': 0,
      'visitsTotal': 0,
      'visitsThisMonth': 0,
      'totalClients': 0,
      'clientsVisited': 0,
    };
  }
});

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isUploading = false;

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () => _handleLogout(context),
          ),
        ],
      ),
      body: userAsync.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('No se pudo cargar el perfil'));
          }
          return _buildProfile(context, user, theme);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildProfile(BuildContext context, AppUser user, ThemeData theme) {
    final metrics = ref.watch(userMetricsProvider(user));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Avatar y nombre
          _buildAvatarSection(context, user, theme),
          const SizedBox(height: 24),

          // Info personal
          _buildInfoCard(context, user, theme),
          const SizedBox(height: 16),

          // Métricas
          metrics.when(
            data: (data) => _buildMetricsCard(context, data, user, theme),
            loading: () => const Card(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),

          // Cuenta
          _buildAccountCard(context, user, theme),
        ],
      ),
    );
  }

  Widget _buildAvatarSection(BuildContext context, AppUser user, ThemeData theme) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            CircleAvatar(
              radius: 56,
              backgroundColor: theme.colorScheme.primaryContainer,
              backgroundImage: user.avatarUrl != null && user.avatarUrl!.startsWith('http')
                  ? NetworkImage(user.avatarUrl!)
                  : null,
              child: user.avatarUrl == null || !user.avatarUrl!.startsWith('http')
                  ? Text(
                      user.initials,
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    )
                  : null,
            ),
            Material(
              elevation: 2,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: _isUploading ? null : () => _pickAndUploadAvatar(user),
                customBorder: const CircleBorder(),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: theme.colorScheme.primary,
                  child: _isUploading
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          user.fullName,
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: _roleColor(user.role.displayName).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            user.role.displayName,
            style: TextStyle(
              color: _roleColor(user.role.displayName),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(BuildContext context, AppUser user, ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Información Personal',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(),
            _infoRow(Icons.email, 'Email', user.email),
            if (user.phone != null && user.phone!.isNotEmpty)
              _infoRow(Icons.phone, 'Teléfono', user.phone!),
            _infoRow(Icons.business, 'Sede', user.sede?.displayName ?? 'No asignada'),
            _infoRow(Icons.shield, 'Estado',
                user.status.displayName,
                valueColor: user.status.name == 'active' ? Colors.green : Colors.orange),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsCard(BuildContext context, Map<String, dynamic> data, AppUser user, ThemeData theme) {
    final isAdmin = data['type'] == 'admin';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(isAdmin ? 'Métricas de Gestión' : 'Mis Métricas',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(),
            if (isAdmin) ...[
              // Métricas Supervisor / Owner
              Row(
                children: [
                  Expanded(child: _metricTile('Clientes Activos', '${data['totalClients'] ?? 0}', Icons.store, Colors.blue)),
                  Expanded(child: _metricTile('Visitados (Mes)', '${data['clientsVisited'] ?? 0}', Icons.person_pin_circle, Colors.purple)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _metricTile('Rutas Completadas', '${data['routesCompleted'] ?? 0}', Icons.check_circle, Colors.green)),
                  Expanded(child: _metricTile('Visitas (Mes)', '${data['visitsThisMonth'] ?? 0}', Icons.calendar_month, Colors.teal)),
                ],
              ),
              if ((data['totalClients'] as int? ?? 0) > 0 && (data['clientsVisited'] as int? ?? 0) > 0) ...[
                const SizedBox(height: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cobertura de clientes',
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.outline)),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: ((data['clientsVisited'] as int) / (data['totalClients'] as int)).clamp(0.0, 1.0),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                      backgroundColor: Colors.purple.withValues(alpha: 0.15),
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.purple),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${((data['clientsVisited'] as int) / (data['totalClients'] as int) * 100).clamp(0, 100).toStringAsFixed(1)}%',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purple),
                    ),
                  ],
                ),
              ],
            ] else ...[
              // Métricas Mercaderista
              Row(
                children: [
                  Expanded(child: _metricTile('Rutas Asignadas', '${data['routesTotal'] ?? 0}', Icons.route, Colors.blue)),
                  Expanded(child: _metricTile('Completadas', '${data['routesCompleted'] ?? 0}', Icons.check_circle, Colors.green)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _metricTile('Visitas Total', '${data['visitsTotal'] ?? 0}', Icons.store, Colors.purple)),
                  Expanded(child: _metricTile('Este Mes', '${data['visitsThisMonth'] ?? 0}', Icons.calendar_month, Colors.teal)),
                ],
              ),
              if ((data['routesTotal'] as int? ?? 0) > 0) ...[
                const SizedBox(height: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tasa de completado',
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.outline)),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: (data['routesCompleted'] as int) / (data['routesTotal'] as int),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                      backgroundColor: Colors.green.withValues(alpha: 0.15),
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${((data['routesCompleted'] as int) / (data['routesTotal'] as int) * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAccountCard(BuildContext context, AppUser user, ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Cuenta',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(),
            _infoRow(Icons.calendar_today, 'Miembro desde',
                '${user.createdAt.day.toString().padLeft(2, '0')}/${user.createdAt.month.toString().padLeft(2, '0')}/${user.createdAt.year}'),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _handleLogout(context),
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text('Cerrar Sesión', style: TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(fontWeight: FontWeight.w500, color: valueColor, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _metricTile(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.8)), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Color _roleColor(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return Colors.deepPurple;
      case 'supervisor':
        return Colors.orange;
      case 'mercaderista':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Future<void> _pickAndUploadAvatar(AppUser user) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 400, maxHeight: 400, imageQuality: 80);
      if (picked == null) return;

      setState(() => _isUploading = true);

      final bytes = await picked.readAsBytes();
      final fileName = '${user.id}/avatar.jpg';

      final url = await SupabaseConfig.uploadFileWithRetry(
        SupabaseConfig.userAvatarsBucket,
        fileName,
        bytes,
      );

      // Actualizar en tabla users
      await SupabaseConfig.client
          .from('users')
          .update({'avatar_url': url, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', user.id);

      ref.invalidate(currentUserProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto de perfil actualizada'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir foto: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(authControllerProvider.notifier).signOut();
    }
  }
}
