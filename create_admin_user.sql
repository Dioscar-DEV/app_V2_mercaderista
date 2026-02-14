-- =====================================================
-- CREAR USUARIO ADMINISTRADOR
-- admin@smartautomation.com / 12345678
-- =====================================================

-- IMPORTANTE: Este script debe ejecutarse en 2 pasos

-- =====================================================
-- PASO 1: Crear el usuario en Authentication
-- =====================================================
-- Ve a Supabase Dashboard > Authentication > Users
-- Click en "Add user" > "Create new user"
-- Email: admin@smartautomation.com
-- Password: 12345678
-- Click en "Create user"

-- =====================================================
-- PASO 2: Actualizar el usuario en la tabla users
-- =====================================================
-- Después de crear el usuario en Authentication,
-- ejecuta este SQL:

UPDATE users
SET
  role = 'admin',
  status = 'active',
  full_name = 'Administrador Disbattery',
  sede = 'GRUPO DISBATTERY',
  region = 'Centro-Capital',
  updated_at = NOW()
WHERE email = 'admin@smartautomation.com';

-- Verificar que se creó correctamente
SELECT
  id,
  email,
  full_name,
  role,
  status,
  sede,
  region
FROM users
WHERE email = 'admin@smartautomation.com';

-- =====================================================
-- ALTERNATIVA: Si prefieres crear directamente con SQL
-- =====================================================
-- Nota: Esto requiere tener acceso a la extensión auth
-- Solo funciona si tienes permisos de super admin en Supabase

-- Descomentar y ejecutar si tienes los permisos:

/*
-- Insertar en auth.users
INSERT INTO auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at,
  confirmation_token,
  email_change,
  email_change_token_new,
  recovery_token
) VALUES (
  '00000000-0000-0000-0000-000000000000',
  gen_random_uuid(),
  'authenticated',
  'authenticated',
  'admin@smartautomation.com',
  crypt('12345678', gen_salt('bf')),
  NOW(),
  '{"provider":"email","providers":["email"]}',
  '{"full_name":"Administrador Disbattery"}',
  NOW(),
  NOW(),
  '',
  '',
  '',
  ''
);

-- Insertar en public.users (esto se hará automáticamente con el trigger)
-- Pero actualizamos el rol y status
UPDATE users
SET
  role = 'admin',
  status = 'active',
  sede = 'GRUPO DISBATTERY',
  region = 'Centro-Capital'
WHERE email = 'admin@smartautomation.com';
*/

-- =====================================================
-- NOTAS IMPORTANTES
-- =====================================================
-- 1. La forma más segura es crear el usuario desde el Dashboard
-- 2. El trigger automático creará el registro en la tabla users
-- 3. Luego solo actualizas el role y status con el UPDATE de arriba
-- 4. La contraseña "12345678" es temporal, cámbiala en producción
-- =====================================================
