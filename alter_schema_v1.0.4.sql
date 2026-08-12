-- ============================================================
-- MotoTaller App — Parches finales de Esquema para Supabase
-- Script: alter_schema_v1.0.4.sql
--
-- ⚠️ INSTRUCCIONES DE EJECUCIÓN:
--   1. Ve a Supabase Dashboard → SQL Editor
--   2. Pega este script completo y haz clic en "Run"
-- ============================================================

-- 1. Agregar columna fotos_estado a la tabla ordenes_mantenimiento si no existe
ALTER TABLE ordenes_mantenimiento ADD COLUMN IF NOT EXISTS fotos_estado TEXT;

-- 2. Asegurar que la columna es_cotizacion existe en ordenes_mantenimiento
ALTER TABLE ordenes_mantenimiento ADD COLUMN IF NOT EXISTS es_cotizacion BOOLEAN DEFAULT FALSE;

-- 3. Asegurar que la columna apellido existe en clientes
ALTER TABLE clientes ADD COLUMN IF NOT EXISTS apellido TEXT;

-- 4. Quitar restricción de check de estado antiguo para evitar conflictos
ALTER TABLE ordenes_mantenimiento DROP CONSTRAINT IF EXISTS ordenes_mantenimiento_estado_check;

-- 5. Forzar recarga del caché de esquema en Supabase
NOTIFY pgrst, 'reload schema';

-- Confirmación
SELECT 'Parches v1.0.10 aplicados exitosamente en Supabase 🚀' AS resultado;
