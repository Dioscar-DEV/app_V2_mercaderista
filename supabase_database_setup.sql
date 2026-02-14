-- =====================================================
-- CONFIGURACIÓN COMPLETA DE BASE DE DATOS SUPABASE
-- DISBATTERY TRADE
-- =====================================================
-- Este script contiene toda la configuración de base de datos
-- =====================================================

-- =====================================================
-- 1. TABLA USERS (Ya ejecutado)
-- =====================================================

-- Crear tabla users
CREATE TABLE IF NOT EXISTS users (
  id UUID REFERENCES auth.users PRIMARY KEY,
  email TEXT NOT NULL,
  full_name TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('mercaderista', 'admin', 'super_admin')),
  sede TEXT,
  region TEXT,
  phone TEXT,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('active', 'pending', 'rejected', 'inactive')),
  avatar_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE
);

-- Habilitar RLS (Row Level Security)
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- FUNCIÓN HELPER PARA EVITAR RECURSIÓN EN POLÍTICAS RLS
-- Esta función usa SECURITY DEFINER para evitar recursión infinita
-- cuando se consulta la tabla users dentro de sus propias políticas
-- =====================================================
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM users
    WHERE id = auth.uid() 
    AND role IN ('admin', 'super_admin')
  );
$$;

-- Eliminar políticas existentes si existen (para evitar duplicados)
DROP POLICY IF EXISTS "Users can view own data" ON users;
DROP POLICY IF EXISTS "Users can update own data" ON users;
DROP POLICY IF EXISTS "Admins can view all users" ON users;
DROP POLICY IF EXISTS "Admins can update users" ON users;
DROP POLICY IF EXISTS "Users can insert own profile" ON users;
DROP POLICY IF EXISTS "Admins can insert users" ON users;

-- Política para SELECT: usuarios ven sus datos, admins ven todos
-- NOTA: Usamos la función is_admin() para evitar recursión infinita
CREATE POLICY "Admins can view all users" ON users
  FOR SELECT USING (auth.uid() = id OR public.is_admin());

-- Política para UPDATE: usuarios actualizan sus datos, admins pueden actualizar todos
CREATE POLICY "Users can update own data" ON users
  FOR UPDATE 
  USING (auth.uid() = id OR public.is_admin())
  WITH CHECK (auth.uid() = id OR public.is_admin());

-- Política para INSERT: usuarios pueden crear su perfil al registrarse
CREATE POLICY "Users can insert own profile" ON users
  FOR INSERT
  WITH CHECK (auth.uid() = id);

-- Política para INSERT: admins pueden crear usuarios
CREATE POLICY "Admins can insert users" ON users
  FOR INSERT
  WITH CHECK (public.is_admin());

-- Índices para mejorar el rendimiento
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
CREATE INDEX IF NOT EXISTS idx_users_status ON users(status);
CREATE INDEX IF NOT EXISTS idx_users_sede ON users(sede);
CREATE INDEX IF NOT EXISTS idx_users_region ON users(region);


-- =====================================================
-- 2. TABLA CLIENTS (Para la Fase 3)
-- =====================================================

CREATE TABLE IF NOT EXISTS clients (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  rif TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  address TEXT NOT NULL,
  city TEXT NOT NULL,
  state TEXT NOT NULL,
  region TEXT NOT NULL,
  phone TEXT,
  contact_person TEXT,
  latitude DECIMAL(10, 8),
  longitude DECIMAL(11, 8),
  client_type TEXT,
  current_signage JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE
);

-- Habilitar RLS
ALTER TABLE clients ENABLE ROW LEVEL SECURITY;

-- Políticas para clientes
CREATE POLICY "Users can view clients" ON clients
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "Admins can manage clients" ON clients
  FOR ALL TO authenticated USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
      AND users.role IN ('admin', 'super_admin')
    )
  );

-- Índices
CREATE INDEX IF NOT EXISTS idx_clients_region ON clients(region);
CREATE INDEX IF NOT EXISTS idx_clients_state ON clients(state);
CREATE INDEX IF NOT EXISTS idx_clients_city ON clients(city);
CREATE INDEX IF NOT EXISTS idx_clients_rif ON clients(rif);


