import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../config/supabase_config.dart';
import '../../../config/theme_config.dart';

/// Pantalla para establecer una nueva contraseña tras click en el link de recuperación.
///
/// Cuando el usuario hace click en el link del email, Supabase abre esta página
/// con un token en el fragment (#access_token=...&type=recovery). El SDK detecta
/// el evento `passwordRecovery` automáticamente, y aquí solo permitimos que ponga
/// la nueva clave.
class UpdatePasswordScreen extends ConsumerStatefulWidget {
  const UpdatePasswordScreen({super.key});

  @override
  ConsumerState<UpdatePasswordScreen> createState() =>
      _UpdatePasswordScreenState();
}

class _UpdatePasswordScreenState extends ConsumerState<UpdatePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  String? _error;
  bool _ready = false;
  bool _checking = true;
  StreamSubscription<AuthState>? _authSub;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    _initRecoveryFlow();
  }

  Future<void> _initRecoveryFlow() async {
    // Si ya hay sesión, listo
    if (SupabaseConfig.client.auth.currentSession != null) {
      setState(() {
        _ready = true;
        _checking = false;
      });
      return;
    }

    // Escuchar cambios de auth para detectar passwordRecovery o signedIn
    _authSub = SupabaseConfig.client.auth.onAuthStateChange.listen((data) {
      if (!mounted) return;
      final event = data.event;
      if (event == AuthChangeEvent.passwordRecovery ||
          event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.tokenRefreshed ||
          event == AuthChangeEvent.initialSession) {
        if (SupabaseConfig.client.auth.currentSession != null) {
          _timeoutTimer?.cancel();
          setState(() {
            _ready = true;
            _checking = false;
            _error = null;
          });
        }
      }
    });

    // Intentar procesar manualmente la URL (para flujo implicit con #access_token=...)
    try {
      final uri = Uri.base;
      final hasRecoveryHash = uri.fragment.contains('access_token=') &&
          uri.fragment.contains('type=recovery');
      final hasRecoveryQuery = uri.queryParameters.containsKey('code') ||
          uri.queryParameters['type'] == 'recovery';

      if (hasRecoveryHash || hasRecoveryQuery) {
        debugPrint('[UpdatePassword] Procesando URL: $uri');
        await SupabaseConfig.client.auth.getSessionFromUrl(uri);
      }
    } catch (e) {
      debugPrint('[UpdatePassword] Error procesando URL: $e');
    }

    // Re-verificar sesión después de procesar URL
    if (mounted && SupabaseConfig.client.auth.currentSession != null) {
      _timeoutTimer?.cancel();
      setState(() {
        _ready = true;
        _checking = false;
        _error = null;
      });
      return;
    }

    // Timeout: si en 5 segundos no hay sesión, mostrar error
    _timeoutTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      if (SupabaseConfig.client.auth.currentSession == null) {
        setState(() {
          _ready = false;
          _checking = false;
          _error =
              'El link de recuperación no es válido o ha expirado. Solicita uno nuevo.';
        });
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _timeoutTimer?.cancel();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleUpdatePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await SupabaseConfig.client.auth.updateUser(
        UserAttributes(password: _passwordController.text),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contraseña actualizada con éxito'),
          backgroundColor: Colors.green,
        ),
      );

      // Cerrar sesión de recovery y volver al login
      await SupabaseConfig.client.auth.signOut();
      if (mounted) context.go('/login');
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Error al actualizar contraseña: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.lock_reset,
                        size: 64,
                        color: ThemeConfig.primaryColor,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Restablecer contraseña',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _checking
                            ? 'Validando enlace...'
                            : (_ready
                                ? 'Ingresa tu nueva contraseña'
                                : 'Link inválido'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (_checking)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      if (_error != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red[200]!),
                          ),
                          child: Text(
                            _error!,
                            style: TextStyle(color: Colors.red[800]),
                          ),
                        ),
                      if (_ready) ...[
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscure,
                          decoration: InputDecoration(
                            labelText: 'Nueva contraseña',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(_obscure
                                  ? Icons.visibility
                                  : Icons.visibility_off),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Requerido';
                            if (v.length < 6) return 'Mínimo 6 caracteres';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _confirmController,
                          obscureText: _obscureConfirm,
                          decoration: InputDecoration(
                            labelText: 'Confirmar contraseña',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(_obscureConfirm
                                  ? Icons.visibility
                                  : Icons.visibility_off),
                              onPressed: () => setState(
                                  () => _obscureConfirm = !_obscureConfirm),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Requerido';
                            if (v != _passwordController.text) {
                              return 'Las contraseñas no coinciden';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed:
                              _loading ? null : _handleUpdatePassword,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ThemeConfig.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _loading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Actualizar contraseña',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => context.go('/login'),
                        child: const Text('Volver al login'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
