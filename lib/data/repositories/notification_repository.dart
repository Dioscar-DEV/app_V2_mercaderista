import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/models/app_notification.dart';

/// Repositorio de notificaciones (Supabase)
class NotificationRepository {
  final SupabaseClient _client;

  NotificationRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Obtiene notificaciones del usuario actual
  Future<List<AppNotification>> getNotifications({int limit = 50}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _client
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);

    return (response as List)
        .map((json) => AppNotification.fromJson(json))
        .toList();
  }

  /// Obtiene conteo de notificaciones no leídas
  Future<int> getUnreadCount() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return 0;

    final response = await _client
        .from('notifications')
        .select('id')
        .eq('user_id', userId)
        .eq('read', false);

    return (response as List).length;
  }

  /// Marca una notificación como leída
  Future<void> markAsRead(String notificationId) async {
    await _client
        .from('notifications')
        .update({'read': true})
        .eq('id', notificationId);
  }

  /// Marca todas las notificaciones como leídas
  Future<void> markAllAsRead() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    await _client
        .from('notifications')
        .update({'read': true})
        .eq('user_id', userId)
        .eq('read', false);
  }

  /// Crea una notificación (dispara email via Edge Function webhook)
  Future<void> createNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    await _client.from('notifications').insert({
      'user_id': userId,
      'title': title,
      'body': body,
      'type': type,
      'data': data ?? {},
    });
  }
}
