import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/models/user.dart';
import '../../data/repositories/auth_repository.dart';

/// Provider del repositorio de autenticación
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

/// Provider del estado de autenticación
final authStateProvider = StreamProvider<AuthState>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return authRepository.authStateChanges;
});

/// Provider del usuario actual
final currentUserProvider = FutureProvider<AppUser?>((ref) async {
  final authRepository = ref.watch(authRepositoryProvider);
  return authRepository.getCurrentUser();
});

/// Provider para verificar si el usuario está autenticado
final isAuthenticatedProvider = Provider<bool>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return authRepository.isAuthenticated;
});

/// Provider del controlador de autenticación
final authControllerProvider = StateNotifierProvider<AuthController, AuthState2>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return AuthController(authRepository);
});

/// Estados de autenticación personalizados
class AuthState2 {
  final bool isLoading;
  final String? error;
  final AppUser? user;

  const AuthState2({
    this.isLoading = false,
    this.error,
    this.user,
  });

  AuthState2 copyWith({
    bool? isLoading,
    String? error,
    AppUser? user,
  }) {
    return AuthState2(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      user: user ?? this.user,
    );
  }
}

/// Controlador de autenticación
class AuthController extends StateNotifier<AuthState2> {
  final AuthRepository _authRepository;

  AuthController(this._authRepository) : super(const AuthState2()) {
    _init();
  }

  /// Inicializa el controlador verificando el usuario actual
  Future<void> _init() async {
    try {
      final user = await _authRepository.getCurrentUser();
      state = state.copyWith(user: user);
    } catch (e) {
      // Si hay error al obtener usuario, no hacemos nada
      // El estado permanece sin usuario
    }
  }

  /// Inicia sesión con email y contraseña
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final user = await _authRepository.signInWithEmail(
        email: email,
        password: password,
      );

      // Verificar que el usuario esté activo
      if (!user.canAccess) {
        await _authRepository.signOut();
        state = state.copyWith(
          isLoading: false,
          error: 'Tu cuenta está ${user.status.displayName.toLowerCase()}. '
              'Contacta al administrador.',
        );
        return;
      }

      state = state.copyWith(isLoading: false, user: user);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Registra un nuevo usuario
  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    String? sede,
    String? region,
    String? phone,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final user = await _authRepository.signUp(
        email: email,
        password: password,
        fullName: fullName,
        sede: sede,
        region: region,
        phone: phone,
      );

      state = state.copyWith(
        isLoading: false,
        user: user,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Cierra la sesión
  Future<void> signOut() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _authRepository.signOut();
      state = const AuthState2();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Recupera la contraseña
  Future<void> resetPassword(String email) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _authRepository.resetPassword(email);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Actualiza la contraseña
  Future<void> updatePassword(String newPassword) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _authRepository.updatePassword(newPassword);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Limpia el error
  void clearError() {
    state = state.copyWith(error: null);
  }
}
