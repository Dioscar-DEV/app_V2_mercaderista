/// Pregunta del formulario dinámico para visitas
class RouteFormQuestion {
  final String id;
  final String routeTypeId;
  final String questionText;
  final QuestionType questionType;
  final List<String>? options;
  final bool isRequired;
  final int displayOrder;
  final bool isActive;
  final DateTime? createdAt;

  // Nuevos campos para secciones y lógica condicional
  final String? section;
  final String? dependsOn;
  final String? dependsValue;
  final Map<String, dynamic>? metadata;

  const RouteFormQuestion({
    required this.id,
    required this.routeTypeId,
    required this.questionText,
    required this.questionType,
    this.options,
    this.isRequired = false,
    this.displayOrder = 0,
    this.isActive = true,
    this.createdAt,
    this.section,
    this.dependsOn,
    this.dependsValue,
    this.metadata,
  });

  factory RouteFormQuestion.fromJson(Map<String, dynamic> json) {
    return RouteFormQuestion(
      id: json['id'] as String,
      routeTypeId: json['route_type_id'] as String,
      questionText: json['question_text'] as String,
      questionType: QuestionType.fromString(json['question_type'] as String),
      options: json['options'] != null
          ? List<String>.from(json['options'] as List)
          : null,
      isRequired: json['is_required'] as bool? ?? false,
      displayOrder: json['display_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      section: json['section'] as String?,
      dependsOn: json['depends_on'] as String?,
      dependsValue: json['depends_value'] as String?,
      metadata: json['metadata'] != null && json['metadata'] is Map
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'route_type_id': routeTypeId,
      'question_text': questionText,
      'question_type': questionType.value,
      'options': options,
      'is_required': isRequired,
      'display_order': displayOrder,
      'is_active': isActive,
      'section': section,
      'depends_on': dependsOn,
      'depends_value': dependsValue,
      'metadata': metadata,
    };
  }

  // Helpers para metadata
  bool get isCameraOnly => metadata?['camera_only'] == true;
  int get maxItems => (metadata?['max_items'] as int?) ?? 10;
  int get maxPhotos => (metadata?['max_photos'] as int?) ?? 1;
  bool get hasPhoto => metadata?['has_photo'] == true;
  String? get placeholder => metadata?['placeholder'] as String?;
}

/// Tipos de pregunta soportados
enum QuestionType {
  text('text'),
  number('number'),
  boolean('boolean'),
  select('select'),
  multiselect('multiselect'),
  photo('photo'),
  rating('rating'),
  booleanPhoto('boolean_photo'),
  numberPhoto('number_photo'),
  textarea('textarea'),
  dynamicList('dynamic_list');

  final String value;
  const QuestionType(this.value);

  static QuestionType fromString(String value) {
    return QuestionType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => QuestionType.text,
    );
  }
}
