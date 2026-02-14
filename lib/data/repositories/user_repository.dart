import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/supabase_config.dart';
import '../../core/models/user.dart';
import '../../core/enums/user_status.dart';
import '../../core/enums/user_role.dart';
import '../../core/enums/sede.dart';

/// Repositorio para operaciones con usuarios
class UserRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  /// Obtiene un usuario por su ID
  Future<AppUser> getUserById(String userId) async {
    try {
      final data = await _client
          .from('users')
          .select()
          .eq('id', userId)
          .single();

      return AppUser.fromJson(data);
    } catch (e) {
      throw Exception('Error al obtener usuario: $e');
    }
  }

  /// Crea un nuevo usuario (solo para owners y supervisores)
  /// 
  /// Este método utiliza las Edge Functions de Supabase para crear
  /// el usuario en auth y en la tabla users
  Future<AppUser> createUser({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
    required Sede sede,
    required String phone,
    required String createdById,
  }) async {
    try {
      // Crear usuario en Supabase Auth usando la función administrativa
      final authResponse = await _client.auth.admin.createUser(
        AdminUserAttributes(
          email: email,
          password: password,
          emailConfirm: true,
          userMetadata: {
            'full_name': fullName,
          },
        ),
      );

      if (authResponse.user == null) {
        throw Exception('No se pudo crear el usuario en autenticación');
      }

      final userId = authResponse.user!.id;

      // Crear registro en la tabla users
      final userData = {
        'id': userId,
        'email': email,
        'full_name': fullName,
        'role': role.value,
        'sede': sede.value,
        'region': sede.region.value,
        'phone': phone,
        'status': UserStatus.active.value, // Usuarios creados por admin están activos
        'created_at': DateTime.now().toIso8601String(),
        'created_by': createdById,
      };

      await _client.from('users').insert(userData);

      return getUserById(userId);
    } on AuthException catch (e) {
      if (e.message.contains('already registered')) {
        throw Exception('El correo electrónico ya está registrado');
      }
      throw Exception('Error de autenticación: ${e.message}');
    } catch (e) {
      throw Exception('Error al crear usuario: $e');
    }
  }

  /// Crea un usuario usando una edge function personalizada
  /// Usar este método si no tienes acceso admin
  Future<AppUser> createUserViaFunction({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
    required Sede sede,
    required String phone,
    required String createdById,
  }) async {
    try {
      // Llamar a la edge function para crear usuario
      final response = await _client.functions.invoke(
        'create-user',
        body: {
          'email': email,
          'password': password,
          'full_name': fullName,
          'role': role.value,
          'sede': sede.value,
          'region': sede.region.value,
          'phone': phone,
          'created_by': createdById,
        },
      );

      if (response.status != 200) {
        final error = response.data?['error'] ?? 'Error desconocido';
        throw Exception(error);
      }

      final userId = response.data['user_id'] as String;
      return getUserById(userId);
    } catch (e) {
      throw Exception('Error al crear usuario: $e');
    }
  }

  /// Obtiene todos los usuarios según los permisos del solicitante
  /// 
  /// - Owner: puede ver todos los usuarios de todas las sedes
  /// - Supervisor: solo puede ver usuarios de su sede
  Future<List<AppUser>> getAllUsers({
    required AppUser requestingUser,
    UserRole? filterRole,
    UserStatus? filterStatus,
    Sede? filterSede,
  }) async {
    try {
      var query = _client.from('users').select();

      // Si es supervisor, filtrar por su sede
      if (requestingUser.role.isSupervisor && requestingUser.sede != null) {
        query = query.eq('sede', requestingUser.sede!.value);
      }

      // Aplicar filtros adicionales
      if (filterRole != null) {
        query = query.eq('role', filterRole.value);
      }
      if (filterStatus != null) {
        query = query.eq('status', filterStatus.value);
      }
      if (filterSede != null && requestingUser.role.isOwner) {
        // Solo owner puede filtrar por sede diferente a la suya
        query = query.eq('sede', filterSede.value);
      }

      final data = await query.order('created_at', ascending: false);

      return (data as List).map((json) => AppUser.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Error al obtener usuarios: $e');
    }
  }

  /// Obtiene usuarios pendientes de aprobación
  Future<List<AppUser>> getPendingUsers({required AppUser requestingUser}) async {
    return getAllUsers(
      requestingUser: requestingUser,
      filterStatus: UserStatus.pending,
    );
  }

  /// Actualiza los datos de un usuario
  Future<AppUser> updateUser(String userId, Map<String, dynamic> updates) async {
    try {
      // Agregar timestamp de actualización
      updates['updated_at'] = DateTime.now().toIso8601String();

      await _client
          .from('users')
          .update(updates)
          .eq('id', userId);

      return getUserById(userId);
    } catch (e) {
      throw Exception('Error al actualizar usuario: $e');
    }
  }

  /// Actualiza el perfil completo de un usuario (para admin)
  Future<AppUser> updateUserProfile({
    required String userId,
    String? fullName,
    String? phone,
    Sede? sede,
    UserRole? role,
  }) async {
    try {
      final updates = <String, dynamic>{};

      if (fullName != null) updates['full_name'] = fullName;
      if (phone != null) updates['phone'] = phone;
      if (sede != null) {
        updates['sede'] = sede.value;
        updates['region'] = sede.region.value;
      }
      if (role != null) updates['role'] = role.value;

      return updateUser(userId, updates);
    } catch (e) {
      throw Exception('Error al actualizar perfil: $e');
    }
  }

  /// Actualiza el estado de un usuario
  Future<AppUser> updateUserStatus(String userId, UserStatus status) async {
    try {
      return updateUser(userId, {'status': status.value});
    } catch (e) {
      throw Exception('Error al actualizar estado del usuario: $e');
    }
  }

  /// Aprueba un usuario pendiente
  Future<AppUser> approveUser(String userId) async {
    return updateUserStatus(userId, UserStatus.active);
  }

  /// Rechaza un usuario pendiente
  Future<AppUser> rejectUser(String userId) async {
    return updateUserStatus(userId, UserStatus.rejected);
  }

  /// Desactiva un usuario
  Future<AppUser> deactivateUser(String userId) async {
    return updateUserStatus(userId, UserStatus.inactive);
  }

  /// Reactiva un usuario inactivo
  Future<AppUser> reactivateUser(String userId) async {
    return updateUserStatus(userId, UserStatus.active);
  }

  /// Actualiza el rol de un usuario (solo admin)
  Future<AppUser> updateUserRole(String userId, UserRole role) async {
    try {
      return updateUser(userId, {'role': role.value});
    } catch (e) {
      throw Exception('Error al actualizar rol del usuario: $e');
    }
  }

  /// Elimina un usuario (solo admin)
  Future<void> deleteUser(String userId) async {
    try {
      // Primero eliminar de la tabla users
      await _client
          .from('users')
          .delete()
          .eq('id', userId);
      
      // Nota: La eliminación del auth.users requiere admin API
      // o una edge function
    } catch (e) {
      throw Exception('Error al eliminar usuario: $e');
    }
  }

  /// Actualiza el avatar del usuario
  Future<AppUser> updateAvatar(String userId, String avatarUrl) async {
    try {
      return updateUser(userId, {'avatar_url': avatarUrl});
    } catch (e) {
      throw Exception('Error al actualizar avatar: $e');
    }
  }

  /// Obtiene usuarios mercaderistas activos
  Future<List<AppUser>> getActiveMercaderistas({
    required AppUser requestingUser,
  }) async {
    return getAllUsers(
      requestingUser: requestingUser,
      filterRole: UserRole.mercaderista,
      filterStatus: UserStatus.active,
    );
  }

  /// Busca usuarios por nombre o email
  Future<List<AppUser>> searchUsers({
    required String searchTerm,
    required AppUser requestingUser,
  }) async {
    try {
      var query = _client
          .from('users')
          .select()
          .or('full_name.ilike.%$searchTerm%,email.ilike.%$searchTerm%');

      // Si es supervisor, filtrar por su sede
      if (requestingUser.role.isSupervisor && requestingUser.sede != null) {
        query = query.eq('sede', requestingUser.sede!.value);
      }

      final data = await query.order('full_name', ascending: true);

      return (data as List).map((json) => AppUser.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Error al buscar usuarios: $e');
    }
  }

  /// Obtiene estadísticas de usuarios
  Future<UserStats> getUserStats({required AppUser requestingUser}) async {
    try {
      final users = await getAllUsers(requestingUser: requestingUser);
      
      int total = users.length;
      int active = 0;
      int pending = 0;
      int inactive = 0;
      int owners = 0;
      int supervisors = 0;
      int mercaderistas = 0;
      Map<String, int> bySede = {};

      for (final user in users) {
        // Por estado
        switch (user.status) {
          case UserStatus.active:
            active++;
            break;
          case UserStatus.pending:
            pending++;
            break;
          case UserStatus.inactive:
          case UserStatus.rejected:
            inactive++;
            break;
        }

        // Por rol
        switch (user.role) {
          case UserRole.owner:
            owners++;
            break;
          case UserRole.supervisor:
            supervisors++;
            break;
          case UserRole.mercaderista:
            mercaderistas++;
            break;
        }

        // Por sede
        if (user.sede != null) {
          final sedeName = user.sede!.displayName;
          bySede[sedeName] = (bySede[sedeName] ?? 0) + 1;
        }
      }

      return UserStats(
        total: total,
        active: active,
        pending: pending,
        inactive: inactive,
        owners: owners,
        supervisors: supervisors,
        mercaderistas: mercaderistas,
        bySede: bySede,
      );
    } catch (e) {
      throw Exception('Error al obtener estadísticas: $e');
    }
  }

  /// Restablece la contraseña de un usuario
  Future<void> resetUserPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
    } catch (e) {
      throw Exception('Error al enviar correo de recuperación: $e');
    }
  }
}

/// Clase para estadísticas de usuarios
class UserStats {
  final int total;
  final int active;
  final int pending;
  final int inactive;
  final int owners;
  final int supervisors;
  final int mercaderistas;
  final Map<String, int> bySede;

  const UserStats({
    required this.total,
    required this.active,
    required this.pending,
    required this.inactive,
    required this.owners,
    required this.supervisors,
    required this.mercaderistas,
    required this.bySede,
  });
}
