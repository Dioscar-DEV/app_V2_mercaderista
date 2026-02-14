import 'route_form_question.dart';

/// Modelo para una visita completada a un cliente
/// Alineado con la tabla route_visits en Supabase:
///   id, route_client_id, route_id, client_co_cli, mercaderista_id,
///   visited_at, latitude, longitude, accuracy_meters,
///   photos (jsonb), notes, synced_at, offline_id, created_at
class RouteVisit {
  final String id;
  final String routeClientId;
  final String? routeId;
  final String? clientCoCli;
  final String? mercaderistaId;
  final DateTime visitedAt;
  final double? latitude;
  final double? longitude;
  final double? accuracyMeters;
  final List<String>? photos;
  final String? notes;
  final DateTime? syncedAt;
  final String? offlineId;
  final DateTime createdAt;

  // Respuestas al formulario dinámico
  final List<RouteVisitAnswer>? answers;

  const RouteVisit({
    required this.id,
    required this.routeClientId,
    this.routeId,
    this.clientCoCli,
    this.mercaderistaId,
    required this.visitedAt,
    this.latitude,
    this.longitude,
    this.accuracyMeters,
    this.photos,
    this.notes,
    this.syncedAt,
    this.offlineId,
    required this.createdAt,
    this.answers,
  });

