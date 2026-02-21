class Prospect {
  final String id;
  final String mercaderistaId;
  final String name;
  final String? rif;
  final String address;
  final String? phone;
  final String? contactPerson;
  final double? latitude;
  final double? longitude;
  final String? photoUrl;
  final bool inSitu;
  final String sedeApp;
  final String? notes;
  final String status; // pending, approved, rejected, converted
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isSynced; // solo local (SQLite)

  const Prospect({
    required this.id,
    required this.mercaderistaId,
    required this.name,
    this.rif,
    required this.address,
    this.phone,
    this.contactPerson,
    this.latitude,
    this.longitude,
    this.photoUrl,
    this.inSitu = true,
    required this.sedeApp,
    this.notes,
    this.status = 'pending',
    this.createdAt,
    this.updatedAt,
    this.isSynced = false,
  });

  factory Prospect.fromJson(Map<String, dynamic> json) {
    return Prospect(
      id: json['id'] as String,
      mercaderistaId: json['mercaderista_id'] as String,
      name: json['name'] as String,
      rif: json['rif'] as String?,
      address: json['address'] as String,
      phone: json['phone'] as String?,
      contactPerson: json['contact_person'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      photoUrl: json['photo_url'] as String?,
      inSitu: json['in_situ'] is bool
          ? json['in_situ'] as bool
          : (json['in_situ'] as int?) == 1,
      sedeApp: json['sede_app'] as String,
      notes: json['notes'] as String?,
      status: json['status'] as String? ?? 'pending',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      isSynced: json['is_synced'] == 1 || json['is_synced'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'mercaderista_id': mercaderistaId,
      'name': name,
      'rif': rif,
      'address': address,
      'phone': phone,
      'contact_person': contactPerson,
      'latitude': latitude,
      'longitude': longitude,
      'photo_url': photoUrl,
      'in_situ': inSitu,
      'sede_app': sedeApp,
      'notes': notes,
      'status': status,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toSqlite() {
    return {
      'id': id,
      'mercaderista_id': mercaderistaId,
      'name': name,
      'rif': rif,
      'address': address,
      'phone': phone,
      'contact_person': contactPerson,
      'latitude': latitude,
      'longitude': longitude,
      'photo_url': photoUrl,
      'in_situ': inSitu ? 1 : 0,
      'sede_app': sedeApp,
      'notes': notes,
      'status': status,
      'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
      'is_synced': isSynced ? 1 : 0,
    };
  }

  Prospect copyWith({
    String? id,
    String? mercaderistaId,
    String? name,
    String? rif,
    String? address,
    String? phone,
    String? contactPerson,
    double? latitude,
    double? longitude,
    String? photoUrl,
    bool? inSitu,
    String? sedeApp,
    String? notes,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSynced,
  }) {
    return Prospect(
      id: id ?? this.id,
      mercaderistaId: mercaderistaId ?? this.mercaderistaId,
      name: name ?? this.name,
      rif: rif ?? this.rif,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      contactPerson: contactPerson ?? this.contactPerson,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      photoUrl: photoUrl ?? this.photoUrl,
      inSitu: inSitu ?? this.inSitu,
      sedeApp: sedeApp ?? this.sedeApp,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
