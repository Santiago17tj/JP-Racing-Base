-- ============================================================
-- MotoTaller App — Módulo Contable y Flujo de Caja (SaaS)
-- Script: alter_schema_registro_caja.sql
--
-- ⚠️ INSTRUCCIONES DE EJECUCIÓN:
--   1. Ve a Supabase Dashboard → SQL Editor
--   2. Pega este script completo y haz clic en "Run"
-- ============================================================

-- 1. CREAR LA TABLA DE REGISTRO DE CAJA
CREATE TABLE IF NOT EXISTS registro_caja (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  taller_id     UUID REFERENCES perfil_taller(id) ON DELETE CASCADE,
  tipo          TEXT NOT NULL CHECK (tipo IN ('ingreso', 'egreso')),
  monto         NUMERIC(12, 2) NOT NULL CHECK (monto >= 0),
  concepto      TEXT NOT NULL,
  referencia_id UUID, -- ID de la orden asociada para evitar duplicados
  fecha         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Habilitar RLS en registro_caja
ALTER TABLE registro_caja ENABLE ROW LEVEL SECURITY;

-- Crear Índices de Desempeño
CREATE INDEX IF NOT EXISTS idx_registro_caja_taller ON registro_caja(taller_id);
CREATE INDEX IF NOT EXISTS idx_registro_caja_fecha ON registro_caja(fecha);

-- Políticas RLS para aislamiento multi-tenant
DROP POLICY IF EXISTS "Acceso multi-tenant registro_caja" ON registro_caja;
CREATE POLICY "Acceso multi-tenant registro_caja"
  ON registro_caja FOR ALL TO authenticated
  USING (taller_id IN (SELECT id FROM perfil_taller WHERE usuario_administrador_id = auth.uid()))
  WITH CHECK (taller_id IN (SELECT id FROM perfil_taller WHERE usuario_administrador_id = auth.uid()));

-- Confirmación
SELECT 'Tabla registro_caja creada y políticas RLS configuradas exitosamente 🚀' AS resultado;
