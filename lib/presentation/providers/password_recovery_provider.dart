import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

/// Provider para generar enlaces de recuperación de contraseña
final generatePasswordLinkProvider = FutureProvider.family<String, String>((ref, email) async {
  final authRepository = ref.watch(authRepositoryProvider);
  return authRepository.generatePasswordRecoveryLink(email);
});
