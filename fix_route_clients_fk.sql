-- =====================================================
-- FIX: Corregir FK de route_clients para usar co_cli
-- =====================================================
-- El problema es que route_clients tiene client_id UUID
-- pero clients usa co_cli TEXT como PK
-- =====================================================

-- =====================================================
-- 1. ROUTE_CLIENTS
-- =====================================================

-- Eliminar la tabla route_clients existente
DROP TABLE IF EXISTS route_clients CASCADE;

-- Recrear route_clients con client_co_cli TEXT
CREATE TABLE IF NOT EXISTS route_clients (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  route_id UUID REFERENCES routes(id) ON DELETE CASCADE NOT NULL,
  client_co_cli TEXT REFERENCES clients(co_cli) ON DELETE CASCADE NOT NULL,
  order_number INTEGER NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'in_progress', 'visited', 'skipped')),
  started_at TIMESTAMP WITH TIME ZONE,
  completed_at TIMESTAMP WITH TIME ZONE,
  latitude_start DECIMAL(10, 8),
  longitude_start DECIMAL(11, 8),
  latitude_end DECIMAL(10, 8),
  longitude_end DECIMAL(11, 8),
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Habilitar RLS
ALTER TABLE route_clients ENABLE ROW LEVEL SECURITY;

-- Políticas RLS
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
          AND users.role IN ('admin', 'super_admin')
        )
      )
    )
  );

CREATE POLICY "Mercaderistas can update their route clients" ON route_clients
  FOR UPDATE TO authenticated USING (
    EXISTS (
      SELECT 1 FROM routes
      WHERE routes.id = route_clients.route_id
      AND routes.mercaderista_id = auth.uid()
    )
  );

CREATE POLICY "Admins can manage route clients" ON route_clients
  FOR ALL TO authenticated USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
      AND users.role IN ('admin', 'super_admin')
    )
  );

-- Índices para performance
CREATE INDEX IF NOT EXISTS idx_route_clients_route ON route_clients(route_id);
CREATE INDEX IF NOT EXISTS idx_route_clients_client ON route_clients(client_co_cli);
CREATE INDEX IF NOT EXISTS idx_route_clients_status ON route_clients(status);

-- =====================================================
-- 2. ROUTE_TEMPLATE_CLIENTS (si existe)
-- =====================================================

DROP TABLE IF EXISTS route_template_clients CASCADE;

CREATE TABLE IF NOT EXISTS route_template_clients (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  template_id UUID REFERENCES route_templates(id) ON DELETE CASCADE NOT NULL,
  client_co_cli TEXT REFERENCES clients(co_cli) ON DELETE CASCADE NOT NULL,
  order_number INTEGER NOT NULL DEFAULT 0,
  estimated_duration_minutes INTEGER DEFAULT 30,
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- RLS
ALTER TABLE route_template_clients ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view template clients" ON route_template_clients
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "Admins can manage template clients" ON route_template_clients
  FOR ALL TO authenticated USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
      AND users.role IN ('admin', 'super_admin')
    )
  );

-- Índices
CREATE INDEX IF NOT EXISTS idx_template_clients_template ON route_template_clients(template_id);
CREATE INDEX IF NOT EXISTS idx_template_clients_client ON route_template_clients(client_co_cli);

-- =====================================================
-- VERIFICACIÓN: Confirmar que las FK funcionan
-- =====================================================
-- SELECT 
--   tc.table_name, 
--   kcu.column_name,
--   ccu.table_name AS foreign_table_name,
--   ccu.column_name AS foreign_column_name
-- FROM information_schema.table_constraints AS tc
-- JOIN information_schema.key_column_usage AS kcu
--   ON tc.constraint_name = kcu.constraint_name
-- JOIN information_schema.constraint_column_usage AS ccu
--   ON ccu.constraint_name = tc.constraint_name
-- WHERE tc.table_name IN ('route_clients', 'route_template_clients') 
--   AND tc.constraint_type = 'FOREIGN KEY';
