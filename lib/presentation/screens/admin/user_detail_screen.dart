import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/enums/user_role.dart';
import '../../../core/enums/user_status.dart';
import '../../../core/enums/sede.dart';
import '../../../core/models/user.dart';
import '../../providers/user_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/loading_overlay.dart';

/// Pantalla de detalle y edición de usuario
class UserDetailScreen extends ConsumerStatefulWidget {
  final String userId;

  const UserDetailScreen({super.key, required this.userId});

  @override
  ConsumerState<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends ConsumerState<UserDetailScreen> {
  bool _isEditing = false;
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  UserRole? _selectedRole;
  Sede? _selectedSede;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    
    // Cargar datos del usuario
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(userControllerProvider.notifier).getUserById(widget.userId);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _initializeForm(AppUser user) {
    _nameController.text = user.fullName;
    _phoneController.text = user.phone ?? '';
    _selectedRole = user.role;
    _selectedSede = user.sede;
  }

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(userControllerProvider);
    final currentUserAsync = ref.watch(currentUserProvider);

    // Escuchar cambios
    ref.listen<UserState>(userControllerProvider, (previous, next) {
      // Inicializar form cuando se carga el usuario
      if (next.selectedUser != null && previous?.selectedUser?.id != next.selectedUser?.id) {
        _initializeForm(next.selectedUser!);
      }

      if (next.error != null && next.error != previous?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!), backgroundColor: Colors.red),
        );
        ref.read(userControllerProvider.notifier).clearError();
      }

      if (next.successMessage != null && next.successMessage != previous?.successMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.successMessage!), backgroundColor: Colors.green),
        );
        ref.read(userControllerProvider.notifier).clearSuccessMessage();
        
        if (_isEditing) {
          setState(() => _isEditing = false);
        }
      }
    });

    final selectedUser = userState.selectedUser;

    return currentUserAsync.when(
      data: (currentUser) {
        if (currentUser == null) {
          return const Scaffold(body: Center(child: Text('No autorizado')));
        }

        final canEdit = selectedUser != null && currentUser.canManageUser(selectedUser);

        return Scaffold(
          appBar: AppBar(
            title: Text(_isEditing ? 'Editar Usuario' : 'Detalle de Usuario'),
            actions: [
              if (canEdit && !_isEditing)
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => setState(() => _isEditing = true),
                  tooltip: 'Editar',
                ),
              if (_isEditing)
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() => _isEditing = false);
                    if (selectedUser != null) _initializeForm(selectedUser);
                  },
                  tooltip: 'Cancelar',
                ),
            ],
          ),
          body: LoadingOverlay(
            isLoading: userState.isLoading,
            child: selectedUser == null
                ? const Center(child: CircularProgressIndicator())
                : _isEditing
                    ? _buildEditForm(context, selectedUser, currentUser)
                    : _buildDetailView(context, selectedUser, currentUser),
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(body: Center(child: Text('Error: $error'))),
    );
  }

  Widget _buildDetailView(BuildContext context, AppUser user, AppUser currentUser) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header con avatar
          _UserHeader(user: user),
          const SizedBox(height: 24),

          // Información personal
          _InfoSection(
            title: 'Información Personal',
            icon: Icons.person,
            children: [
              _InfoRow(label: 'Nombre completo', value: user.fullName),
              _InfoRow(label: 'Correo electrónico', value: user.email),
              _InfoRow(label: 'Teléfono', value: user.phone ?? 'No registrado'),
            ],
          ),
          const SizedBox(height: 16),

          // Información laboral
          _InfoSection(
            title: 'Información Laboral',
            icon: Icons.work,
            children: [
              _InfoRow(label: 'Rol', value: user.role.displayName),
              _InfoRow(label: 'Sede', value: user.sede?.displayName ?? 'No asignada'),
              _InfoRow(label: 'Región', value: user.region?.displayName ?? 'No asignada'),
              _InfoRow(label: 'Estado', value: user.status.displayName, valueColor: _getStatusColor(user.status)),
            ],
          ),
          const SizedBox(height: 16),

          // Información del sistema
          _InfoSection(
            title: 'Información del Sistema',
            icon: Icons.info_outline,
            children: [
              _InfoRow(label: 'Fecha de registro', value: _formatDate(user.createdAt)),
              if (user.updatedAt != null)
                _InfoRow(label: 'Última actualización', value: _formatDate(user.updatedAt!)),
            ],
          ),
          const SizedBox(height: 24),

          // Acciones
          if (currentUser.canManageUser(user))
            _ActionsSection(user: user, currentUser: currentUser),
        ],
      ),
    );
  }

  Widget _buildEditForm(BuildContext context, AppUser user, AppUser currentUser) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nombre
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre completo *',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'El nombre es requerido';
                }
                if (value.length < 3) {
                  return 'El nombre debe tener al menos 3 caracteres';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Teléfono
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Teléfono',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
                hintText: '+58 412 1234567',
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),

            // Rol (solo si el usuario actual puede cambiar el rol)
            if (currentUser.role.isOwner || 
                (currentUser.role.isSupervisor && user.role.isMercaderista))
              DropdownButtonFormField<UserRole>(
                value: _selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Rol *',
                  prefixIcon: Icon(Icons.badge),
                  border: OutlineInputBorder(),
                ),
                items: currentUser.role.creatableRoles
                    .map((role) => DropdownMenuItem(
                          value: role,
                          child: Text(role.displayName),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _selectedRole = value),
                validator: (value) {
                  if (value == null) {
                    return 'Seleccione un rol';
                  }
                  return null;
                },
              ),
            const SizedBox(height: 16),

            // Sede (solo si es owner)
            if (currentUser.role.isOwner)
              DropdownButtonFormField<Sede>(
                value: _selectedSede,
                decoration: const InputDecoration(
                  labelText: 'Sede *',
                  prefixIcon: Icon(Icons.business),
                  border: OutlineInputBorder(),
                ),
                items: Sede.values
                    .map((sede) => DropdownMenuItem(
                          value: sede,
                          child: Text('${sede.displayName} (${sede.region.displayName})'),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _selectedSede = value),
                validator: (value) {
                  if (value == null) {
                    return 'Seleccione una sede';
                  }
                  return null;
                },
              ),
            const SizedBox(height: 32),

            // Botón guardar
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _saveChanges,
                icon: const Icon(Icons.save),
                label: const Text('Guardar Cambios'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    await ref.read(userControllerProvider.notifier).updateUserProfile(
      userId: widget.userId,
      fullName: _nameController.text.trim(),
      phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      role: _selectedRole,
      sede: _selectedSede,
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Color _getStatusColor(UserStatus status) {
    switch (status) {
      case UserStatus.active:
        return Colors.green;
      case UserStatus.pending:
        return Colors.orange;
      case UserStatus.rejected:
        return Colors.red;
      case UserStatus.inactive:
        return Colors.grey;
    }
  }
}

/// Header con avatar del usuario
class _UserHeader extends StatelessWidget {
  final AppUser user;

  const _UserHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: _getRoleColor(user.role).withOpacity(0.2),
          backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
          child: user.avatarUrl == null
              ? Text(
                  user.initials,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: _getRoleColor(user.role),
                  ),
                )
              : null,
        ),
        const SizedBox(height: 12),
        Text(
          user.fullName,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: _getRoleColor(user.role).withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            user.role.displayName,
            style: TextStyle(
              color: _getRoleColor(user.role),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.owner:
        return Colors.purple;
      case UserRole.supervisor:
        return Colors.blue;
      case UserRole.mercaderista:
        return Colors.teal;
    }
  }
}

