import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'app.dart';
import 'config/supabase_config.dart';

/// Punto de entrada principal de la aplicación
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Usar path URL strategy en web (sin #) para que los enlaces de
  // recuperación de Supabase (#access_token=...) funcionen correctamente
  usePathUrlStrategy();

  // Configurar orientación de la pantalla (solo portrait)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Configurar el estilo de la barra de estado
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  // Inicializar Supabase
  try {
    await SupabaseConfig.initialize();
    print('✅ Supabase inicializado correctamente');
  } catch (e) {
    print('❌ Error al inicializar Supabase: $e');
    // En producción, podrías mostrar un error más amigable al usuario
  }

  // Ejecutar la aplicación
  runApp(
    const ProviderScope(
      child: DisbatteryTradeApp(),
    ),
  );
}
