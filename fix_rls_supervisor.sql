-- =====================================================
-- FIX: Agregar supervisor a políticas RLS de route_clients
-- =====================================================
-- El error "new row violates row-level security policy" 
-- ocurre porque supervisor no tiene permiso de INSERT
-- =====================================================

-- Eliminar políticas existentes
DROP POLICY IF EXISTS "Users can view route clients" ON route_clients;
DROP POLICY IF EXISTS "Mercaderistas can update their route clients" ON route_clients;
DROP POLICY IF EXISTS "Admins can manage route clients" ON route_clients;

-- Nueva política SELECT: todos los autenticados pueden ver
CREATE POLICY "Users can view route clients" ON route_clients
  FOR SELECT TO authenticated USING (
    EXISTS (
      SELECT 1 FROM routes
      WHERE routes.id = route_clients.route_id
      AND (
        routes.mercaderista_id = auth.uid() OR
        EXISTS (
          SELECT 1 FROM users
          WHERE users.id = auth.uid()
          AND users.role IN ('admin', 'super_admin', 'supervisor')
        )
      )
    )
  );

-- Nueva política INSERT: admin, super_admin y supervisor pueden crear
CREATE POLICY "Staff can insert route clients" ON route_clients
  FOR INSERT TO authenticated WITH CHECK (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
      AND users.role IN ('admin', 'super_admin', 'supervisor')
    )
  );

-- Nueva política UPDATE: mercaderistas sus propias rutas, staff todas
CREATE POLICY "Users can update route clients" ON route_clients
  FOR UPDATE TO authenticated USING (
    EXISTS (
      SELECT 1 FROM routes
      WHERE routes.id = route_clients.route_id
      AND (
        routes.mercaderista_id = auth.uid() OR
        EXISTS (
          SELECT 1 FROM users
          WHERE users.id = auth.uid()
          AND users.role IN ('admin', 'super_admin', 'supervisor')
        )
      )
    )
  );

-- Nueva política DELETE: solo admin, super_admin, supervisor
CREATE POLICY "Staff can delete route clients" ON route_clients
  FOR DELETE TO authenticated USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
      AND users.role IN ('admin', 'super_admin', 'supervisor')
    )
  );

-- =====================================================
-- También actualizar políticas de routes
-- =====================================================

DROP POLICY IF EXISTS "Supervisors and admins can manage routes" ON routes;
DROP POLICY IF EXISTS "Admins can manage routes" ON routes;

CREATE POLICY "Staff can manage routes" ON routes
  FOR ALL TO authenticated USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
      AND users.role IN ('admin', 'super_admin', 'supervisor')
    )
  );

-- =====================================================
-- Verificar que el usuario tenga el rol correcto
-- =====================================================
-- SELECT id, email, role FROM users WHERE email = 'dsalcedo@smartautomatai.com';
