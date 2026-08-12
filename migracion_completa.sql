-- ============================================================
-- MotoTaller App — Migración y Reparación de Esquema Completo
-- Script: migracion_completa.sql
--
-- ⚠️ INSTRUCCIONES DE EJECUCIÓN:
--   1. Ve a Supabase Dashboard → SQL Editor
--   2. Pega este script completo y haz clic en "Run"
-- ============================================================

-- 1. REPARACIÓN DE LA TABLA: clientes
ALTER TABLE clientes ADD COLUMN IF NOT EXISTS apellido TEXT;
ALTER TABLE clientes ADD COLUMN IF NOT EXISTS tipo_documento TEXT DEFAULT 'DNI';
ALTER TABLE clientes ADD COLUMN IF NOT EXISTS numero_documento TEXT;
ALTER TABLE clientes ADD COLUMN IF NOT EXISTS ciudad TEXT;
ALTER TABLE clientes ADD COLUMN IF NOT EXISTS notas TEXT;
ALTER TABLE clientes ADD COLUMN IF NOT EXISTS taller_id UUID REFERENCES perfil_taller(id) ON DELETE CASCADE;

-- 2. REPARACIÓN DE LA TABLA: vehiculos
ALTER TABLE vehiculos ADD COLUMN IF NOT EXISTS placa_patente TEXT;
ALTER TABLE vehiculos ADD COLUMN IF NOT EXISTS kilometraje_actual INTEGER DEFAULT 0;
ALTER TABLE vehiculos ADD COLUMN IF NOT EXISTS numero_motor TEXT;
ALTER TABLE vehiculos ADD COLUMN IF NOT EXISTS numero_chasis TEXT;
ALTER TABLE vehiculos ADD COLUMN IF NOT EXISTS notas TEXT;
ALTER TABLE vehiculos ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE vehiculos ADD COLUMN IF NOT EXISTS taller_id UUID REFERENCES perfil_taller(id) ON DELETE CASCADE;

-- Migrar datos de columnas viejas si existen
UPDATE vehiculos SET placa_patente = placa WHERE placa_patente IS NULL AND placa IS NOT NULL;
UPDATE vehiculos SET kilometraje_actual = kilometraje WHERE (kilometraje_actual = 0 OR kilometraje_actual IS NULL) AND kilometraje IS NOT NULL;

-- 3. REPARACIÓN DE LA TABLA: inventario_repuestos
ALTER TABLE inventario_repuestos ADD COLUMN IF NOT EXISTS subcategoria TEXT;
ALTER TABLE inventario_repuestos ADD COLUMN IF NOT EXISTS marca_repuesto TEXT;
ALTER TABLE inventario_repuestos ADD COLUMN IF NOT EXISTS numero_parte TEXT;
ALTER TABLE inventario_repuestos ADD COLUMN IF NOT EXISTS ubicacion_almacen TEXT;
ALTER TABLE inventario_repuestos ADD COLUMN IF NOT EXISTS unidad_medida TEXT DEFAULT 'unidad';
ALTER TABLE inventario_repuestos ADD COLUMN IF NOT EXISTS taller_id UUID REFERENCES perfil_taller(id) ON DELETE CASCADE;

-- Quitar check restrictivo antiguo de categorías si existe
ALTER TABLE inventario_repuestos DROP CONSTRAINT IF EXISTS inventario_repuestos_categoria_check;

-- 4. REPARACIÓN DE LA TABLA: ordenes_mantenimiento
ALTER TABLE ordenes_mantenimiento ADD COLUMN IF NOT EXISTS numero_orden TEXT;
ALTER TABLE ordenes_mantenimiento ADD COLUMN IF NOT EXISTS tipo_servicio TEXT DEFAULT 'Mantenimiento';
ALTER TABLE ordenes_mantenimiento ADD COLUMN IF NOT EXISTS subtotal_repuestos NUMERIC(12,2) DEFAULT 0;
ALTER TABLE ordenes_mantenimiento ADD COLUMN IF NOT EXISTS total_estimado NUMERIC(12,2) DEFAULT 0;
ALTER TABLE ordenes_mantenimiento ADD COLUMN IF NOT EXISTS fecha_promesa TIMESTAMPTZ;
ALTER TABLE ordenes_mantenimiento ADD COLUMN IF NOT EXISTS fecha_entrega TIMESTAMPTZ;
ALTER TABLE ordenes_mantenimiento ADD COLUMN IF NOT EXISTS diagnostico TEXT;
ALTER TABLE ordenes_mantenimiento ADD COLUMN IF NOT EXISTS es_cotizacion BOOLEAN DEFAULT FALSE;
ALTER TABLE ordenes_mantenimiento ADD COLUMN IF NOT EXISTS fotos_estado TEXT;
ALTER TABLE ordenes_mantenimiento ADD COLUMN IF NOT EXISTS taller_id UUID REFERENCES perfil_taller(id) ON DELETE CASCADE;

-- Rellenar campos obligatorios vacíos para registros históricos
UPDATE ordenes_mantenimiento SET numero_orden = 'ORD-' || substring(id::text, 1, 8) WHERE numero_orden IS NULL;
UPDATE ordenes_mantenimiento SET tipo_servicio = 'Mantenimiento' WHERE tipo_servicio IS NULL;

-- Crear índice UNIQUE para evitar duplicados en numero_orden
ALTER TABLE ordenes_mantenimiento DROP CONSTRAINT IF EXISTS ordenes_mantenimiento_numero_orden_key;
ALTER TABLE ordenes_mantenimiento ADD CONSTRAINT ordenes_mantenimiento_numero_orden_key UNIQUE (numero_orden);

-- Quitar restricción de check de estado antiguo para evitar conflictos
ALTER TABLE ordenes_mantenimiento DROP CONSTRAINT IF EXISTS ordenes_mantenimiento_estado_check;

-- 5. FORZAR RECARGA DE CACHÉ EN POSTGREST (OBLIGATORIO)
NOTIFY pgrst, 'reload schema';

-- Mensaje de éxito
SELECT 'Esquema de base de datos reparado y sincronizado al 100% con la app móvil. ¡Listo para usar! 🚀' AS resultado;
