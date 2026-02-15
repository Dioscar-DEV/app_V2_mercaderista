/// Modelo para un check-in diario de mercaderista en un evento
class EventCheckIn {
  final String id;
  final String eventId;
  final String mercaderistaId;
  final DateTime checkInDate;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final double? latitude;
  final double? longitude;
  final String? observations;
  final DateTime createdAt;

  // Datos cargados por join
  final List<EventCheckInAnswer>? answers;
  final String? mercaderistaName;

  const EventCheckIn({
    required this.id,
    required this.eventId,
    required this.mercaderistaId,
    required this.checkInDate,
    this.startedAt,
    this.completedAt,
    this.latitude,
    this.longitude,
    this.observations,
    required this.createdAt,
    this.answers,
    this.mercaderistaName,
  });

  factory EventCheckIn.fromJson(Map<String, dynamic> json) {
    String? name;
    if (json['users'] != null && json['users'] is Map) {
      name = (json['users'] as Map<String, dynamic>)['full_name'] as String?;
    }

    return EventCheckIn(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      mercaderistaId: json['mercaderista_id'] as String,
      checkInDate: DateTime.parse(json['check_in_date'] as String),
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      observations: json['observations'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      mercaderistaName: name,
      answers: json['event_check_in_answers'] != null
          ? (json['event_check_in_answers'] as List)
              .map((e) =>
                  EventCheckInAnswer.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_id': eventId,
      'mercaderista_id': mercaderistaId,
      'check_in_date': checkInDate.toIso8601String().split('T')[0],
      'started_at': startedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'observations': observations,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'event_id': eventId,
      'mercaderista_id': mercaderistaId,
      'check_in_date': checkInDate.toIso8601String().split('T')[0],
      'started_at': startedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'observations': observations,
    };
  }

  EventCheckIn copyWith({
    String? id,
    String? eventId,
    String? mercaderistaId,
    DateTime? checkInDate,
    DateTime? startedAt,
    DateTime? completedAt,
    double? latitude,
    double? longitude,
    String? observations,
    DateTime? createdAt,
    List<EventCheckInAnswer>? answers,
    String? mercaderistaName,
  }) {
    return EventCheckIn(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      mercaderistaId: mercaderistaId ?? this.mercaderistaId,
      checkInDate: checkInDate ?? this.checkInDate,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      observations: observations ?? this.observations,
      createdAt: createdAt ?? this.createdAt,
      answers: answers ?? this.answers,
      mercaderistaName: mercaderistaName ?? this.mercaderistaName,
    );
  }

  bool get isCompleted => completedAt != null;
}

/// Modelo para respuestas del formulario en un check-in de evento
class EventCheckInAnswer {
  final String id;
  final String checkInId;
  final String questionId;
  final String? answer;
  final String? photoUrl;
  final DateTime createdAt;

  const EventCheckInAnswer({
    required this.id,
    required this.checkInId,
    required this.questionId,
    this.answer,
    this.photoUrl,
    required this.createdAt,
  });

  factory EventCheckInAnswer.fromJson(Map<String, dynamic> json) {
    return EventCheckInAnswer(
      id: json['id'] as String,
      checkInId: json['check_in_id'] as String,
      questionId: json['question_id'] as String,
      answer: json['answer'] as String?,
      photoUrl: json['photo_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'check_in_id': checkInId,
      'question_id': questionId,
      'answer': answer,
      'photo_url': photoUrl,
    };
  }
}
