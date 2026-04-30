import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'config/theme_config.dart';
import 'routes/app_router.dart';
import 'config/app_constants.dart';

/// Widget principal de la aplicación
class DisbatteryTradeApp extends ConsumerStatefulWidget {
  const DisbatteryTradeApp({super.key});

  @override
  ConsumerState<DisbatteryTradeApp> createState() => _DisbatteryTradeAppState();
}

class _DisbatteryTradeAppState extends ConsumerState<DisbatteryTradeApp> {
  @override
  void initState() {
    super.initState();
    // Escuchar passwordRecovery para forzar navegación a /update-password
    SupabaseConfig.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        AppRouter.router.go('/update-password');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      // Configuración de la app
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,

      // Tema
      theme: ThemeConfig.lightTheme,

      // Configuración de router
      routerConfig: AppRouter.router,

      // Configuración de localización
      // TODO: Agregar soporte de localización en el futuro
      // localizationsDelegates: const [
      //   GlobalMaterialLocalizations.delegate,
      //   GlobalWidgetsLocalizations.delegate,
      //   GlobalCupertinoLocalizations.delegate,
      // ],
      // supportedLocales: const [
      //   Locale('es', 'ES'), // Español
      // ],
      // locale: const Locale('es', 'ES'),
    );
  }
}
