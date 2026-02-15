import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../config/app_constants.dart';
import '../../providers/auth_provider.dart';

/// Pantalla de splash que verifica la autenticación
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthentication();
  }

  /// Verifica el estado de autenticación y navega a la pantalla correspondiente
  Future<void> _checkAuthentication() async {
    // Esperar un mínimo de 2 segundos para mostrar el splash
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    try {
      // Obtener el usuario actual
      final userAsync = await ref.read(currentUserProvider.future);

      if (!mounted) return;

      if (userAsync != null && userAsync.canAccess) {
        // Usuario autenticado y activo, navegar según el rol
        if (userAsync.isAdmin) {
          context.go('/admin');
        } else {
          context.go('/home');
        }
      } else {
        // No hay usuario autenticado, ir a login
        context.go('/login');
      }
    } catch (e) {
      // Error al verificar autenticación, ir a login
      if (mounted) {
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.secondary,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo de Disbattery
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Image.asset(
                      'assets/images/disbattery_logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // Nombre de la aplicación
              Text(
                AppConstants.appName,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),

              // Subtítulo
              const Text(
                'Gestión de Rutas de Mercaderistas',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 50),

              // Indicador de carga
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              const SizedBox(height: 20),

              // Texto de carga
              const Text(
                'Cargando...',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
