import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/supabase_config.dart';
import '../../core/models/user.dart';

/// Repositorio para operaciones de autenticación
class AuthRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  /// Inicia sesión con email y contraseña
  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw Exception('Error al iniciar sesión');
      }

      // Obtener datos del usuario desde la tabla users
      final userData = await _client
          .from('users')
          .select()
          .eq('id', response.user!.id)
          .single();

      return AppUser.fromJson(userData);
    } on AuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Error al iniciar sesión: $e');
    }
  }

  /// Registra un nuevo usuario
  Future<AppUser> signUp({
    required String email,
    required String password,
    required String fullName,
    String? sede,
    String? region,
    String? phone,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'sede': sede,
          'region': region,
          'phone': phone,
        },
      );

      if (response.user == null) {
        throw Exception('Error al crear la cuenta');
      }

      // Crear registro en la tabla users
      final userData = {
        'id': response.user!.id,
        'email': email,
        'full_name': fullName,
        'role': 'mercaderista', // Rol por defecto
        'sede': sede,
        'region': region,
        'phone': phone,
        'status': 'pending', // Estado pendiente hasta que admin apruebe
        'created_at': DateTime.now().toIso8601String(),
      };

      await _client.from('users').insert(userData);

      // Obtener el usuario completo
      final user = await _client
          .from('users')
          .select()
          .eq('id', response.user!.id)
          .single();

      return AppUser.fromJson(user);
    } on AuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Error al registrar usuario: $e');
    }
  }

  /// Cierra la sesión actual
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on AuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Error al cerrar sesión: $e');
    }
  }

  /// Obtiene el usuario actual
  Future<AppUser?> getCurrentUser() async {
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) return null;

      final userData = await _client
          .from('users')
          .select()
          .eq('id', currentUser.id)
          .single();

      return AppUser.fromJson(userData);
    } catch (e) {
      return null;
    }
  }

  /// Verifica si hay una sesión activa
  bool get isAuthenticated => _client.auth.currentUser != null;

  /// Stream de cambios en el estado de autenticación
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Recupera la contraseña
  Future<void> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
    } on AuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Error al recuperar contraseña: $e');
    }
  }

  /// Actualiza la contraseña del usuario
  Future<void> updatePassword(String newPassword) async {
    try {
      await _client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
    } on AuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Error al actualizar contraseña: $e');
    }
  }

  /// Maneja las excepciones de autenticación
  String _handleAuthException(AuthException e) {
    switch (e.statusCode) {
      case '400':
        return 'Credenciales inválidas';
      case '422':
        return 'Email o contraseña inválidos';
      case '429':
        return 'Demasiados intentos. Intenta más tarde';
      default:
        return e.message;
    }
  }
}