-- =====================================================
-- 3. TABLA ROUTES (Para la Fase 4)
-- =====================================================

CREATE TABLE IF NOT EXISTS routes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  mercaderista_id UUID REFERENCES users(id) NOT NULL,
  name TEXT NOT NULL,
  date DATE NOT NULL,
  status TEXT NOT NULL DEFAULT 'planned' CHECK (status IN ('planned', 'in_progress', 'completed', 'cancelled')),
  total_clients INTEGER DEFAULT 0,
  completed_clients INTEGER DEFAULT 0,
  estimated_duration INTERVAL,
  started_at TIMESTAMP WITH TIME ZONE,
  completed_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE
);

-- Habilitar RLS
ALTER TABLE routes ENABLE ROW LEVEL SECURITY;

-- Políticas para rutas
CREATE POLICY "Users can view own routes" ON routes
  FOR SELECT TO authenticated USING (
    auth.uid() = mercaderista_id OR
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
      AND users.role IN ('admin', 'super_admin')
    )
  );

CREATE POLICY "Admins can manage routes" ON routes
  FOR ALL TO authenticated USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
      AND users.role IN ('admin', 'super_admin')
    )
  );

CREATE POLICY "Users can update own routes" ON routes
  FOR UPDATE TO authenticated USING (auth.uid() = mercaderista_id);

-- Índices
CREATE INDEX IF NOT EXISTS idx_routes_mercaderista ON routes(mercaderista_id);
CREATE INDEX IF NOT EXISTS idx_routes_date ON routes(date);
CREATE INDEX IF NOT EXISTS idx_routes_status ON routes(status);


-- =====================================================
-- 4. TABLA ROUTE_CLIENTS (Para la Fase 4)
-- =====================================================

CREATE TABLE IF NOT EXISTS route_clients (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  route_id UUID REFERENCES routes(id) ON DELETE CASCADE NOT NULL,
  client_id UUID REFERENCES clients(id) NOT NULL,
  order_number INTEGER NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'visited', 'skipped')),
  visited_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Habilitar RLS
ALTER TABLE route_clients ENABLE ROW LEVEL SECURITY;

-- Políticas
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

CREATE POLICY "Admins can manage route clients" ON route_clients
  FOR ALL TO authenticated USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
      AND users.role IN ('admin', 'super_admin')
    )
  );

-- Índices
CREATE INDEX IF NOT EXISTS idx_route_clients_route ON route_clients(route_id);
CREATE INDEX IF NOT EXISTS idx_route_clients_client ON route_clients(client_id);
CREATE INDEX IF NOT EXISTS idx_route_clients_status ON route_clients(status);


-- =====================================================
-- 5. TABLA VISITS (Para las Fases 6-8)
-- =====================================================

CREATE TABLE IF NOT EXISTS visits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  route_id UUID REFERENCES routes(id) ON DELETE SET NULL,
  client_id UUID REFERENCES clients(id) NOT NULL,
  mercaderista_id UUID REFERENCES users(id) NOT NULL,
  visit_type TEXT NOT NULL CHECK (visit_type IN ('merchandising_shell', 'merchandising_qualid', 'trade_event', 'trade_impulse')),
  visit_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  latitude DECIMAL(10, 8),
  longitude DECIMAL(11, 8),
  data JSONB NOT NULL DEFAULT '{}',
  photos TEXT[] DEFAULT '{}',
  notes TEXT,
  synced BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE
);

-- Habilitar RLS
ALTER TABLE visits ENABLE ROW LEVEL SECURITY;

-- Políticas
CREATE POLICY "Users can view own visits" ON visits
  FOR SELECT TO authenticated USING (
    auth.uid() = mercaderista_id OR
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
      AND users.role IN ('admin', 'super_admin')
    )
  );

CREATE POLICY "Users can create visits" ON visits
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = mercaderista_id);

CREATE POLICY "Users can update own visits" ON visits
  FOR UPDATE TO authenticated USING (auth.uid() = mercaderista_id);

CREATE POLICY "Admins can manage visits" ON visits
  FOR ALL TO authenticated USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
      AND users.role IN ('admin', 'super_admin')
    )
  );

