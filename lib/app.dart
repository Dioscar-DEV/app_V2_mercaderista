import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config/theme_config.dart';
import 'routes/app_router.dart';
import 'config/app_constants.dart';

/// Widget principal de la aplicación
class DisbatteryTradeApp extends ConsumerWidget {
  const DisbatteryTradeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
