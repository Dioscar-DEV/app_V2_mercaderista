# Guía de Configuración de Supabase

Esta guía te ayudará a configurar completamente Supabase para el proyecto Disbattery Trade.

## 📋 Información del Proyecto

- **Project ID**: `thilpflapyijwzrbgecg`
- **URL**: `https://thilpflapyijwzrbgecg.supabase.co`
- **Anon Key**: Ya configurada en `lib/config/supabase_config.dart`

## 🚀 Pasos de Configuración

### 1️⃣ Configuración de Base de Datos

#### Opción A: Si ya ejecutaste el SQL para crear la tabla `users` ✅

Si ya ejecutaste el SQL inicial para crear la tabla users, solo necesitas ejecutar el resto de las tablas para las fases futuras:

1. Ve a tu proyecto en [Supabase Dashboard](https://supabase.com/dashboard/project/thilpflapyijwzrbgecg)
2. Click en **SQL Editor** en el menú lateral
3. Click en **New Query**
4. Copia y pega el contenido del archivo `supabase_database_setup.sql`
5. Click en **Run** (o presiona Ctrl/Cmd + Enter)

> **Nota**: El script usa `CREATE TABLE IF NOT EXISTS` y `DROP POLICY IF EXISTS`, por lo que es seguro ejecutarlo múltiples veces.

#### Opción B: Configuración desde cero

Si prefieres empezar desde cero, simplemente ejecuta el archivo `supabase_database_setup.sql` completo que incluye:

- ✅ Tabla `users` con políticas RLS
- ✅ Tabla `clients` (para Fase 3)
- ✅ Tablas `routes` y `route_clients` (para Fase 4)
- ✅ Tabla `visits` (para Fases 6-8)
- ✅ Tabla `trade_events` (para Fase 8)
- ✅ Tabla `sync_queue` (para Fase 9)
- ✅ Triggers automáticos
- ✅ Índices de rendimiento

### 2️⃣ Configuración de Storage Buckets

Para configurar los buckets de almacenamiento:

1. En **SQL Editor**, crea una **New Query**
2. Copia y pega el contenido del archivo `supabase_storage_setup.sql`
3. Click en **Run**

Este script creará:
- ✅ Bucket `visit-photos` (5MB límite)
- ✅ Bucket `client-photos` (5MB límite)
- ✅ Bucket `user-avatars` (2MB límite)
- ✅ Políticas de seguridad para cada bucket

### 3️⃣ Verificar la Configuración

#### Verificar Tablas Creadas

Ejecuta esta query en SQL Editor:

```sql
SELECT
  schemaname,
  tablename,
  tableowner
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;
```

Deberías ver las siguientes tablas:
- ✅ `users`
- ✅ `clients`
- ✅ `routes`
- ✅ `route_clients`
- ✅ `visits`
- ✅ `trade_events`
- ✅ `sync_queue`

#### Verificar Buckets Creados

Ejecuta esta query:

```sql
SELECT id, name, public, file_size_limit, allowed_mime_types
FROM storage.buckets
WHERE id IN ('visit-photos', 'client-photos', 'user-avatars');
```

O simplemente ve a **Storage** en el menú lateral y verifica que existen los 3 buckets.

### 4️⃣ Crear Usuario Administrador (Opcional)

Si quieres crear un usuario administrador para probar:

1. Ve a **Authentication** > **Users**
2. Click en **Add user** > **Create new user**
3. Ingresa:
   - Email: tu email
   - Password: tu contraseña (mínimo 8 caracteres)
4. Click en **Create user**

Luego, en **SQL Editor**, ejecuta:

```sql
-- Actualizar el usuario recién creado a admin
UPDATE users
SET role = 'admin', status = 'active'
WHERE email = 'tu-email@ejemplo.com';
```

## 📂 Archivos de Configuración

- `supabase_database_setup.sql` - Script completo de base de datos
- `supabase_storage_setup.sql` - Script de storage buckets
- `lib/config/supabase_config.dart` - Configuración de Supabase en Flutter (ya configurado ✅)

## 🔒 Seguridad

### Row Level Security (RLS)

Todas las tablas tienen RLS habilitado con las siguientes políticas:

- **Users**: Los usuarios ven solo su información, admins ven todo
- **Clients**: Todos los autenticados ven clientes, solo admins editan
- **Routes**: Los mercaderistas ven sus rutas, admins ven todo
- **Visits**: Los mercaderistas ven sus visitas, admins ven todo
- **Storage**: Los usuarios suben a sus carpetas, todos pueden ver (público)

### Storage Policies

- Los archivos se organizan por carpetas de usuario: `{user_id}/{filename}`
- Solo el dueño puede subir/editar/eliminar sus archivos
- Todos pueden ver los archivos (buckets públicos)
- Los admins tienen permisos especiales en `client-photos`

## 🧪 Probar la Configuración

### Test de Autenticación

1. Ejecuta la app: `flutter run`
2. Intenta registrarte con un nuevo usuario
3. Verifica que:
   - El usuario se crea en Authentication
   - Se crea automáticamente en la tabla `users` con status `pending`

### Test de Storage (cuando implementes upload)

```dart
// Ejemplo de cómo subir una foto
final userId = SupabaseConfig.currentUser!.id;
final path = '$userId/test.jpg';
final url = await SupabaseConfig.uploadFile(
  SupabaseConfig.visitPhotosBucket,
  path,
  imageBytes,
);
```

## ❗ Solución de Problemas

### Error: "relation users does not exist"

Ejecuta el script `supabase_database_setup.sql` completo.

### Error: "bucket does not exist"

Ejecuta el script `supabase_storage_setup.sql`.

### Error: "permission denied for table users"

Verifica que las políticas RLS estén creadas. Ejecuta:

```sql
SELECT * FROM pg_policies WHERE tablename = 'users';
```

### No puedo ver los datos en la tabla

Asegúrate de estar autenticado y que tu usuario tenga los permisos correctos según las políticas RLS.

## 📝 Notas Adicionales

1. **Trigger Automático**: Cuando un usuario se registra vía Authentication, automáticamente se crea su registro en la tabla `users` con rol `mercaderista` y status `pending`.

2. **Updated At**: Todas las tablas con campo `updated_at` se actualizan automáticamente gracias al trigger.

3. **Cascadas**: Si se elimina una ruta, se eliminan automáticamente todos sus `route_clients` asociados.

4. **Límites de Storage**:
   - Visit photos y client photos: 5MB por archivo
   - User avatars: 2MB por archivo
   - Solo imágenes: JPEG, PNG, WebP

## 🎯 Próximos Pasos

Una vez completada esta configuración:

1. ✅ Supabase está completamente configurado
2. ✅ Puedes ejecutar la app Flutter
3. ✅ El sistema de autenticación funciona
4. ✅ Las bases de datos están listas para las siguientes fases

Para ejecutar la aplicación:

```bash
cd disbattery_trade
flutter run
```

## 📞 Soporte

Si tienes problemas con la configuración, revisa:

1. Los logs de Supabase en **Logs** > **Postgres Logs**
2. Los logs de Flutter en la consola
3. Verifica que las credenciales en `supabase_config.dart` sean correctas
