-- ============================================================
-- MotoTaller App — Módulo de Cotizaciones
-- Script: alter_schema_es_cotizacion.sql
--
-- ⚠️ INSTRUCCIONES DE EJECUCIÓN:
--   1. Ve a Supabase Dashboard → SQL Editor
--   2. Pega este script completo y haz clic en "Run"
-- ============================================================

-- Agregar columna es_cotizacion a ordenes_mantenimiento
ALTER TABLE ordenes_mantenimiento ADD COLUMN IF NOT EXISTS es_cotizacion BOOLEAN DEFAULT FALSE;

-- Confirmación
SELECT 'Columna es_cotizacion añadida exitosamente a ordenes_mantenimiento 🚀' AS resultado;