/// Sección de información
class _InfoSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _InfoSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Fila de información
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sección de acciones
class _ActionsSection extends ConsumerWidget {
  final AppUser user;
  final AppUser currentUser;

  const _ActionsSection({
    required this.user,
    required this.currentUser,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.settings, size: 20),
                SizedBox(width: 8),
                Text(
                  'Acciones',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(),
            
            // Aprobar usuario pendiente
            if (user.status == UserStatus.pending)
              ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: const Text('Aprobar usuario'),
                subtitle: const Text('Activar la cuenta del usuario'),
                onTap: () => _showConfirmDialog(
                  context,
                  ref,
                  '¿Aprobar este usuario?',
                  'El usuario podrá acceder a la aplicación',
                  () => ref.read(userControllerProvider.notifier).approveUser(user.id),
                ),
              ),

            // Rechazar usuario pendiente
            if (user.status == UserStatus.pending)
              ListTile(
                leading: const Icon(Icons.cancel, color: Colors.red),
                title: const Text('Rechazar usuario'),
                subtitle: const Text('Denegar el acceso al usuario'),
                onTap: () => _showConfirmDialog(
                  context,
                  ref,
                  '¿Rechazar este usuario?',
                  'El usuario no podrá acceder a la aplicación',
                  () => ref.read(userControllerProvider.notifier).rejectUser(user.id),
                ),
              ),

            // Desactivar usuario activo
            if (user.status == UserStatus.active)
              ListTile(
                leading: const Icon(Icons.block, color: Colors.orange),
                title: const Text('Desactivar usuario'),
                subtitle: const Text('Suspender temporalmente el acceso'),
                onTap: () => _showConfirmDialog(
                  context,
                  ref,
                  '¿Desactivar este usuario?',
                  'El usuario no podrá acceder hasta ser reactivado',
                  () => ref.read(userControllerProvider.notifier).deactivateUser(user.id),
                ),
              ),

            // Reactivar usuario inactivo
            if (user.status == UserStatus.inactive || user.status == UserStatus.rejected)
              ListTile(
                leading: const Icon(Icons.refresh, color: Colors.green),
                title: const Text('Reactivar usuario'),
                subtitle: const Text('Restaurar el acceso del usuario'),
                onTap: () => _showConfirmDialog(
                  context,
                  ref,
                  '¿Reactivar este usuario?',
                  'El usuario podrá acceder nuevamente',
                  () => ref.read(userControllerProvider.notifier).reactivateUser(user.id),
                ),
              ),

            // Enviar recuperación de contraseña
            ListTile(
              leading: const Icon(Icons.lock_reset, color: Colors.blue),
              title: const Text('Restablecer contraseña'),
              subtitle: const Text('Enviar correo de recuperación'),
              onTap: () => _showConfirmDialog(
                context,
                ref,
                '¿Enviar correo de recuperación?',
                'Se enviará un enlace al correo ${user.email}',
                () => ref.read(userControllerProvider.notifier).sendPasswordReset(user.email),
              ),
            ),

            // Eliminar usuario (solo owners y con precaución)
            if (currentUser.role.isOwner && user.id != currentUser.id)
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text('Eliminar usuario'),
                subtitle: const Text('Esta acción no se puede deshacer'),
                onTap: () => _showDeleteDialog(context, ref),
              ),
          ],
        ),
      ),
    );
  }

  void _showConfirmDialog(
    BuildContext context,
    WidgetRef ref,
    String title,
    String message,
    Future<void> Function() action,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              action();
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar usuario?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Esta acción eliminará permanentemente:'),
            const SizedBox(height: 8),
            Text('• ${user.fullName}'),
            Text('• ${user.email}'),
            const SizedBox(height: 16),
            const Text(
              '¡Esta acción no se puede deshacer!',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              ref.read(userControllerProvider.notifier).deleteUser(user.id).then((success) {
                if (success && context.mounted) {
                  context.pop();
                }
              });
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}
