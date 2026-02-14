import 'package:geolocator/geolocator.dart';
import '../../config/app_constants.dart';

/// Servicio de ubicación GPS
/// Maneja permisos y obtención de coordenadas reales
class LocationService {
  static LocationService? _instance;
  static LocationService get instance => _instance ??= LocationService._();
  LocationService._();

  /// Verifica y solicita permisos de ubicación
  /// Retorna true si los permisos fueron otorgados
  Future<bool> requestPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// Verifica si los permisos de ubicación están otorgados
  Future<bool> hasPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  /// Obtiene la ubicación actual
  /// Retorna null si no se puede obtener (sin permisos o servicio desactivado)
  Future<Position?> getCurrentPosition() async {
    try {
      final hasPerms = await requestPermissions();
      if (!hasPerms) return null;

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: AppConstants.locationTimeout,
      );
    } catch (e) {
      // Intentar con menor precisión si falla
      try {
        return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 15),
        );
      } catch (_) {
        return null;
      }
    }
  }

  /// Obtiene ubicación como mapa {latitude, longitude} o null
  Future<({double latitude, double longitude})?> getCoordinates() async {
    final position = await getCurrentPosition();
    if (position == null) return null;
    return (latitude: position.latitude, longitude: position.longitude);
  }

  /// Verifica si el servicio de ubicación está habilitado
  Future<bool> isServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Abre la configuración de ubicación del dispositivo
  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  /// Abre la configuración de permisos de la app
  Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }
}
