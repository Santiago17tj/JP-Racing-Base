-- ============================================================
-- MotoTaller App — Esquema de Base de Datos Sincronizado en Supabase
-- Ejecuta este script en: Supabase Dashboard → SQL Editor → New Query → Run
-- ============================================================

-- ── 0. Limpieza (Opcional - Elimina tablas antiguas para recrear) ──
DROP TABLE IF EXISTS historial_stock CASCADE;
DROP TABLE IF EXISTS orden_items CASCADE;
DROP TABLE IF EXISTS ordenes_mantenimiento CASCADE;
DROP TABLE IF EXISTS inventario_repuestos CASCADE;
DROP TABLE IF EXISTS vehiculos CASCADE;
DROP TABLE IF EXISTS clientes CASCADE;

-- Habilitar extensión UUID
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ── 1. CLIENTES ─────────────────────────────────────────────
CREATE TABLE clientes (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  nombre            TEXT NOT NULL,
  apellido          TEXT NOT NULL,
  tipo_documento    TEXT NOT NULL,
  numero_documento  TEXT NOT NULL UNIQUE,
  email             TEXT,
  telefono          TEXT NOT NULL,
  direccion         TEXT,
  ciudad            TEXT,
  notas             TEXT,
  activo            BOOLEAN NOT NULL DEFAULT true,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── 2. VEHÍCULOS ────────────────────────────────────────────
CREATE TABLE vehiculos (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  cliente_id          UUID NOT NULL REFERENCES clientes(id) ON DELETE CASCADE,
  placa_patente       TEXT NOT NULL UNIQUE,
  marca               TEXT NOT NULL,
  modelo              TEXT NOT NULL,
  anio                INTEGER NOT NULL,
  kilometraje_actual  INTEGER NOT NULL DEFAULT 0,
  color               TEXT,
  numero_motor        TEXT,
  numero_chasis       TEXT,
  notas               TEXT,
  activo              BOOLEAN NOT NULL DEFAULT true,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── 3. INVENTARIO DE REPUESTOS ──────────────────────────────
CREATE TABLE inventario_repuestos (
  id                 UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  codigo_interno     TEXT NOT NULL UNIQUE,
  nombre             TEXT NOT NULL,
  descripcion        TEXT,
  foto_url           TEXT,
  categoria          TEXT NOT NULL DEFAULT 'OTROS',
  subcategoria       TEXT,
  marca_repuesto     TEXT,
  numero_parte       TEXT,
  stock_actual       INTEGER NOT NULL DEFAULT 0 CHECK(stock_actual >= 0),
  stock_minimo       INTEGER NOT NULL DEFAULT 5 CHECK(stock_minimo >= 0),
  precio_costo       NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK(precio_costo >= 0),
  precio_venta       NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK(precio_venta >= 0),
  ubicacion_almacen  TEXT,
  unidad_medida      TEXT DEFAULT 'unidad',
  activo             BOOLEAN NOT NULL DEFAULT true,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── 4. ÓRDENES DE MANTENIMIENTO ─────────────────────────────
CREATE TABLE ordenes_mantenimiento (
  id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  numero_orden          TEXT NOT NULL UNIQUE,
  cliente_id            UUID NOT NULL REFERENCES clientes(id) ON DELETE CASCADE,
  vehiculo_id           UUID NOT NULL REFERENCES vehiculos(id) ON DELETE CASCADE,
  estado                TEXT NOT NULL DEFAULT 'INGRESADA',
  tipo_servicio         TEXT NOT NULL,
  kilometraje_ingreso   INTEGER NOT NULL DEFAULT 0,
  descripcion_problema  TEXT,
  diagnostico           TEXT,
  notas_mecanico        TEXT,
  mecanico_asignado     TEXT,
  costo_mano_obra       NUMERIC(12,2) NOT NULL DEFAULT 0,
  subtotal_repuestos    NUMERIC(12,2) NOT NULL DEFAULT 0,
  total_estimado        NUMERIC(12,2) NOT NULL DEFAULT 0,
  fecha_ingreso         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  fecha_promesa         TIMESTAMPTZ,
  fecha_entrega         TIMESTAMPTZ,
  activo                BOOLEAN NOT NULL DEFAULT true,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── 5. ÍTEMS DE ORDEN ───────────────────────────────────────
CREATE TABLE orden_items (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  orden_id         UUID NOT NULL REFERENCES ordenes_mantenimiento(id) ON DELETE CASCADE,
  repuesto_id      UUID NOT NULL REFERENCES inventario_repuestos(id) ON DELETE CASCADE,
  descripcion      TEXT NOT NULL,
  cantidad         INTEGER NOT NULL DEFAULT 1,
  precio_unitario  NUMERIC(12,2) NOT NULL DEFAULT 0,
  descuento        NUMERIC(12,2) NOT NULL DEFAULT 0,
  subtotal         NUMERIC(12,2) NOT NULL DEFAULT 0,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── 6. HISTORIAL DE STOCK ───────────────────────────────────
CREATE TABLE historial_stock (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  repuesto_id      UUID NOT NULL REFERENCES inventario_repuestos(id) ON DELETE CASCADE,
  orden_id         UUID REFERENCES ordenes_mantenimiento(id) ON DELETE SET NULL,
  tipo_movimiento  TEXT NOT NULL,
  cantidad         INTEGER NOT NULL,
  stock_anterior   INTEGER NOT NULL,
  stock_posterior  INTEGER NOT NULL,
  motivo           TEXT,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- ÍNDICES para optimización de consultas
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_vehiculos_cliente     ON vehiculos(cliente_id);
CREATE INDEX IF NOT EXISTS idx_ordenes_vehiculo      ON ordenes_mantenimiento(vehiculo_id);
CREATE INDEX IF NOT EXISTS idx_ordenes_cliente       ON ordenes_mantenimiento(cliente_id);
CREATE INDEX IF NOT EXISTS idx_ordenes_estado        ON ordenes_mantenimiento(estado);
CREATE INDEX IF NOT EXISTS idx_orden_items_orden     ON orden_items(orden_id);
CREATE INDEX IF NOT EXISTS idx_historial_repuesto    ON historial_stock(repuesto_id);
CREATE INDEX IF NOT EXISTS idx_repuestos_categoria   ON inventario_repuestos(categoria);
CREATE INDEX IF NOT EXISTS idx_repuestos_stock_bajo  ON inventario_repuestos(stock_actual, stock_minimo);

-- ============================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================
ALTER TABLE clientes               ENABLE ROW LEVEL SECURITY;
ALTER TABLE vehiculos              ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventario_repuestos   ENABLE ROW LEVEL SECURITY;
ALTER TABLE ordenes_mantenimiento  ENABLE ROW LEVEL SECURITY;
ALTER TABLE orden_items            ENABLE ROW LEVEL SECURITY;
ALTER TABLE historial_stock        ENABLE ROW LEVEL SECURITY;

-- Políticas: usuarios autenticados tienen acceso total a sus datos
CREATE POLICY "Acceso autenticado - clientes"
  ON clientes FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Acceso autenticado - vehiculos"
  ON vehiculos FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Acceso autenticado - repuestos"
  ON inventario_repuestos FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Acceso autenticado - ordenes"
  ON ordenes_mantenimiento FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Acceso autenticado - orden_items"
  ON orden_items FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Acceso autenticado - historial"
  ON historial_stock FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ============================================================
-- TRIGGER: auto-actualizar updated_at
-- ============================================================
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_clientes_updated_at
  BEFORE UPDATE ON clientes
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_vehiculos_updated_at
  BEFORE UPDATE ON vehiculos
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_repuestos_updated_at
  BEFORE UPDATE ON inventario_repuestos
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_ordenes_updated_at
  BEFORE UPDATE ON ordenes_mantenimiento
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================
-- DATOS SEMILLA DE PRUEBA (Para tener repuestos cargados al iniciar)
-- ============================================================
INSERT INTO inventario_repuestos (id, codigo_interno, nombre, descripcion, categoria, marca_repuesto, numero_parte, stock_actual, stock_minimo, precio_costo, precio_venta, ubicacion_almacen, unidad_medida)
VALUES
  ('a1b2c3d4-e5f6-7890-abcd-ef1234567801', 'FRE-001', 'Pastillas de Freno Delanteras', 'Pastillas de freno sinterizadas para uso en calle y pista', 'FRENOS', 'Brembo', 'BP-SX200', 12, 5, 18.50, 32.00, 'Estante A-1', 'par'),
  ('a1b2c3d4-e5f6-7890-abcd-ef1234567802', 'FRE-002', 'Disco de Freno Trasero 220mm', 'Disco de freno flotante de acero inoxidable', 'FRENOS', 'EBC', 'DF-220T', 3, 4, 45.00, 78.50, 'Estante A-2', 'unidad'),
  ('a1b2c3d4-e5f6-7890-abcd-ef1234567803', 'MOT-001', 'Filtro de Aceite HF204', 'Filtro de aceite de alta calidad para motores 4T', 'FILTROS', 'HiFlo', 'HF204', 25, 10, 5.20, 12.00, 'Estante B-1', 'unidad'),
  ('a1b2c3d4-e5f6-7890-abcd-ef1234567804', 'MOT-002', 'Bujía Iridium CR9EIX', 'Bujía de iridio para mejor rendimiento y durabilidad', 'MOTOR', 'NGK', 'CR9EIX', 8, 10, 9.80, 18.50, 'Estante B-2', 'unidad'),
  ('a1b2c3d4-e5f6-7890-abcd-ef1234567805', 'ELE-001', 'Regulador de Voltaje SH847', 'Regulador/rectificador de voltaje universal', 'ELECTRICO', 'Shindengen', 'SH847AA', 2, 3, 32.00, 55.00, 'Estante C-1', 'unidad'),
  ('a1b2c3d4-e5f6-7890-abcd-ef1234567806', 'LUB-001', 'Aceite Motor 10W-40 Full Synthetic', 'Aceite sintético de alto rendimiento para motocicletas 4T', 'LUBRICANTES', 'Motul', '7100-10W40', 30, 15, 12.50, 22.00, 'Estante D-1', 'litro'),
  ('a1b2c3d4-e5f6-7890-abcd-ef1234567807', 'TRA-001', 'Kit de Arrastre 428H (14-42)', 'Kit completo: cadena DID 428H + piñón 14T + corona 42T', 'TRANSMISION', 'DID', 'KIT-428H-1442', 0, 3, 38.00, 65.00, 'Estante E-1', 'kit')
ON CONFLICT (codigo_interno) DO NOTHING;

-- ✅ Script ejecutado correctamente
SELECT 'Esquema de Base de Datos MotoTaller Sincronizado Exitosamente 🏍️' AS resultado;
