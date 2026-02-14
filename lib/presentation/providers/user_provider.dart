import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/user.dart';
import '../../core/enums/user_role.dart';
import '../../core/enums/user_status.dart';
import '../../core/enums/sede.dart';
import '../../data/repositories/user_repository.dart';
import 'auth_provider.dart';

/// Provider del repositorio de usuarios
final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository();
});

/// Provider para obtener un usuario por ID
final userByIdProvider = FutureProvider.family<AppUser, String>((ref, userId) async {
  final userRepository = ref.watch(userRepositoryProvider);
  return userRepository.getUserById(userId);
});

/// Provider para obtener todos los usuarios según permisos del usuario actual
final allUsersProvider = FutureProvider<List<AppUser>>((ref) async {
  final userRepository = ref.watch(userRepositoryProvider);
  final currentUser = await ref.watch(currentUserProvider.future);
  
  if (currentUser == null) {
    throw Exception('Usuario no autenticado');
  }
  
  return userRepository.getAllUsers(requestingUser: currentUser);
});

/// Provider para obtener mercaderistas activos
final activeMercaderistasProvider = FutureProvider<List<AppUser>>((ref) async {
  final userRepository = ref.watch(userRepositoryProvider);
  final currentUser = await ref.watch(currentUserProvider.future);
  
  if (currentUser == null) {
    throw Exception('Usuario no autenticado');
  }
  
  return userRepository.getActiveMercaderistas(requestingUser: currentUser);
});

/// Provider para obtener usuarios pendientes
final pendingUsersProvider = FutureProvider<List<AppUser>>((ref) async {
  final userRepository = ref.watch(userRepositoryProvider);
  final currentUser = await ref.watch(currentUserProvider.future);
  
  if (currentUser == null) {
    throw Exception('Usuario no autenticado');
  }
  
  return userRepository.getPendingUsers(requestingUser: currentUser);
});

/// Provider para estadísticas de usuarios
final userStatsProvider = FutureProvider<UserStats>((ref) async {
  final userRepository = ref.watch(userRepositoryProvider);
  final currentUser = await ref.watch(currentUserProvider.future);
  
  if (currentUser == null) {
    throw Exception('Usuario no autenticado');
  }
  
  return userRepository.getUserStats(requestingUser: currentUser);
});

/// Provider del controlador de usuarios
final userControllerProvider = StateNotifierProvider<UserController, UserState>((ref) {
  final userRepository = ref.watch(userRepositoryProvider);
  return UserController(userRepository, ref);
});

/// Estado del controlador de usuarios
class UserState {
  final bool isLoading;
  final String? error;
  final String? successMessage;
  final List<AppUser> users;
  final AppUser? selectedUser;
  final UserFilters filters;

  const UserState({
    this.isLoading = false,
    this.error,
    this.successMessage,
    this.users = const [],
    this.selectedUser,
    this.filters = const UserFilters(),
  });

  UserState copyWith({
    bool? isLoading,
    String? error,
    String? successMessage,
    List<AppUser>? users,
    AppUser? selectedUser,
    UserFilters? filters,
  }) {
    return UserState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      successMessage: successMessage,
      users: users ?? this.users,
      selectedUser: selectedUser ?? this.selectedUser,
      filters: filters ?? this.filters,
    );
  }
}

/// Filtros para búsqueda de usuarios
class UserFilters {
  final UserRole? role;
  final UserStatus? status;
  final Sede? sede;
  final String? searchTerm;

  const UserFilters({
    this.role,
    this.status,
    this.sede,
    this.searchTerm,
  });

  UserFilters copyWith({
    UserRole? role,
    UserStatus? status,
    Sede? sede,
    String? searchTerm,
    bool clearRole = false,
    bool clearStatus = false,
    bool clearSede = false,
    bool clearSearch = false,
  }) {
    return UserFilters(
      role: clearRole ? null : (role ?? this.role),
      status: clearStatus ? null : (status ?? this.status),
      sede: clearSede ? null : (sede ?? this.sede),
      searchTerm: clearSearch ? null : (searchTerm ?? this.searchTerm),
    );
  }