-- Índices
CREATE INDEX IF NOT EXISTS idx_visits_mercaderista ON visits(mercaderista_id);
CREATE INDEX IF NOT EXISTS idx_visits_client ON visits(client_id);
CREATE INDEX IF NOT EXISTS idx_visits_route ON visits(route_id);
CREATE INDEX IF NOT EXISTS idx_visits_type ON visits(visit_type);
CREATE INDEX IF NOT EXISTS idx_visits_date ON visits(visit_date);
CREATE INDEX IF NOT EXISTS idx_visits_synced ON visits(synced);


-- =====================================================
-- 6. TABLA TRADE_EVENTS (Para la Fase 8)
-- =====================================================

CREATE TABLE IF NOT EXISTS trade_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  brand TEXT NOT NULL CHECK (brand IN ('shell', 'qualid', 'both')),
  location TEXT NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  assigned_mercaderistas UUID[] DEFAULT '{}',
  status TEXT NOT NULL DEFAULT 'planned' CHECK (status IN ('planned', 'active', 'completed')),
  created_by UUID REFERENCES users(id) NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE
);

-- Habilitar RLS
ALTER TABLE trade_events ENABLE ROW LEVEL SECURITY;

-- Políticas
CREATE POLICY "Users can view events" ON trade_events
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "Admins can manage events" ON trade_events
  FOR ALL TO authenticated USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
      AND users.role IN ('admin', 'super_admin')
    )
  );

-- Índices
CREATE INDEX IF NOT EXISTS idx_events_status ON trade_events(status);
CREATE INDEX IF NOT EXISTS idx_events_dates ON trade_events(start_date, end_date);


-- =====================================================
-- 7. TABLA SYNC_QUEUE (Para la Fase 9)
-- =====================================================

CREATE TABLE IF NOT EXISTS sync_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id UUID,
  operation TEXT NOT NULL CHECK (operation IN ('create', 'update', 'delete')),
  data JSONB NOT NULL DEFAULT '{}',
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'synced', 'error')),
  error_message TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  synced_at TIMESTAMP WITH TIME ZONE
);

-- Habilitar RLS
ALTER TABLE sync_queue ENABLE ROW LEVEL SECURITY;

-- Políticas
CREATE POLICY "Users can view own sync queue" ON sync_queue
  FOR SELECT TO authenticated USING (auth.uid() = user_id);

CREATE POLICY "Users can manage own sync queue" ON sync_queue
  FOR ALL TO authenticated USING (auth.uid() = user_id);

-- Índices
CREATE INDEX IF NOT EXISTS idx_sync_queue_user ON sync_queue(user_id);
CREATE INDEX IF NOT EXISTS idx_sync_queue_status ON sync_queue(status);
CREATE INDEX IF NOT EXISTS idx_sync_queue_created ON sync_queue(created_at);


-- =====================================================
-- 8. FUNCIÓN PARA ACTUALIZAR updated_at AUTOMÁTICAMENTE
-- =====================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Aplicar trigger a todas las tablas que tienen updated_at
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_clients_updated_at BEFORE UPDATE ON clients
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_routes_updated_at BEFORE UPDATE ON routes
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_visits_updated_at BEFORE UPDATE ON visits
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_trade_events_updated_at BEFORE UPDATE ON trade_events
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();


-- =====================================================
-- 9. FUNCIÓN PARA CREAR USUARIO EN LA TABLA USERS AL REGISTRARSE
-- =====================================================

CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (id, email, full_name, role, status)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', 'Usuario'),
    'mercaderista',
    'pending'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger para crear usuario automáticamente
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();


-- =====================================================
-- 10. VERIFICACIÓN DE TABLAS CREADAS
-- =====================================================

-- Ejecutar para verificar todas las tablas
SELECT
  schemaname,
  tablename,
  tableowner
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;


-- =====================================================
-- NOTAS FINALES
-- =====================================================
-- 1. Todas las tablas tienen RLS habilitado
-- 2. Se crearon políticas de seguridad para cada tabla
-- 3. Se agregaron índices para mejorar el rendimiento
-- 4. Trigger automático para actualizar updated_at
-- 5. Trigger automático para crear usuario al registrarse
-- 6. Las relaciones están definidas con foreign keys
-- =====================================================