  factory RouteVisit.fromJson(Map<String, dynamic> json) {
    return RouteVisit(
      id: json['id'] as String,
      routeClientId: json['route_client_id'] as String,
      routeId: json['route_id'] as String?,
      clientCoCli: json['client_co_cli'] as String?,
      mercaderistaId: json['mercaderista_id'] as String?,
      visitedAt: DateTime.parse(json['visited_at'] as String),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      accuracyMeters: (json['accuracy_meters'] as num?)?.toDouble(),
      photos: json['photos'] != null
          ? List<String>.from(json['photos'] as List)
          : null,
      notes: json['notes'] as String?,
      syncedAt: json['synced_at'] != null
          ? DateTime.parse(json['synced_at'] as String)
          : null,
      offlineId: json['offline_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      answers: json['route_visit_answers'] != null
          ? (json['route_visit_answers'] as List)
              .map((e) => RouteVisitAnswer.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'route_client_id': routeClientId,
      'route_id': routeId,
      'client_co_cli': clientCoCli,
      'mercaderista_id': mercaderistaId,
      'visited_at': visitedAt.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'accuracy_meters': accuracyMeters,
      'photos': photos ?? [],
      'notes': notes,
      'synced_at': syncedAt?.toIso8601String(),
      'offline_id': offlineId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Para insertar en Supabase (sin id ni created_at, los genera el servidor)
  Map<String, dynamic> toInsertJson() {
    return {
      'route_client_id': routeClientId,
      'route_id': routeId,
      'client_co_cli': clientCoCli,
      'mercaderista_id': mercaderistaId,
      'visited_at': visitedAt.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'accuracy_meters': accuracyMeters,
      'photos': photos ?? [],
      'notes': notes,
      'offline_id': offlineId,
    };
  }

  /// Para almacenamiento local (offline)
  Map<String, dynamic> toLocalJson() {
    final data = toJson();
    if (answers != null) {
      data['route_visit_answers'] = answers!.map((a) => a.toJson()).toList();
    }
    return data;
  }

  RouteVisit copyWith({
    String? id,
    String? routeClientId,
    String? routeId,
    String? clientCoCli,
    String? mercaderistaId,
    DateTime? visitedAt,
    double? latitude,
    double? longitude,
    double? accuracyMeters,
    List<String>? photos,
    String? notes,
    DateTime? syncedAt,
    String? offlineId,
    DateTime? createdAt,
    List<RouteVisitAnswer>? answers,
  }) {
    return RouteVisit(
      id: id ?? this.id,
      routeClientId: routeClientId ?? this.routeClientId,
      routeId: routeId ?? this.routeId,
      clientCoCli: clientCoCli ?? this.clientCoCli,
      mercaderistaId: mercaderistaId ?? this.mercaderistaId,
      visitedAt: visitedAt ?? this.visitedAt,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracyMeters: accuracyMeters ?? this.accuracyMeters,
      photos: photos ?? this.photos,
      notes: notes ?? this.notes,
      syncedAt: syncedAt ?? this.syncedAt,
      offlineId: offlineId ?? this.offlineId,
      createdAt: createdAt ?? this.createdAt,
      answers: answers ?? this.answers,
    );
  }

  /// Indica si la visita está completa
  bool get isComplete => true; // A visit record is always complete

  /// Indica si la visita necesita sincronización
  bool get needsSync => syncedAt == null;
}

/// Modelo para respuestas a preguntas del formulario dinámico
/// Alineado con la tabla route_visit_answers en Supabase:
///   id, visit_id, question_id, answer_text, answer_number,
///   answer_boolean, answer_json (jsonb), created_at
class RouteVisitAnswer {
  final String id;
  final String routeVisitId; // maps to 'visit_id' in DB
  final String questionId;
  final String? answerText;
  final double? answerNumber;
  final bool? answerBoolean;
  final List<String>? answerOptions; // stored in answer_json.options
  final List<String>? answerPhotoUrls; // stored in answer_json.photo_urls
  final DateTime createdAt;

  // Información de la pregunta (cargada por join)
  final RouteFormQuestion? question;

  const RouteVisitAnswer({
    required this.id,
    required this.routeVisitId,
    required this.questionId,
    this.answerText,
    this.answerNumber,
    this.answerBoolean,
    this.answerOptions,
    this.answerPhotoUrls,
    required this.createdAt,
    this.question,
  });

  factory RouteVisitAnswer.fromJson(Map<String, dynamic> json) {
    // Parse answer_json for options and photo_urls
    List<String>? options;
    List<String>? photoUrls;
    if (json['answer_json'] != null && json['answer_json'] is Map) {
      final answerJson = json['answer_json'] as Map<String, dynamic>;
      if (answerJson['options'] != null) {
        options = List<String>.from(answerJson['options'] as List);
      }
      if (answerJson['photo_urls'] != null) {
        photoUrls = List<String>.from(answerJson['photo_urls'] as List);
      }
    }

    return RouteVisitAnswer(
      id: json['id'] as String,
      // Handle both 'visit_id' (DB) and 'route_visit_id' (legacy)
      routeVisitId: (json['visit_id'] ?? json['route_visit_id'] ?? '') as String,
      questionId: json['question_id'] as String,
      answerText: json['answer_text'] as String?,
      answerNumber: (json['answer_number'] as num?)?.toDouble(),
      answerBoolean: json['answer_boolean'] as bool?,
      answerOptions: options,
      answerPhotoUrls: photoUrls,
      createdAt: DateTime.parse(json['created_at'] as String),
      question: json['route_form_question'] != null
          ? RouteFormQuestion.fromJson(
              json['route_form_question'] as Map<String, dynamic>)
          : (json['route_form_questions'] != null
              ? RouteFormQuestion.fromJson(
                  json['route_form_questions'] as Map<String, dynamic>)
              : null),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'visit_id': routeVisitId,
      'question_id': questionId,
      'answer_text': answerText,
      'answer_number': answerNumber,
      'answer_boolean': answerBoolean,
      'answer_json': _buildAnswerJson(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Para insertar en Supabase (sin id ni created_at)
  Map<String, dynamic> toInsertJson() {
    return {
      'visit_id': routeVisitId,
      'question_id': questionId,
      'answer_text': answerText,
      'answer_number': answerNumber,
      'answer_boolean': answerBoolean,
      'answer_json': _buildAnswerJson(),
    };
  }

  Map<String, dynamic>? _buildAnswerJson() {
    if (answerOptions == null && answerPhotoUrls == null) return null;
    final json = <String, dynamic>{};
    if (answerOptions != null && answerOptions!.isNotEmpty) {
      json['options'] = answerOptions;
    }
    if (answerPhotoUrls != null && answerPhotoUrls!.isNotEmpty) {
      json['photo_urls'] = answerPhotoUrls;
    }
    return json.isNotEmpty ? json : null;
  }

  RouteVisitAnswer copyWith({
    String? id,
    String? routeVisitId,
    String? questionId,
    String? answerText,
    double? answerNumber,
    bool? answerBoolean,
    List<String>? answerOptions,
    List<String>? answerPhotoUrls,
    DateTime? createdAt,
    RouteFormQuestion? question,
  }) {
    return RouteVisitAnswer(
      id: id ?? this.id,
      routeVisitId: routeVisitId ?? this.routeVisitId,
      questionId: questionId ?? this.questionId,
      answerText: answerText ?? this.answerText,
      answerNumber: answerNumber ?? this.answerNumber,
      answerBoolean: answerBoolean ?? this.answerBoolean,
      answerOptions: answerOptions ?? this.answerOptions,
      answerPhotoUrls: answerPhotoUrls ?? this.answerPhotoUrls,
      createdAt: createdAt ?? this.createdAt,
      question: question ?? this.question,
    );
  }

  /// Obtiene el valor de la respuesta como String para mostrar
  String get displayValue {
    if (answerText != null) return answerText!;
    if (answerNumber != null) return answerNumber.toString();
    if (answerBoolean != null) return answerBoolean! ? 'Sí' : 'No';
    if (answerOptions != null && answerOptions!.isNotEmpty) {
      return answerOptions!.join(', ');
    }
    if (answerPhotoUrls != null && answerPhotoUrls!.isNotEmpty) {
      return '${answerPhotoUrls!.length} foto(s)';
    }
    return '-';
  }
}
