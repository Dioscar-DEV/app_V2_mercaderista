import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/enums/user_role.dart';
import '../../../core/enums/sede.dart';
import '../../providers/user_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/loading_overlay.dart';

/// Pantalla para crear un nuevo usuario
class CreateUserScreen extends ConsumerStatefulWidget {
  const CreateUserScreen({super.key});

  @override
  ConsumerState<CreateUserScreen> createState() => _CreateUserScreenState();
}

class _CreateUserScreenState extends ConsumerState<CreateUserScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  // Selections
  UserRole? _selectedRole;
  Sede? _selectedSede;
  
  // UI State
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  
  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(userControllerProvider);
    final currentUserAsync = ref.watch(currentUserProvider);

    // Escuchar cambios
    ref.listen<UserState>(userControllerProvider, (previous, next) {
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
        // Volver a la lista
        context.pop();
      }
    });

    return currentUserAsync.when(
      data: (currentUser) {
        if (currentUser == null || !currentUser.role.canManageUsers) {
          return const Scaffold(
            body: Center(child: Text('No tienes permisos para crear usuarios')),
          );
        }

        // Si es supervisor, preseleccionar su sede
        if (currentUser.role.isSupervisor && _selectedSede == null) {
          _selectedSede = currentUser.sede;
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Crear Usuario'),
          ),
          body: LoadingOverlay(
            isLoading: userState.isLoading,
            message: 'Creando usuario...',
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Información del formulario
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue[700]),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'El usuario recibirá un correo con las credenciales de acceso.',
                              style: TextStyle(color: Colors.blue[700]),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Sección: Datos Personales
                    _SectionTitle(title: 'Datos Personales', icon: Icons.person),
                    const SizedBox(height: 16),

                    // Nombre completo
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre completo *',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                        hintText: 'Ej: Juan Carlos Pérez',
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'El nombre es requerido';
                        }
                        if (value.trim().split(' ').length < 2) {
                          return 'Ingrese nombre y apellido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Correo electrónico
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Correo electrónico *',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                        hintText: 'usuario@empresa.com',
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'El correo es requerido';
                        }
                        final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                        if (!emailRegex.hasMatch(value)) {
                          return 'Ingrese un correo válido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Teléfono
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Teléfono *',
                        prefixIcon: Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(),
                        hintText: '+58 412 1234567',
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'El teléfono es requerido';
                        }
                        if (value.replaceAll(RegExp(r'[^\d]'), '').length < 10) {
                          return 'Ingrese un teléfono válido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Sección: Información Laboral
                    _SectionTitle(title: 'Información Laboral', icon: Icons.work),
                    const SizedBox(height: 16),

                    // Rol
                    DropdownButtonFormField<UserRole>(
                      value: _selectedRole,
                      decoration: const InputDecoration(
                        labelText: 'Rol *',
                        prefixIcon: Icon(Icons.badge_outlined),
                        border: OutlineInputBorder(),
                      ),
                      items: currentUser.role.creatableRoles
                          .map((role) => DropdownMenuItem(
                                value: role,
                                child: Row(
                                  children: [
                                    Icon(_getRoleIcon(role), size: 20, color: _getRoleColor(role)),
                                    const SizedBox(width: 8),
                                    Text(role.displayName),
                                  ],
                                ),
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

                    // Sede (deshabilitado para supervisores)
                    DropdownButtonFormField<Sede>(
                      value: _selectedSede,
                      decoration: InputDecoration(
                        labelText: 'Sede *',
                        prefixIcon: const Icon(Icons.business_outlined),
                        border: const OutlineInputBorder(),
                        enabled: currentUser.role.isOwner,
                      ),
                      items: currentUser.role.isOwner
                          ? Sede.values
                              .map((sede) => DropdownMenuItem(
                                    value: sede,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(sede.displayName),
                                        Text(
                                          sede.region.displayName,
                                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                        ),
                                      ],
                                    ),
                                  ))
                              .toList()
                          : [
                              if (currentUser.sede != null)
                                DropdownMenuItem(
                                  value: currentUser.sede,
                                  child: Text(currentUser.sede!.displayName),
                                )
                            ],
                      onChanged: currentUser.role.isOwner
                          ? (value) => setState(() => _selectedSede = value)
                          : null,
                      validator: (value) {
                        if (value == null) {
                          return 'Seleccione una sede';
                        }
                        return null;
                      },
                    ),
                    
                    // Mostrar estados de la sede seleccionada
                    if (_selectedSede != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Estados cubiertos:',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: _selectedSede!.estados
                                  .map((estado) => Chip(
                                        label: Text(estado, style: const TextStyle(fontSize: 12)),
                                        padding: EdgeInsets.zero,
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ))
                                  .toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),

                    // Sección: Credenciales
                    _SectionTitle(title: 'Credenciales de Acceso', icon: Icons.lock),
                    const SizedBox(height: 16),

                    // Contraseña
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Contraseña *',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        hintText: 'Mínimo 8 caracteres',
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'La contraseña es requerida';
                        }
                        if (value.length < 8) {
                          return 'Mínimo 8 caracteres';
                        }
                        if (!value.contains(RegExp(r'[A-Z]'))) {
                          return 'Debe contener al menos una mayúscula';
                        }
                        if (!value.contains(RegExp(r'[0-9]'))) {
                          return 'Debe contener al menos un número';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Confirmar contraseña
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      decoration: InputDecoration(
                        labelText: 'Confirmar contraseña *',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureConfirmPassword ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Confirme la contraseña';
                        }
                        if (value != _passwordController.text) {
                          return 'Las contraseñas no coinciden';
                        }
                        return null;
                      },
                    ),
                    
                    // Indicador de fortaleza de contraseña
                    const SizedBox(height: 8),
                    _PasswordStrengthIndicator(password: _passwordController.text),
                    
                    const SizedBox(height: 32),

                    // Botón crear
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: userState.isLoading ? null : _createUser,
                        icon: const Icon(Icons.person_add),
                        label: const Text('Crear Usuario'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(body: Center(child: Text('Error: $error'))),
    );
  }

  Future<void> _createUser() async {
    if (!_formKey.currentState!.validate()) return;

    await ref.read(userControllerProvider.notifier).createUser(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      fullName: _nameController.text.trim(),
      role: _selectedRole!,
      sede: _selectedSede!,
      phone: _phoneController.text.trim(),
    );
  }

  IconData _getRoleIcon(UserRole role) {
    switch (role) {
      case UserRole.owner:
        return Icons.admin_panel_settings;
      case UserRole.supervisor:
        return Icons.supervisor_account;
      case UserRole.mercaderista:
        return Icons.person;
    }
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

/// Título de sección
class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
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
    );
  }
}

