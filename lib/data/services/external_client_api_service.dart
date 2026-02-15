import 'package:dio/dio.dart';
import '../../core/models/client.dart';

/// Servicio para consumir la API externa de clientes
class ExternalClientApiService {
  static const String _baseUrl = 'https://apimercaderista-production.up.railway.app';
  
  final Dio _dio;
  
  ExternalClientApiService({Dio? dio}) : _dio = dio ?? Dio(BaseOptions(
    baseUrl: _baseUrl,
    headers: {'accept': 'application/json'},
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
  ));
  
  /// Mapeo de códigos de sede de la API a nuestras sedes de la app
  static const Map<int, String> sedeMapping = {
    1: 'blitz_2000',          // Valencia (Carabobo)
    2: 'blitz_2000',          // Valencia (Carabobo)
    3: 'blitz_2000',          // Calabozo (Guárico)
    4: 'grupo_disbattery',    // Girardot (Aragua)
    5: 'grupo_disbattery',    // Carirubana (Falcón)
    6: 'grupo_disbattery',    // Distrito Capital
    7: 'grupo_disbattery',    // Iribarren (Lara)
    8: 'oceano_pacifico',     // Porlamar (Nueva Esparta)
    9: 'oceano_pacifico',     // Maturin (Monagas)
    10: 'oceano_pacifico',    // Barcelona (Anzoátegui)
    11: 'oceano_pacifico',    // Guayana (Bolívar)
    12: 'grupo_victoria',     // San Cristobal (Táchira)
    13: 'grupo_victoria',     // Merida (Mérida)
    14: 'grupo_victoria',     // Maracaibo (Zulia)
    15: 'grupo_victoria',     // Barinas (Barinas)
    16: 'grupo_victoria',     // Valera (Trujillo)
  };

  /// Obtiene todas las sedes con el conteo de clientes
  Future<List<ApiSede>> getSedes() async {
    try {
      final response = await _dio.get('/sedes');

      if (response.statusCode == 200) {
        final data = response.data;
        final sedesList = data['sedes'] as List;
        
        return sedesList.map((json) {
          final codigo = json['codigo'] as int;
          final sedeApp = sedeMapping[codigo] ?? 'grupo_disbattery';
          return ApiSede.fromExternalApi(json as Map<String, dynamic>, sedeApp);
        }).toList();
      } else {
        throw Exception('Error al obtener sedes: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión al obtener sedes: $e');
    }
  }

  /// Obtiene los clientes de una sede específica
  Future<List<Client>> getClientesBySede(int sedeCode) async {
    try {
      final response = await _dio.get('/clientes/sede/$sedeCode');

      if (response.statusCode == 200) {
        final data = response.data as List;
        final sedeApp = sedeMapping[sedeCode] ?? 'grupo_disbattery';
        
        return data.map((json) {
          return Client.fromExternalApi(
            json as Map<String, dynamic>,
            sedeCode,
            sedeApp,
          );
        }).toList();
      } else {
        throw Exception('Error al obtener clientes: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión al obtener clientes: $e');
    }
  }

  /// Obtiene todos los clientes de múltiples sedes
  Future<List<Client>> getAllClientes({
    List<int>? sedeCodes,
    void Function(int current, int total)? onProgress,
  }) async {
    final codes = sedeCodes ?? sedeMapping.keys.toList();
    final allClients = <Client>[];
    
    for (var i = 0; i < codes.length; i++) {
      final code = codes[i];
      try {
        final clients = await getClientesBySede(code);
        allClients.addAll(clients);
        onProgress?.call(i + 1, codes.length);
      } catch (e) {
        // Continuar con las otras sedes si una falla
        print('Error al obtener clientes de sede $code: $e');
      }
    }
    
    return allClients;
  }

  /// Obtiene los códigos de sede que corresponden a una sede de la app
  static List<int> getSedeCodesForApp(String sedeApp) {
    return sedeMapping.entries
        .where((e) => e.value == sedeApp)
        .map((e) => e.key)
        .toList();
  }

  /// Obtiene el nombre de la sede de la API por código
  static String getSedeNameByCode(int code) {
    const sedeNames = {
      1: 'Valencia',
      2: 'Valencia',
      3: 'Calabozo',
      4: 'Girardot',
      5: 'Carirubana',
      6: 'Distrito Capital',
      7: 'Iribarren',
      8: 'Porlamar',
      9: 'Maturín',
      10: 'Barcelona',
      11: 'Guayana',
      12: 'San Cristóbal',
      13: 'Mérida',
      14: 'Maracaibo',
      15: 'Barinas',
      16: 'Valera',
    };
    return sedeNames[code] ?? 'Desconocida';
  }
}
