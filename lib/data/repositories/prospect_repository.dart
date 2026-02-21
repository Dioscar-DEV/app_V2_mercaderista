import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/models/prospect.dart';
import '../../config/supabase_config.dart';
import '../local/database_service.dart';

class ProspectRepository {
  final SupabaseClient _client;
  final DatabaseService _db;

  ProspectRepository({
    SupabaseClient? client,
    DatabaseService? db,
  })  : _client = client ?? SupabaseConfig.client,
        _db = db ?? DatabaseService();

  /// Guarda prospecto offline-first: SQLite primero, luego intenta Supabase
  Future<Prospect> saveProspectOfflineFirst(Prospect prospect) async {
    // 1. Guardar en SQLite inmediatamente
    if (!kIsWeb) {
      await _db.saveProspect(prospect);
    }

    // 2. Intentar subir foto y sync con Supabase
    try {
      var finalProspect = prospect;

      // Subir foto si es local
      if (prospect.photoUrl != null && prospect.photoUrl!.startsWith('local:')) {
        final localPath = prospect.photoUrl!.replaceFirst('local:', '');
        final file = File(localPath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final userId = _client.auth.currentUser?.id ?? 'unknown';
          final fileName = '$userId/prospect_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final url = await SupabaseConfig.uploadFile(
            SupabaseConfig.visitPhotosBucket,
            fileName,
            bytes,
          );
          finalProspect = finalProspect.copyWith(photoUrl: url);
        }
      }

      // Insertar en Supabase
      await _client.from('prospects').insert(finalProspect.toJson());

      // Marcar como sincronizado en SQLite
      if (!kIsWeb) {
        if (finalProspect.photoUrl != prospect.photoUrl) {
          await _db.updateProspectPhotoUrl(prospect.id, finalProspect.photoUrl!);
        }
        await _db.markProspectSynced(prospect.id);
      }

      return finalProspect.copyWith(isSynced: true);
    } catch (e) {
      // Offline: se queda en SQLite para sync posterior
      if (kIsWeb) rethrow;
      return prospect;
    }
  }

  /// Sube foto de prospecto a Storage y retorna URL (o local: si falla)
  Future<String> uploadProspectPhoto(File photoFile) async {
    try {
      final bytes = await photoFile.readAsBytes();
      final userId = _client.auth.currentUser?.id ?? 'unknown';
      final fileName = '$userId/prospect_${DateTime.now().millisecondsSinceEpoch}.jpg';
      return await SupabaseConfig.uploadFile(
        SupabaseConfig.visitPhotosBucket,
        fileName,
        bytes,
      );
    } catch (e) {
      // Fallback: guardar path local
      return 'local:${photoFile.path}';
    }
  }

  /// Sube foto desde bytes (web)
  Future<String> uploadProspectPhotoBytes(Uint8List bytes) async {
    final userId = _client.auth.currentUser?.id ?? 'unknown';
    final fileName = '$userId/prospect_${DateTime.now().millisecondsSinceEpoch}.jpg';
    return await SupabaseConfig.uploadFile(
      SupabaseConfig.visitPhotosBucket,
      fileName,
      bytes,
    );
  }

  /// Obtiene prospectos del usuario actual desde Supabase
  Future<List<Prospect>> getMyProspects() async {
    final response = await _client
        .from('prospects')
        .select()
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => Prospect.fromJson(json).copyWith(isSynced: true))
        .toList();
  }

  /// Sincroniza prospectos pendientes de SQLite a Supabase
  Future<int> syncPendingProspects() async {
    if (kIsWeb) return 0;

    final unsynced = await _db.getUnsyncedProspects();
    int synced = 0;

    for (final prospect in unsynced) {
      try {
        var finalProspect = prospect;

        // Subir foto local si existe
        if (prospect.photoUrl != null && prospect.photoUrl!.startsWith('local:')) {
          final localPath = prospect.photoUrl!.replaceFirst('local:', '');
          final file = File(localPath);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            final userId = _client.auth.currentUser?.id ?? 'unknown';
            final fileName = '$userId/prospect_${DateTime.now().millisecondsSinceEpoch}_$synced.jpg';
            final url = await SupabaseConfig.uploadFile(
              SupabaseConfig.visitPhotosBucket,
              fileName,
              bytes,
            );
            finalProspect = finalProspect.copyWith(photoUrl: url);
            await _db.updateProspectPhotoUrl(prospect.id, url);
          }
        }

        await _client.from('prospects').insert(finalProspect.toJson());
        await _db.markProspectSynced(prospect.id);
        synced++;
      } catch (e) {
        // Si ya existe (duplicate key), marcamos como synced
        if (e.toString().contains('duplicate') || e.toString().contains('23505')) {
          await _db.markProspectSynced(prospect.id);
          synced++;
        }
        // Otro error: skip, se reintentará luego
      }
    }

    return synced;
  }
}