  bool get hasFilters => role != null || status != null || sede != null || (searchTerm != null && searchTerm!.isNotEmpty);
}

/// Controlador de usuarios
class UserController extends StateNotifier<UserState> {
  final UserRepository _userRepository;
  final Ref _ref;

  UserController(this._userRepository, this._ref) : super(const UserState());

  /// Obtiene el usuario actual autenticado
  Future<AppUser?> _getCurrentUser() async {
    return _ref.read(currentUserProvider.future);
  }

  /// Carga usuarios según los filtros actuales
  Future<void> loadUsers({
    UserRole? role,
    UserStatus? status,
    Sede? sede,
  }) async {
    state = state.copyWith(isLoading: true, error: null, successMessage: null);

    try {
      final currentUser = await _getCurrentUser();
      if (currentUser == null) {
        throw Exception('Usuario no autenticado');
      }

      final users = await _userRepository.getAllUsers(
        requestingUser: currentUser,
        filterRole: role,
        filterStatus: status,
        filterSede: sede,
      );

      state = state.copyWith(
        isLoading: false,
        users: users,
        filters: UserFilters(role: role, status: status, sede: sede),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  /// Aplica filtros a la lista de usuarios
  Future<void> applyFilters(UserFilters filters) async {
    await loadUsers(
      role: filters.role,
      status: filters.status,
      sede: filters.sede,
    );
  }

  /// Limpia todos los filtros
  Future<void> clearFilters() async {
    await loadUsers();
  }

  /// Crea un nuevo usuario
  Future<bool> createUser({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
    required Sede sede,
    required String phone,
  }) async {
    state = state.copyWith(isLoading: true, error: null, successMessage: null);

    try {
      final currentUser = await _getCurrentUser();
      if (currentUser == null) {
        throw Exception('Usuario no autenticado');
      }

      // Verificar permisos
      if (!currentUser.canCreateUserWithRole(role)) {
        throw Exception('No tienes permisos para crear usuarios con este rol');
      }

      // Supervisor solo puede crear usuarios de su sede
      if (currentUser.role.isSupervisor && currentUser.sede != sede) {
        throw Exception('Solo puedes crear usuarios para tu sede');
      }

      await _userRepository.createUserViaFunction(
        email: email,
        password: password,
        fullName: fullName,
        role: role,
        sede: sede,
        phone: phone,
        createdById: currentUser.id,
      );

      // Recargar lista de usuarios
      await loadUsers(
        role: state.filters.role,
        status: state.filters.status,
        sede: state.filters.sede,
      );

      state = state.copyWith(
        successMessage: 'Usuario creado exitosamente. Se enviarán las credenciales al correo.',
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  /// Actualiza el perfil de un usuario
  Future<bool> updateUserProfile({
    required String userId,
    String? fullName,
    String? phone,
    Sede? sede,
    UserRole? role,
  }) async {
    state = state.copyWith(isLoading: true, error: null, successMessage: null);

    try {
      final currentUser = await _getCurrentUser();
      if (currentUser == null) {
        throw Exception('Usuario no autenticado');
      }

      final updatedUser = await _userRepository.updateUserProfile(
        userId: userId,
        fullName: fullName,
        phone: phone,
        sede: sede,
        role: role,
      );

      // Actualizar el usuario en la lista
      final updatedUsers = state.users.map((user) {
        return user.id == userId ? updatedUser : user;
      }).toList();

      state = state.copyWith(
        isLoading: false,
        users: updatedUsers,
        selectedUser: updatedUser,
        successMessage: 'Usuario actualizado exitosamente',
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  /// Actualiza el estado de un usuario
  Future<bool> updateUserStatus(String userId, UserStatus status) async {
    state = state.copyWith(isLoading: true, error: null, successMessage: null);

    try {
      final updatedUser = await _userRepository.updateUserStatus(userId, status);

      // Actualizar el usuario en la lista
      final updatedUsers = state.users.map((user) {
        return user.id == userId ? updatedUser : user;
      }).toList();

      String message;
      switch (status) {
        case UserStatus.active:
          message = 'Usuario activado exitosamente';
          break;
        case UserStatus.inactive:
          message = 'Usuario desactivado exitosamente';
          break;
        case UserStatus.rejected:
          message = 'Usuario rechazado exitosamente';
          break;
        case UserStatus.pending:
          message = 'Estado actualizado';
          break;
      }

      state = state.copyWith(
        isLoading: false,
        users: updatedUsers,
        selectedUser: updatedUser,
        successMessage: message,
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  /// Aprueba un usuario pendiente
  Future<bool> approveUser(String userId) async {
    return updateUserStatus(userId, UserStatus.active);
  }

  /// Rechaza un usuario pendiente
  Future<bool> rejectUser(String userId) async {
    return updateUserStatus(userId, UserStatus.rejected);
  }

  /// Desactiva un usuario
  Future<bool> deactivateUser(String userId) async {
    return updateUserStatus(userId, UserStatus.inactive);
  }

  /// Reactiva un usuario
  Future<bool> reactivateUser(String userId) async {
    return updateUserStatus(userId, UserStatus.active);
  }

  /// Actualiza el rol de un usuario
  Future<bool> updateUserRole(String userId, UserRole role) async {
    state = state.copyWith(isLoading: true, error: null, successMessage: null);

    try {
      final updatedUser = await _userRepository.updateUserRole(userId, role);

      // Actualizar el usuario en la lista
      final updatedUsers = state.users.map((user) {
        return user.id == userId ? updatedUser : user;
      }).toList();

      state = state.copyWith(
        isLoading: false,
        users: updatedUsers,
        selectedUser: updatedUser,
        successMessage: 'Rol actualizado exitosamente',
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  /// Elimina un usuario
  Future<bool> deleteUser(String userId) async {
    state = state.copyWith(isLoading: true, error: null, successMessage: null);

    try {
      await _userRepository.deleteUser(userId);

      // Eliminar el usuario de la lista
      final updatedUsers = state.users.where((user) => user.id != userId).toList();

      state = state.copyWith(
        isLoading: false,
        users: updatedUsers,
        successMessage: 'Usuario eliminado exitosamente',
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  /// Busca usuarios por término
  Future<void> searchUsers(String searchTerm) async {
    state = state.copyWith(isLoading: true, error: null, successMessage: null);

    try {
      final currentUser = await _getCurrentUser();
      if (currentUser == null) {
        throw Exception('Usuario no autenticado');
      }

      if (searchTerm.isEmpty) {
        await loadUsers();
        return;
      }

      final users = await _userRepository.searchUsers(
        searchTerm: searchTerm,
        requestingUser: currentUser,
      );

      state = state.copyWith(
        isLoading: false,
        users: users,
        filters: state.filters.copyWith(searchTerm: searchTerm),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  /// Selecciona un usuario para ver detalles
  void selectUser(AppUser user) {
    state = state.copyWith(selectedUser: user);
  }

  /// Obtiene un usuario por ID y lo selecciona
  Future<void> getUserById(String userId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final user = await _userRepository.getUserById(userId);
      state = state.copyWith(
        isLoading: false,
        selectedUser: user,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  /// Envía correo de recuperación de contraseña
  Future<bool> sendPasswordReset(String email) async {
    state = state.copyWith(isLoading: true, error: null, successMessage: null);

    try {
      await _userRepository.resetUserPassword(email);

      state = state.copyWith(
        isLoading: false,
        successMessage: 'Correo de recuperación enviado',
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  /// Limpia el error
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Limpia el mensaje de éxito
  void clearSuccessMessage() {
    state = state.copyWith(successMessage: null);
  }

  /// Limpia el usuario seleccionado
  void clearSelectedUser() {
    state = state.copyWith(selectedUser: null);
  }
}
