/// Tipos de visitas que puede realizar un mercaderista
enum VisitType {
  merchandisingShell('merchandising_shell', 'Merchandising Shell', 'Visita de merchandising para productos Shell'),
  merchandisingQualid('merchandising_qualid', 'Merchandising Qualid', 'Visita de merchandising para productos Qualid'),
  tradeEvent('trade_event', 'Trade Evento', 'Participación en evento comercial'),
  tradeImpulse('trade_impulse', 'Trade Impulso', 'Actividad de impulso de ventas');

  const VisitType(this.value, this.displayName, this.description);

  final String value;
  final String displayName;
  final String description;

  /// Crea un VisitType desde un string
  static VisitType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'merchandising_shell':
        return VisitType.merchandisingShell;
      case 'merchandising_qualid':
        return VisitType.merchandisingQualid;
      case 'trade_event':
        return VisitType.tradeEvent;
      case 'trade_impulse':
        return VisitType.tradeImpulse;
      default:
        throw ArgumentError('Invalid visit type: $value');
    }
  }

  /// Verifica si es un tipo de merchandising
  bool get isMerchandising =>
      this == VisitType.merchandisingShell ||
      this == VisitType.merchandisingQualid;

  /// Verifica si es un tipo de trade
  bool get isTrade =>
      this == VisitType.tradeEvent || this == VisitType.tradeImpulse;

  /// Verifica si es merchandising Shell
  bool get isShell => this == VisitType.merchandisingShell;

  /// Verifica si es merchandising Qualid
  bool get isQualid => this == VisitType.merchandisingQualid;

  @override
  String toString() => displayName;
}
