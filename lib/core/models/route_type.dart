/// Tipo de visita (Merchandising, Impulso, etc.)
class RouteType {
  final String id;
  final String name;
  final String? description;
  final String color;
  final String icon;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const RouteType({
    required this.id,
    required this.name,
    this.description,
    this.color = '#2196F3',
    this.icon = 'route',
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory RouteType.fromJson(Map<String, dynamic> json) {
    return RouteType(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      color: json['color'] as String? ?? '#2196F3',
      icon: json['icon'] as String? ?? 'route',
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : null,
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'color': color,
      'icon': icon,
      'is_active': isActive,
    };
  }
}
