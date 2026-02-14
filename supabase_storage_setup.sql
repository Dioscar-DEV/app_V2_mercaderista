-- =====================================================
-- CONFIGURACIÓN DE STORAGE BUCKETS PARA DISBATTERY TRADE
-- =====================================================
-- Ejecutar este script en el SQL Editor de Supabase
-- =====================================================

-- 1. CREAR BUCKETS DE STORAGE
-- =====================================================

-- Bucket para fotos de visitas
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'visit-photos',
  'visit-photos',
  true,
  5242880, -- 5MB en bytes
  ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO NOTHING;

-- Bucket para fotos de clientes
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'client-photos',
  'client-photos',
  true,
  5242880, -- 5MB en bytes
  ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO NOTHING;

-- Bucket para avatares de usuarios
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'user-avatars',
  'user-avatars',
  true,
  2097152, -- 2MB en bytes
  ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO NOTHING;


-- 2. POLÍTICAS DE SEGURIDAD PARA STORAGE
-- =====================================================

-- =====================================
-- BUCKET: visit-photos
-- =====================================

-- Política: Los usuarios autenticados pueden subir fotos de visitas
CREATE POLICY "Users can upload visit photos"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'visit-photos' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

-- Política: Todos pueden ver fotos de visitas (público)
CREATE POLICY "Public can view visit photos"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'visit-photos');

-- Política: Los usuarios pueden actualizar sus propias fotos de visitas
CREATE POLICY "Users can update own visit photos"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'visit-photos' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

-- Política: Los usuarios pueden eliminar sus propias fotos de visitas
CREATE POLICY "Users can delete own visit photos"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'visit-photos' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

-- =====================================
-- BUCKET: client-photos
-- =====================================

-- Política: Los usuarios autenticados pueden subir fotos de clientes
CREATE POLICY "Users can upload client photos"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'client-photos');

-- Política: Todos pueden ver fotos de clientes (público)
CREATE POLICY "Public can view client photos"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'client-photos');

-- Política: Los admins pueden actualizar fotos de clientes
CREATE POLICY "Admins can update client photos"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'client-photos' AND
  EXISTS (
    SELECT 1 FROM users
    WHERE users.id = auth.uid()
    AND users.role IN ('admin', 'super_admin')
  )
);

-- Política: Los admins pueden eliminar fotos de clientes
CREATE POLICY "Admins can delete client photos"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'client-photos' AND
  EXISTS (
    SELECT 1 FROM users
    WHERE users.id = auth.uid()
    AND users.role IN ('admin', 'super_admin')
  )
);

-- =====================================
-- BUCKET: user-avatars
-- =====================================

-- Política: Los usuarios pueden subir su propio avatar
CREATE POLICY "Users can upload own avatar"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'user-avatars' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

-- Política: Todos pueden ver avatares (público)
CREATE POLICY "Public can view avatars"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'user-avatars');

-- Política: Los usuarios pueden actualizar su propio avatar
CREATE POLICY "Users can update own avatar"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'user-avatars' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

-- Política: Los usuarios pueden eliminar su propio avatar
CREATE POLICY "Users can delete own avatar"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'user-avatars' AND
  auth.uid()::text = (storage.foldername(name))[1]
);


-- 3. VERIFICAR BUCKETS CREADOS
-- =====================================================

-- Ejecutar esta query para verificar que los buckets se crearon correctamente
SELECT id, name, public, file_size_limit, allowed_mime_types
FROM storage.buckets
WHERE id IN ('visit-photos', 'client-photos', 'user-avatars');


-- =====================================================
-- NOTAS IMPORTANTES:
-- =====================================================
-- 1. Los buckets están configurados como públicos (public = true)
-- 2. Límite de tamaño: 5MB para fotos de visitas y clientes, 2MB para avatares
-- 3. Solo se permiten formatos de imagen: JPEG, PNG, WebP
-- 4. Las políticas de seguridad están configuradas para:
--    - Usuarios autenticados pueden subir sus propias fotos
--    - Todos pueden ver las fotos (público)
--    - Solo los dueños pueden actualizar/eliminar sus fotos
--    - Los admins tienen permisos especiales en fotos de clientes
-- 5. La estructura de carpetas recomendada es: {user_id}/{filename}
--    Ejemplo: visit-photos/abc123-uuid/foto1.jpg
-- =====================================================
