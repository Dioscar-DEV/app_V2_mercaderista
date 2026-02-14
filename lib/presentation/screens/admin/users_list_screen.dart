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

/// Pantalla de gestión de usuarios
class UsersListScreen extends ConsumerStatefulWidget {
  const UsersListScreen({super.key});

  @override
  ConsumerState<UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends ConsumerState<UsersListScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    // Cargar usuarios al iniciar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(userControllerProvider.notifier).loadUsers();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(userControllerProvider);
    final currentUserAsync = ref.watch(currentUserProvider);

    // Escuchar mensajes de éxito/error
    ref.listen<UserState>(userControllerProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: Colors.red,
          ),
        );
        ref.read(userControllerProvider.notifier).clearError();
      }
      if (next.successMessage != null && next.successMessage != previous?.successMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.successMessage!),
            backgroundColor: Colors.green,
          ),
        );
        ref.read(userControllerProvider.notifier).clearSuccessMessage();
      }
    });

    return currentUserAsync.when(
      data: (currentUser) {
        if (currentUser == null) {
          return const Scaffold(
            body: Center(child: Text('No autorizado')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Gestión de Usuarios'),
            actions: [
              IconButton(
                icon: Icon(_showFilters ? Icons.filter_list_off : Icons.filter_list),
                onPressed: () {
                  setState(() {
                    _showFilters = !_showFilters;
                  });
                },
                tooltip: 'Filtros',
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  ref.read(userControllerProvider.notifier).loadUsers();
                },
                tooltip: 'Actualizar',
              ),
            ],
          ),
          body: LoadingOverlay(
            isLoading: userState.isLoading,
            child: Column(
              children: [
                // Barra de búsqueda
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar por nombre o correo...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                ref.read(userControllerProvider.notifier).loadUsers();
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                    ),
                    onSubmitted: (value) {
                      if (value.isNotEmpty) {
                        ref.read(userControllerProvider.notifier).searchUsers(value);
                      }
                    },
                  ),
                ),

                // Panel de filtros
                if (_showFilters)
                  _FiltersPanel(
                    currentUser: currentUser,
                    currentFilters: userState.filters,
                    onApplyFilters: (filters) {
                      ref.read(userControllerProvider.notifier).applyFilters(filters);
                    },
                  ),

                // Estadísticas rápidas
                _QuickStats(users: userState.users),

                // Lista de usuarios
                Expanded(
                  child: userState.users.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.people_outline,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No se encontraron usuarios',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () async {
                            await ref.read(userControllerProvider.notifier).loadUsers();
                          },
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: userState.users.length,
                            itemBuilder: (context, index) {
                              final user = userState.users[index];
                              return _UserCard(
                                user: user,
                                currentUser: currentUser,
                                onTap: () => context.push('/admin/users/${user.id}'),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
          ),
          floatingActionButton: currentUser.role.canManageUsers
              ? FloatingActionButton.extended(
                  onPressed: () => context.push('/admin/users/create'),
                  icon: const Icon(Icons.person_add),
                  label: const Text('Nuevo Usuario'),
                )
              : null,
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        body: Center(child: Text('Error: $error')),
      ),
    );
  }
}

/// Panel de filtros
class _FiltersPanel extends StatefulWidget {
  final AppUser currentUser;
  final UserFilters currentFilters;
  final Function(UserFilters) onApplyFilters;

  const _FiltersPanel({
    required this.currentUser,
    required this.currentFilters,
    required this.onApplyFilters,
  });

  @override
  State<_FiltersPanel> createState() => _FiltersPanelState();
}

