class PopMaterial {
  final String id;
  final String nombre;
  final String marca; // SHELL, QUALID
  final String tipoMaterial; // TRADE, MERCHANDISING
  final String categoria; // ENTREGABLE, MATERIAL DE APOYO, INTERIOR, EXTERIOR
  final bool isActive;
  final String? linkedQuestionPattern; // Patrón de pregunta vinculada
  final String? linkedOptionPattern; // Patrón de opción vinculada

  const PopMaterial({
    required this.id,
    required this.nombre,
    required this.marca,
    required this.tipoMaterial,
    required this.categoria,
    this.isActive = true,
    this.linkedQuestionPattern,
    this.linkedOptionPattern,
  });

  bool get isLinked => linkedQuestionPattern != null && linkedOptionPattern != null;

  factory PopMaterial.fromJson(Map<String, dynamic> json) {
    return PopMaterial(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      marca: json['marca'] as String,
      tipoMaterial: json['tipo_material'] as String,
      categoria: json['categoria'] as String,
      isActive: json['is_active'] as bool? ?? true,
      linkedQuestionPattern: json['linked_question_pattern'] as String?,
      linkedOptionPattern: json['linked_option_pattern'] as String?,
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'nombre': nombre,
      'marca': marca,
      'tipo_material': tipoMaterial,
      'categoria': categoria,
      'is_active': isActive,
      'linked_question_pattern': linkedQuestionPattern,
      'linked_option_pattern': linkedOptionPattern,
    };
  }
}

class PopStock {
  final String id;
  final String materialId;
  final String sedeApp;
  final int cantidad;
  final DateTime? updatedAt;
  final PopMaterial? material;

  const PopStock({
    required this.id,
    required this.materialId,
    required this.sedeApp,
    required this.cantidad,
    this.updatedAt,
    this.material,
  });

  factory PopStock.fromJson(Map<String, dynamic> json) {
    return PopStock(
      id: json['id'] as String,
      materialId: json['material_id'] as String,
      sedeApp: json['sede_app'] as String,
      cantidad: json['cantidad'] as int? ?? 0,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      material: json['pop_materials'] != null
          ? PopMaterial.fromJson(json['pop_materials'] as Map<String, dynamic>)
          : null,
    );
  }
}

class PopMovement {
  final String id;
  final String materialId;
  final String sedeApp;
  final String tipo; // ingreso, egreso
  final int cantidad;
  final String? observaciones;
  final String? rifCliente;
  final String? registradoPor;
  final DateTime? createdAt;
  final PopMaterial? material;

  const PopMovement({
    required this.id,
    required this.materialId,
    required this.sedeApp,
    required this.tipo,
    required this.cantidad,
    this.observaciones,
    this.rifCliente,
    this.registradoPor,
    this.createdAt,
    this.material,
  });

  factory PopMovement.fromJson(Map<String, dynamic> json) {
    return PopMovement(
      id: json['id'] as String,
      materialId: json['material_id'] as String,
      sedeApp: json['sede_app'] as String,
      tipo: json['tipo'] as String,
      cantidad: json['cantidad'] as int,
      observaciones: json['observaciones'] as String?,
      rifCliente: json['rif_cliente'] as String?,
      registradoPor: json['registrado_por'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      material: json['pop_materials'] != null
          ? PopMaterial.fromJson(json['pop_materials'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'material_id': materialId,
      'sede_app': sedeApp,
      'tipo': tipo,
      'cantidad': cantidad,
      if (observaciones != null) 'observaciones': observaciones,
      if (rifCliente != null) 'rif_cliente': rifCliente,
      if (registradoPor != null) 'registrado_por': registradoPor,
    };
  }
}
