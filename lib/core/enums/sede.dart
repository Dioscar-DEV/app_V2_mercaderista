/// Regiones geográficas de operación
enum Region {
  centroCapital('centro_capital', 'Zona Metropolitana y Centro'),
  oriente('oriente', 'Zona Oriente'),
  centroLosLlanos('centro_los_llanos', 'Zona Centro'),
  occidente('occidente', 'Zona Occidente');

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
  // ZONA METROPOLITANA Y CENTRO
  grupoDisbattery('grupo_disbattery', 'Grupo Disbattery', Region.centroCapital),

  // ZONA ORIENTE
  oceanoPacifico('oceano_pacifico', 'Dislub Oriente', Region.oriente),

  // ZONA CENTRO
  blitz2000('blitz_2000', 'Blitz 2000', Region.centroLosLlanos),

  // ZONA OCCIDENTE
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
      case 'oceano_pacifico':
        return Sede.oceanoPacifico;
      case 'disbattery': // backward compatibility
        return Sede.oceanoPacifico;
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
        return ['Amazonas', 'Aragua', 'Distrito Capital', 'Falcón', 'La Guaira', 'Lara', 'Miranda', 'Portuguesa', 'Yaracuy'];
      case Sede.oceanoPacifico:
        return ['Anzoátegui', 'Bolívar', 'Delta Amacuro', 'Monagas', 'Nueva Esparta', 'Sucre'];
      case Sede.blitz2000:
        return ['Apure', 'Carabobo', 'Cojedes', 'Guárico'];
      case Sede.grupoVictoria:
        return ['Barinas', 'Mérida', 'Táchira', 'Trujillo', 'Zulia'];
    }
  }

  /// Descripción completa de la sede
  String get fullDescription => '$displayName (${region.displayName})';

  @override
  String toString() => displayName;
}