class _FiltersPanelState extends State<_FiltersPanel> {
  UserRole? _selectedRole;
  UserStatus? _selectedStatus;
  Sede? _selectedSede;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.currentFilters.role;
    _selectedStatus = widget.currentFilters.status;
    _selectedSede = widget.currentFilters.sede;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.filter_alt, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Filtros',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedRole = null;
                    _selectedStatus = null;
                    _selectedSede = null;
                  });
                  widget.onApplyFilters(const UserFilters());
                },
                child: const Text('Limpiar'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // Filtro por rol
              DropdownButton<UserRole?>(
                value: _selectedRole,
                hint: const Text('Rol'),
                underline: const SizedBox(),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Todos los roles')),
                  ...UserRole.values.map((role) => DropdownMenuItem(
                        value: role,
                        child: Text(role.displayName),
                      )),
                ],
                onChanged: (value) {
                  setState(() => _selectedRole = value);
                  _applyFilters();
                },
              ),

              // Filtro por estado
              DropdownButton<UserStatus?>(
                value: _selectedStatus,
                hint: const Text('Estado'),
                underline: const SizedBox(),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Todos los estados')),
                  ...UserStatus.values.map((status) => DropdownMenuItem(
                        value: status,
                        child: Text(status.displayName),
                      )),
                ],
                onChanged: (value) {
                  setState(() => _selectedStatus = value);
                  _applyFilters();
                },
              ),

              // Filtro por sede (solo para owners)
              if (widget.currentUser.role.canViewAllSedes)
                DropdownButton<Sede?>(
                  value: _selectedSede,
                  hint: const Text('Sede'),
                  underline: const SizedBox(),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Todas las sedes')),
                    ...Sede.values.map((sede) => DropdownMenuItem(
                          value: sede,
                          child: Text(sede.displayName),
                        )),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedSede = value);
                    _applyFilters();
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _applyFilters() {
    widget.onApplyFilters(UserFilters(
      role: _selectedRole,
      status: _selectedStatus,
      sede: _selectedSede,
    ));
  }
}

/// Estadísticas rápidas
class _QuickStats extends StatelessWidget {
  final List<AppUser> users;

  const _QuickStats({required this.users});

  @override
  Widget build(BuildContext context) {
    final active = users.where((u) => u.status == UserStatus.active).length;
    final pending = users.where((u) => u.status == UserStatus.pending).length;
    final inactive = users.where((u) => u.status == UserStatus.inactive || u.status == UserStatus.rejected).length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _StatChip(
            label: 'Total',
            count: users.length,
            color: Colors.blue,
          ),
          const SizedBox(width: 8),
          _StatChip(
            label: 'Activos',
            count: active,
            color: Colors.green,
          ),
          const SizedBox(width: 8),
          _StatChip(
            label: 'Pendientes',
            count: pending,
            color: Colors.orange,
          ),
          const SizedBox(width: 8),
          _StatChip(
            label: 'Inactivos',
            count: inactive,
            color: Colors.grey,
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatChip({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              count.toString(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta de usuario
class _UserCard extends StatelessWidget {
  final AppUser user;
  final AppUser currentUser;
  final VoidCallback onTap;

  const _UserCard({
    required this.user,
    required this.currentUser,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: _getRoleColor(user.role).withOpacity(0.2),
                backgroundImage: user.avatarUrl != null
                    ? NetworkImage(user.avatarUrl!)
                    : null,
                child: user.avatarUrl == null
                    ? Text(
                        user.initials,
                        style: TextStyle(
                          color: _getRoleColor(user.role),
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),

              // Información del usuario
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            user.fullName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _StatusBadge(status: user.status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _RoleBadge(role: user.role),
                        if (user.sede != null) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              user.sede!.displayName,
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Flecha
              Icon(
                Icons.chevron_right,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
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

/// Badge de estado
class _StatusBadge extends StatelessWidget {
  final UserStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String text;

    switch (status) {
      case UserStatus.active:
        color = Colors.green;
        text = 'Activo';
        break;
      case UserStatus.pending:
        color = Colors.orange;
        text = 'Pendiente';
        break;
      case UserStatus.rejected:
        color = Colors.red;
        text = 'Rechazado';
        break;
      case UserStatus.inactive:
        color = Colors.grey;
        text = 'Inactivo';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// Badge de rol
class _RoleBadge extends StatelessWidget {
  final UserRole role;

  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;

    switch (role) {
      case UserRole.owner:
        color = Colors.purple;
        icon = Icons.admin_panel_settings;
        break;
      case UserRole.supervisor:
        color = Colors.blue;
        icon = Icons.supervisor_account;
        break;
      case UserRole.mercaderista:
        color = Colors.teal;
        icon = Icons.person;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            role.displayName,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
