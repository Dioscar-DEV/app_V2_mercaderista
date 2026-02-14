/// Constantes globales de la aplicación
class AppConstants {
  // Información de la aplicación
  static const String appName = 'Disbattery Trade';
  static const String appVersion = '1.0.0';

  // Configuración de Google Maps (comentado por ahora)
  // TODO: Configurar cuando se necesite usar Google Maps
  // static const String googleMapsApiKey = String.fromEnvironment(
  //   'GOOGLE_MAPS_API_KEY',
  //   defaultValue: 'your-google-maps-api-key',
  // );

  // Tiempos de timeout
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration syncTimeout = Duration(minutes: 5);

  // Configuración de imágenes
  static const int maxImageSizeBytes = 5 * 1024 * 1024; // 5 MB
  static const int imageQuality = 70; // 0-100
  static const int maxImageWidth = 1920;
  static const int maxImageHeight = 1080;

  // Configuración de sincronización
  static const Duration syncInterval = Duration(minutes: 15);
  static const int maxSyncRetries = 3;
  static const Duration syncRetryDelay = Duration(seconds: 30);

  // Configuración de ubicación
  static const double locationAccuracyThreshold = 50.0; // metros
  static const Duration locationTimeout = Duration(seconds: 10);
  static const int maxLocationRetries = 3;

  // Paginación
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // Cache
  static const Duration cacheExpiration = Duration(hours: 24);
  static const int maxCacheSize = 100 * 1024 * 1024; // 100 MB

  // Validaciones
  static const int minPasswordLength = 8;
  static const int maxPasswordLength = 50;
  static const int maxNotesLength = 500;
  static const int maxNameLength = 100;
  static const int maxAddressLength = 200;

  // Formatos
  static const String dateFormat = 'dd/MM/yyyy';
  static const String dateTimeFormat = 'dd/MM/yyyy HH:mm';
  static const String timeFormat = 'HH:mm';
  static const String shortDateFormat = 'dd/MM/yy';

  // Colores de marca (Shell y Qualid)
  static const String shellPrimaryColor = '#FFDD00';
  static const String shellSecondaryColor = '#ED1C24';
  static const String qualidPrimaryColor = '#0066CC';
  static const String qualidSecondaryColor = '#00AA00';

  // Regiones de Venezuela
  static const List<String> regions = [
    'Occidente',
    'Centro-Capital',
    'Centro-Los Llanos',
    'Oriente',
  ];

  // Sedes/Sucursales de Disbattery
  static const Map<String, List<String>> sedes = {
    'GRUPO DISBATTERY': [
      'Falcon',
      'Aragua',
      'Lara',
      'Caracas',
    ],
    'BLITZ 2000': [
      'Valencia',
      'Calabozo',
    ],
    'GRUPO VICTORIA': [
      'San Cristobal',
      'Maracaibo',
      'Valera',
      'VG-SBZ',
      'Barinas',
      'Merida',
    ],
    'DISBATTERY': [
      'El Tigre',
      'Puerto La Cruz',
      'Maturin',
      'Puerto Ordaz',
      'Margarita',
    ],
  };

  // Todas las sucursales (lista plana)
  static const List<String> allSucursales = [
    // GRUPO DISBATTERY
    'Falcon',
    'Aragua',
    'Lara',
    'Caracas',
    // BLITZ 2000
    'Valencia',
    'Calabozo',
    // GRUPO VICTORIA
    'San Cristobal',
    'Maracaibo',
    'Valera',
    'VG-SBZ',
    'Barinas',
    'Merida',
    // DISBATTERY
    'El Tigre',
    'Puerto La Cruz',
    'Maturin',
    'Puerto Ordaz',
    'Margarita',
  ];

  // Estados de Venezuela
  static const List<String> states = [
    'Amazonas',
    'Anzoátegui',
    'Apure',
    'Aragua',
    'Barinas',
    'Bolívar',
    'Carabobo',
    'Cojedes',
    'Delta Amacuro',
    'Distrito Capital',
    'Falcón',
    'Guárico',
    'Lara',
    'Mérida',
    'Miranda',
    'Monagas',
    'Nueva Esparta',
    'Portuguesa',
    'Sucre',
    'Táchira',
    'Trujillo',
    'Vargas',
    'Yaracuy',
    'Zulia',
  ];

  // Tipos de clientes
  static const List<String> clientTypes = [
    'Estación de Servicio',
    'Distribuidor',
    'Taller',
    'Supermercado',
    'Ferretería',
    'Otro',
  ];

  // Productos Shell
  static const List<String> shellProducts = [
    'Shell Helix Ultra',
    'Shell Helix HX7',
    'Shell Helix HX5',
    'Shell Rimula',
    'Shell Tellus',
    'Shell Omala',
    'Otros',
  ];

  // Productos Qualid
  static const List<String> qualidProducts = [
    'Qualid Super',
    'Qualid Premium',
    'Qualid Diesel',
    'Qualid 2T',
    'Qualid 4T',
    'Qualid ATF',
    'Otros',
  ];

  // Material POP Shell
  static const List<String> shellPOPMaterials = [
    'Afiche',
    'Banderín',
    'Exhibidor',
    'Aviso',
    'Banner',
    'Letrero',
    'Otros',
  ];

  // Material POP Qualid
  static const List<String> qualidPOPMaterials = [
    'Afiche',
    'Banderín',
    'Exhibidor',
    'Aviso',
    'Banner',
    'Letrero',
    'Otros',
  ];

  // Notificaciones
  static const String notificationChannelId = 'disbattery_trade_channel';
  static const String notificationChannelName = 'Disbattery Trade Notifications';
  static const String notificationChannelDescription = 'Notificaciones de Disbattery Trade';
}