/// Indicador de fortaleza de contraseña
class _PasswordStrengthIndicator extends StatelessWidget {
  final String password;

  const _PasswordStrengthIndicator({required this.password});

  @override
  Widget build(BuildContext context) {
    final strength = _calculateStrength();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: LinearProgressIndicator(
                value: strength.value,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation(strength.color),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              strength.label,
              style: TextStyle(
                color: strength.color,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Requisitos: 8+ caracteres, 1 mayúscula, 1 número',
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
      ],
    );
  }

  _PasswordStrength _calculateStrength() {
    if (password.isEmpty) {
      return _PasswordStrength(0, 'Sin contraseña', Colors.grey);
    }

    int score = 0;
    
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;
    if (password.contains(RegExp(r'[A-Z]'))) score++;
    if (password.contains(RegExp(r'[a-z]'))) score++;
    if (password.contains(RegExp(r'[0-9]'))) score++;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) score++;

    if (score <= 2) {
      return _PasswordStrength(0.25, 'Débil', Colors.red);
    } else if (score <= 4) {
      return _PasswordStrength(0.5, 'Media', Colors.orange);
    } else if (score <= 5) {
      return _PasswordStrength(0.75, 'Fuerte', Colors.lightGreen);
    } else {
      return _PasswordStrength(1.0, 'Muy fuerte', Colors.green);
    }
  }
}

class _PasswordStrength {
  final double value;
  final String label;
  final Color color;

  _PasswordStrength(this.value, this.label, this.color);
}
