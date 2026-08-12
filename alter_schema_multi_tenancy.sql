-- ============================================================
-- MotoTaller App — Migración Multi-Tenant (SaaS)
-- Script: alter_schema_multi_tenancy.sql
--
-- ⚠️ INSTRUCCIONES DE EJECUCIÓN:
--   1. Ve a Supabase Dashboard → SQL Editor
--   2. Pega este script completo y haz clic en "Run"
-- ============================================================

-- 1. CREAR LA TABLA DE PERFIL DE TALLER
CREATE TABLE IF NOT EXISTS perfil_taller (
  id                          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  usuario_administrador_id    UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  nombre_taller               TEXT NOT NULL DEFAULT 'Mi Taller',
  logo_url                    TEXT,
  telefono                    TEXT,
  direccion                   TEXT,
  ciudad                      TEXT,
  moneda                      TEXT NOT NULL DEFAULT 'COP',
  porcentaje_impuesto_defecto NUMERIC(5,2) NOT NULL DEFAULT 0.00 CHECK (porcentaje_impuesto_defecto >= 0),
  terminos_condiciones_factura TEXT,
  created_at                  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at                  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Habilitar RLS en perfil_taller
ALTER TABLE perfil_taller ENABLE ROW LEVEL SECURITY;

-- Registrar trigger para actualizar updated_at en perfil_taller
CREATE TRIGGER trg_perfil_taller_updated_at
  BEFORE UPDATE ON perfil_taller
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- 2. MODIFICAR TABLAS EXISTENTES PARA INYECTAR taller_id
-- NOTA: Se agregan con DEFAULT NULL inicialmente para no romper registros existentes (si los hay),
-- pero luego se pueden actualizar y hacer NOT NULL.

-- Clientes
ALTER TABLE clientes ADD COLUMN IF NOT EXISTS taller_id UUID REFERENCES perfil_taller(id) ON DELETE CASCADE;
-- Vehiculos
ALTER TABLE vehiculos ADD COLUMN IF NOT EXISTS taller_id UUID REFERENCES perfil_taller(id) ON DELETE CASCADE;
-- Inventario de Repuestos
ALTER TABLE inventario_repuestos ADD COLUMN IF NOT EXISTS taller_id UUID REFERENCES perfil_taller(id) ON DELETE CASCADE;
-- Ordenes de Mantenimiento
ALTER TABLE ordenes_mantenimiento ADD COLUMN IF NOT EXISTS taller_id UUID REFERENCES perfil_taller(id) ON DELETE CASCADE;

-- 3. CREAR ÍNDICES DE DESEMPEÑO PARA taller_id
CREATE INDEX IF NOT EXISTS idx_clientes_taller ON clientes(taller_id);
CREATE INDEX IF NOT EXISTS idx_vehiculos_taller ON vehiculos(taller_id);
CREATE INDEX IF NOT EXISTS idx_repuestos_taller ON inventario_repuestos(taller_id);
CREATE INDEX IF NOT EXISTS idx_ordenes_taller ON ordenes_mantenimiento(taller_id);

-- 4. FUNCIÓN Y TRIGGER PARA AUTOMATIZAR LA CREACIÓN DE TALLER AL REGISTRARSE
-- Cuando un usuario se registra en auth.users, creamos automáticamente su perfil_taller
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  new_taller_id UUID;
BEGIN
  INSERT INTO public.perfil_taller (usuario_administrador_id, nombre_taller, moneda, porcentaje_impuesto_defecto)
  VALUES (NEW.id, 'Mi Taller', 'COP', 0.00)
  RETURNING id INTO new_taller_id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger de Auth
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Para usuarios que YA existen pero no tienen perfil_taller, creamos su perfil manualmente:
INSERT INTO public.perfil_taller (usuario_administrador_id, nombre_taller, moneda, porcentaje_impuesto_defecto)
SELECT id, 'Mi Taller', 'COP', 0.00 
FROM auth.users
ON CONFLICT (usuario_administrador_id) DO NOTHING;

-- Asociar registros existentes al taller correspondiente de su usuario administrador (si aplica).
-- Dado que los registros previos de clientes/vehiculos/etc no tenían dueño directo (o se asumía el único usuario),
-- asociamos todo lo existente al primer taller de cada usuario administrador (o al taller recién creado).
-- Si hay un único usuario administrador, asociamos todo a su taller:
DO $$
DECLARE
  taller_record RECORD;
BEGIN
  FOR taller_record IN SELECT id, usuario_administrador_id FROM public.perfil_taller LOOP
    UPDATE public.clientes SET taller_id = taller_record.id WHERE taller_id IS NULL;
    UPDATE public.vehiculos SET taller_id = taller_record.id WHERE taller_id IS NULL;
    UPDATE public.inventario_repuestos SET taller_id = taller_record.id WHERE taller_id IS NULL;
    UPDATE public.ordenes_mantenimiento SET taller_id = taller_record.id WHERE taller_id IS NULL;
  END LOOP;
END;
$$;

-- 5. RECONSTRUIR REGLAS DE ROW LEVEL SECURITY (RLS) MULTI-TENANT

-- Limpiar políticas anteriores
DROP POLICY IF EXISTS "Acceso autenticado - clientes" ON clientes;
DROP POLICY IF EXISTS "Acceso autenticado - vehiculos" ON vehiculos;
DROP POLICY IF EXISTS "Acceso autenticado - repuestos" ON inventario_repuestos;
DROP POLICY IF EXISTS "Acceso autenticado - ordenes" ON ordenes_mantenimiento;
DROP POLICY IF EXISTS "Acceso autenticado - orden_items" ON orden_items;
DROP POLICY IF EXISTS "Acceso autenticado - historial" ON historial_stock;

-- Nuevas políticas multi-tenant para perfil_taller
CREATE POLICY "Dueño puede acceder a su perfil de taller"
  ON perfil_taller FOR ALL TO authenticated
  USING (usuario_administrador_id = auth.uid())
  WITH CHECK (usuario_administrador_id = auth.uid());

-- Políticas para clientes
CREATE POLICY "Acceso multi-tenant clientes"
  ON clientes FOR ALL TO authenticated
  USING (taller_id IN (SELECT id FROM perfil_taller WHERE usuario_administrador_id = auth.uid()))
  WITH CHECK (taller_id IN (SELECT id FROM perfil_taller WHERE usuario_administrador_id = auth.uid()));

-- Políticas para vehiculos
CREATE POLICY "Acceso multi-tenant vehiculos"
  ON vehiculos FOR ALL TO authenticated
  USING (taller_id IN (SELECT id FROM perfil_taller WHERE usuario_administrador_id = auth.uid()))
  WITH CHECK (taller_id IN (SELECT id FROM perfil_taller WHERE usuario_administrador_id = auth.uid()));

-- Políticas para repuestos
CREATE POLICY "Acceso multi-tenant repuestos"
  ON inventario_repuestos FOR ALL TO authenticated
  USING (taller_id IN (SELECT id FROM perfil_taller WHERE usuario_administrador_id = auth.uid()))
  WITH CHECK (taller_id IN (SELECT id FROM perfil_taller WHERE usuario_administrador_id = auth.uid()));

-- Políticas para ordenes_mantenimiento
CREATE POLICY "Acceso multi-tenant ordenes"
  ON ordenes_mantenimiento FOR ALL TO authenticated
  USING (taller_id IN (SELECT id FROM perfil_taller WHERE usuario_administrador_id = auth.uid()))
  WITH CHECK (taller_id IN (SELECT id FROM perfil_taller WHERE usuario_administrador_id = auth.uid()));

-- Políticas para orden_items (a través de la orden de mantenimiento)
CREATE POLICY "Acceso multi-tenant orden_items"
  ON orden_items FOR ALL TO authenticated
  USING (orden_id IN (
    SELECT id FROM ordenes_mantenimiento 
    WHERE taller_id IN (SELECT id FROM perfil_taller WHERE usuario_administrador_id = auth.uid())
  ))
  WITH CHECK (orden_id IN (
    SELECT id FROM ordenes_mantenimiento 
    WHERE taller_id IN (SELECT id FROM perfil_taller WHERE usuario_administrador_id = auth.uid())
  ));

-- Políticas para historial_stock (a través del repuesto)
CREATE POLICY "Acceso multi-tenant historial"
  ON historial_stock FOR ALL TO authenticated
  USING (repuesto_id IN (
    SELECT id FROM inventario_repuestos 
    WHERE taller_id IN (SELECT id FROM perfil_taller WHERE usuario_administrador_id = auth.uid())
  ))
  WITH CHECK (repuesto_id IN (
    SELECT id FROM inventario_repuestos 
    WHERE taller_id IN (SELECT id FROM perfil_taller WHERE usuario_administrador_id = auth.uid())
  ));

-- 6. CREAR BUCKET PÚBLICO DE ALMACENAMIENTO PARA LOGOTIPOS
-- Si la extensión de storage está activa, insertamos el bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('logos', 'logos', true, 2097152, ARRAY['image/png', 'image/jpeg', 'image/jpg', 'image/webp'])
ON CONFLICT (id) DO NOTHING;

-- Crear políticas para permitir a los usuarios autenticados gestionar sus propios logotipos
CREATE POLICY "Permitir carga pública de logos"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'logos');

CREATE POLICY "Permitir actualización de logos"
  ON storage.objects FOR UPDATE TO authenticated
  USING (bucket_id = 'logos');

CREATE POLICY "Permitir eliminación de logos"
  ON storage.objects FOR DELETE TO authenticated
  USING (bucket_id = 'logos');

CREATE POLICY "Permitir lectura pública de logos"
  ON storage.objects FOR SELECT TO public
  USING (bucket_id = 'logos');

-- ✅ Fin de script de migración
SELECT 'Migración Multi-Tenant ejecutada exitosamente 🚀' AS resultado;
