import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/app_notification.dart';
import '../../providers/notification_provider.dart';

/// Drawer lateral de notificaciones
class NotificationsDrawer extends ConsumerWidget {
  const NotificationsDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.85,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              child: Row(
                children: [
                  const Icon(Icons.notifications, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Notificaciones',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Botón marcar todas como leídas
                  notificationsAsync.when(
                    data: (notifications) {
                      final hasUnread = notifications.any((n) => !n.read);
                      if (!hasUnread) return const SizedBox.shrink();
                      return IconButton(
                        icon: const Icon(Icons.done_all, color: Colors.white),
                        tooltip: 'Marcar todas como leídas',
                        onPressed: () async {
                          final markAll = ref.read(markAllAsReadProvider);
                          await markAll();
                        },
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),

            // Lista de notificaciones
            Expanded(
              child: notificationsAsync.when(
                data: (notifications) {
                  if (notifications.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications_none,
                            size: 64,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No tienes notificaciones',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(notificationsProvider);
                      ref.invalidate(unreadNotificationCountProvider);
                    },
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: notifications.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final notification = notifications[index];
                        return _NotificationTile(
                          notification: notification,
                          onTap: () => _handleNotificationTap(
                            context,
                            ref,
                            notification,
                          ),
                        );
                      },
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error: $error', textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref.invalidate(notificationsProvider),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleNotificationTap(
    BuildContext context,
    WidgetRef ref,
    AppNotification notification,
  ) async {
    // Marcar como leída
    if (!notification.read) {
      final markRead = ref.read(markAsReadProvider);
      await markRead(notification.id);
    }

    // Cerrar drawer
    if (context.mounted) {
      Navigator.of(context).pop();
    }

    // Navegar según tipo
    if (!context.mounted) return;
    final data = notification.data;

    switch (notification.type) {
      case 'route_assigned':
        final routeId = data['route_id'] as String?;
        if (routeId != null) {
          context.push('/mercaderista/route/$routeId');
        }
        break;
      case 'event_assigned':
        final eventId = data['event_id'] as String?;
        if (eventId != null) {
          context.push('/mercaderista/event/$eventId');
        }
        break;
      case 'route_completed':
        final routeId = data['route_id'] as String?;
        if (routeId != null) {
          context.push('/admin/routes/$routeId');
        }
        break;
      default:
        break;
    }
  }
}

/// Tile individual de notificación
class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.read;

    return InkWell(
      onTap: onTap,
      child: Container(
        color: isUnread ? Colors.blue.withValues(alpha: 0.05) : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icono según tipo
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _getTypeColor().withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _getTypeIcon(),
                color: _getTypeColor(),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            // Contenido
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isUnread ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (isUnread)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.body,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notification.timeAgo,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getTypeIcon() {
    switch (notification.type) {
      case 'route_assigned':
        return Icons.route;
      case 'event_assigned':
        return Icons.event;
      case 'route_completed':
        return Icons.check_circle;
      case 'reminder':
        return Icons.alarm;
      default:
        return Icons.notifications;
    }
  }

  Color _getTypeColor() {
    switch (notification.type) {
      case 'route_assigned':
        return Colors.blue;
      case 'event_assigned':
        return Colors.teal;
      case 'route_completed':
        return Colors.green;
      case 'reminder':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}
