import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/models/prospect.dart';
import '../../data/repositories/prospect_repository.dart';
import 'auth_provider.dart';

/// Provider del repositorio
final prospectRepositoryProvider = Provider<ProspectRepository>((ref) {
  return ProspectRepository();
});

/// Lista de mis prospectos
final myProspectsProvider = FutureProvider<List<Prospect>>((ref) async {
  final repo = ref.watch(prospectRepositoryProvider);
  return repo.getMyProspects();
});

/// Estado del formulario de prospecto
class ProspectFormState {
  final bool isLoading;
  final bool isSaved;
  final String? error;
  final String? photoPath; // local file path or URL
  final double? latitude;
  final double? longitude;
  final bool hasGps;

  const ProspectFormState({
    this.isLoading = false,
    this.isSaved = false,
    this.error,
    this.photoPath,
    this.latitude,
    this.longitude,
    this.hasGps = false,
  });

  ProspectFormState copyWith({
    bool? isLoading,
    bool? isSaved,
    String? error,
    String? photoPath,
    double? latitude,
    double? longitude,
    bool? hasGps,
  }) {
    return ProspectFormState(
      isLoading: isLoading ?? this.isLoading,
      isSaved: isSaved ?? this.isSaved,
      error: error ?? this.error,
      photoPath: photoPath ?? this.photoPath,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      hasGps: hasGps ?? this.hasGps,
    );
  }
}

/// Notifier del formulario
class ProspectFormNotifier extends StateNotifier<ProspectFormState> {
  final ProspectRepository _repository;
  final Ref _ref;

  ProspectFormNotifier(this._repository, this._ref) : super(const ProspectFormState());

  void setLocation(double lat, double lng) {
    state = state.copyWith(latitude: lat, longitude: lng, hasGps: true);
  }

  void setPhoto(String path) {
    state = state.copyWith(photoPath: path);
  }

  void clearError() {
    state = const ProspectFormState(); // Reset to default but keep nothing
  }

  Future<bool> submitProspect({
    required String name,
    String? rif,
    required String address,
    String? phone,
    String? contactPerson,
    bool inSitu = true,
    String? notes,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final currentUser = await _ref.read(currentUserProvider.future);
      if (currentUser == null) {
        state = state.copyWith(isLoading: false, error: 'Usuario no autenticado');
        return false;
      }

      // Preparar URL de foto
      String? photoUrl;
      if (state.photoPath != null) {
        final path = state.photoPath!;
        if (path.startsWith('http')) {
          photoUrl = path; // Ya es URL (web upload)
        } else {
          photoUrl = 'local:$path'; // Se subirá en el repo offline-first
        }
      }

      final prospect = Prospect(
        id: const Uuid().v4(),
        mercaderistaId: currentUser.id,
        name: name,
        rif: rif,
        address: address,
        phone: phone,
        contactPerson: contactPerson,
        latitude: state.latitude,
        longitude: state.longitude,
        photoUrl: photoUrl,
        inSitu: inSitu,
        sedeApp: currentUser.sede?.value ?? 'unknown',
        notes: notes,
        status: 'pending',
        createdAt: DateTime.now(),
      );

      await _repository.saveProspectOfflineFirst(prospect);

      state = state.copyWith(isLoading: false, isSaved: true);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Error al guardar: $e');
      return false;
    }
  }
}

/// Provider del form notifier
final prospectFormProvider =
    StateNotifierProvider.autoDispose<ProspectFormNotifier, ProspectFormState>((ref) {
  final repo = ref.watch(prospectRepositoryProvider);
  return ProspectFormNotifier(repo, ref);
});
