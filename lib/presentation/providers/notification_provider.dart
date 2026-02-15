import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/app_notification.dart';
import '../../data/repositories/notification_repository.dart';

/// Provider del repositorio
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository();
});

/// Provider de lista de notificaciones
final notificationsProvider = FutureProvider<List<AppNotification>>((ref) async {
  final repo = ref.watch(notificationRepositoryProvider);
  return repo.getNotifications();
});

/// Provider de conteo de no leídas (para badge)
final unreadNotificationCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(notificationRepositoryProvider);
  return repo.getUnreadCount();
});

/// Provider para marcar como leída
final markAsReadProvider = Provider<Future<void> Function(String)>((ref) {
  final repo = ref.watch(notificationRepositoryProvider);
  return (String notificationId) async {
    await repo.markAsRead(notificationId);
    ref.invalidate(notificationsProvider);
    ref.invalidate(unreadNotificationCountProvider);
  };
});

/// Provider para marcar todas como leídas
final markAllAsReadProvider = Provider<Future<void> Function()>((ref) {
  final repo = ref.watch(notificationRepositoryProvider);
  return () async {
    await repo.markAllAsRead();
    ref.invalidate(notificationsProvider);
    ref.invalidate(unreadNotificationCountProvider);
  };
});
