import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Configuración de Supabase para la aplicación
class SupabaseConfig {
  // Credenciales de Supabase
  static const String supabaseUrl = 'https://thilpflapyijwzrbgecg.supabase.co';

  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoaWxwZmxhcHlpand6cmJnZWNnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA3NDAyMzksImV4cCI6MjA4NjMxNjIzOX0.2UZ_0qPx0Y7XvVt1aEEM5LDQ60axg2j6cIO5ctqFX0E';

  /// Inicializa Supabase
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      debug: kDebugMode,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
      realtimeClientOptions: const RealtimeClientOptions(
        eventsPerSecond: 10,
      ),
    );
  }

  /// Obtiene la instancia del cliente Supabase
  static SupabaseClient get client => Supabase.instance.client;

  /// Obtiene el usuario autenticado actual
  static User? get currentUser => client.auth.currentUser;

  /// Stream de cambios de autenticación
  static Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  /// Nombres de buckets de Storage
  static const String visitPhotosBucket = 'visit-photos';
  static const String clientPhotosBucket = 'client-photos';
  static const String userAvatarsBucket = 'user-avatars';

  /// Obtiene la URL pública de un archivo en Storage
  static String getPublicUrl(String bucket, String path) {
    return client.storage.from(bucket).getPublicUrl(path);
  }

  /// Sube un archivo a Storage
  static Future<String> uploadFile(
    String bucket,
    String path,
    Uint8List fileBytes, {
    String contentType = 'image/jpeg',
  }) async {
    await client.storage.from(bucket).uploadBinary(
          path,
          fileBytes,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: true,
          ),
        );
    return getPublicUrl(bucket, path);
  }

  /// Elimina un archivo de Storage
  static Future<void> deleteFile(String bucket, String path) async {
    await client.storage.from(bucket).remove([path]);
  }
}
