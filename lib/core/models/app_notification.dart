/// Modelo de notificación in-app
class AppNotification {
  final String id;
  final String userId;
  final String title;
  final String body;
  final String type; // route_assigned, event_assigned, route_completed, reminder
  final Map<String, dynamic> data;
  final bool read;
  final bool sent;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    this.data = const {},
    this.read = false,
    this.sent = false,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      type: json['type'] as String,
      data: json['data'] is Map<String, dynamic>
          ? json['data'] as Map<String, dynamic>
          : {},
      read: json['read'] as bool? ?? false,
      sent: json['sent'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'user_id': userId,
      'title': title,
      'body': body,
      'type': type,
      'data': data,
    };
  }

  AppNotification copyWith({bool? read}) {
    return AppNotification(
      id: id,
      userId: userId,
      title: title,
      body: body,
      type: type,
      data: data,
      read: read ?? this.read,
      sent: sent,
      createdAt: createdAt,
    );
  }

  /// Tiempo relativo desde la creación
  String get timeAgo {
    final now = DateTime.now();
    final diff = now.difference(createdAt);

    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours}h';
    if (diff.inDays == 1) return 'Ayer';
    if (diff.inDays < 7) return 'Hace ${diff.inDays} días';
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }
}
