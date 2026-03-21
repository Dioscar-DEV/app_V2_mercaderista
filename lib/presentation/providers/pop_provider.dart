import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/supabase_config.dart';
import '../../core/models/pop_material.dart';

/// Provider de materiales (catálogo)
final popMaterialsProvider = FutureProvider<List<PopMaterial>>((ref) async {
  final response = await SupabaseConfig.client
      .from('pop_materials')
      .select()
      .eq('is_active', true)
      .order('marca')
      .order('nombre');

  return (response as List)
      .map((e) => PopMaterial.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Provider de stock por sede
final popStockProvider =
    FutureProvider.family<List<PopStock>, String?>((ref, sedeApp) async {
  var query = SupabaseConfig.client
      .from('pop_stock')
      .select('*, pop_materials(*)');

  if (sedeApp != null) {
    query = query.eq('sede_app', sedeApp);
  }

  final response = await query.order('sede_app');

  return (response as List)
      .map((e) => PopStock.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Provider de movimientos recientes por sede
final popMovementsProvider =
    FutureProvider.family<List<PopMovement>, String?>((ref, sedeApp) async {
  var query = SupabaseConfig.client
      .from('pop_movements')
      .select('*, pop_materials(*)');

  if (sedeApp != null) {
    query = query.eq('sede_app', sedeApp);
  }

  final response = await query.order('created_at', ascending: false).limit(100);

  return (response as List)
      .map((e) => PopMovement.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Provider de opciones usadas en formularios (para vincular materiales)
final popFormOptionsProvider =
    FutureProvider.family<List<String>, String>((ref, questionPattern) async {
  // Buscar opciones únicas usadas en visitas para esa pregunta
  final response = await SupabaseConfig.client.rpc('get_form_options', params: {
    'p_question_pattern': questionPattern,
  });

  if (response == null) return [];
  return (response as List).map((e) => e['opcion_nombre'] as String).toList();
});

/// Registrar un movimiento (ingreso o egreso)
final registerPopMovementProvider =
    FutureProvider.family<void, PopMovement>((ref, movement) async {
  await SupabaseConfig.client
      .from('pop_movements')
      .insert(movement.toInsertJson());

  // Invalidar providers para refrescar data
  ref.invalidate(popStockProvider);
  ref.invalidate(popMovementsProvider);
});
