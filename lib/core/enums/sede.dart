/// Regiones geográficas de operación
enum Region {
  centroCapital('centro_capital', 'Centro-Capital'),
  oriente('oriente', 'Oriente'),
  centroLosLlanos('centro_los_llanos', 'Centro-Los Llanos'),
  occidente('occidente', 'Occidente');

  const Region(this.value, this.displayName);

  final String value;
  final String displayName;

  /// Crea una Region desde un string
  static Region fromString(String value) {
    switch (value.toLowerCase().replaceAll('-', '_').replaceAll(' ', '_')) {
      case 'centro_capital':
        return Region.centroCapital;
      case 'oriente':
        return Region.oriente;
      case 'centro_los_llanos':
        return Region.centroLosLlanos;
      case 'occidente':
        return Region.occidente;
      default:
        throw ArgumentError('Invalid region: $value');
    }
  }

  /// Obtiene las sedes que pertenecen a esta región
  List<Sede> get sedes {
    return Sede.values.where((s) => s.region == this).toList();
  }

  @override
  String toString() => displayName;
}

/// Sedes de operación de Disbattery
/// 
/// Cada sede pertenece a una región y cubre estados específicos de Venezuela
enum Sede {
  // CENTRO-CAPITAL
  grupoDisbattery('grupo_disbattery', 'Grupo Disbattery', Region.centroCapital),
  
  // ORIENTE
  disbattery('disbattery', 'Disbattery', Region.oriente),
  
  // CENTRO-LOS LLANOS
  blitz2000('blitz_2000', 'Blitz 2000', Region.centroLosLlanos),
  
  // OCCIDENTE
  grupoVictoria('grupo_victoria', 'Grupo Victoria', Region.occidente);

  const Sede(this.value, this.displayName, this.region);

  final String value;
  final String displayName;
  final Region region;

  /// Crea una Sede desde un string
  static Sede fromString(String value) {
    switch (value.toLowerCase().replaceAll(' ', '_').replaceAll('-', '_')) {
      case 'grupo_disbattery':
        return Sede.grupoDisbattery;
      case 'disbattery':
        return Sede.disbattery;
      case 'blitz_2000':
      case 'blitz2000':
        return Sede.blitz2000;
      case 'grupo_victoria':
        return Sede.grupoVictoria;
      default:
        throw ArgumentError('Invalid sede: $value');
    }
  }

  /// Intenta crear una Sede desde un string, retorna null si no es válido
  static Sede? tryFromString(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return fromString(value);
    } catch (_) {
      return null;
    }
  }

  /// Lista de todos los estados/zonas que cubre esta sede
  List<String> get estados {
    switch (this) {
      case Sede.grupoDisbattery:
        return ['Distrito Capital', 'Miranda', 'Vargas'];
      case Sede.disbattery:
        return ['Aragua', 'Anzoátegui', 'Bolívar', 'Monagas', 'Sucre', 'Nueva Esparta'];
      case Sede.blitz2000:
        return ['Carabobo', 'Guárico', 'Lara', 'Yaracuy', 'Falcón', 'Zulia', 'Táchira', 'Mérida', 'Trujillo'];
      case Sede.grupoVictoria:
        return ['Cojedes', 'Portuguesa', 'Barinas', 'Apure', 'Amazonas', 'Delta Amacuro'];
    }
  }

  /// Descripción completa de la sede
  String get fullDescription => '$displayName (${region.displayName})';

  @override
  String toString() => displayName;
}
