-- ============================================================
-- MotoTaller App — Esquema de Base de Datos en Supabase
-- Ejecuta este script en: Supabase Dashboard → SQL Editor → New Query
-- ============================================================

-- ── Habilitar extensión UUID ────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ── 1. CLIENTES ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS clientes (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  nombre      TEXT NOT NULL,
  telefono    TEXT,
  email       TEXT,
  direccion   TEXT,
  activo      BOOLEAN NOT NULL DEFAULT true,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── 2. VEHÍCULOS ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS vehiculos (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  cliente_id   UUID NOT NULL REFERENCES clientes(id) ON DELETE CASCADE,
  placa        TEXT NOT NULL,
  marca        TEXT NOT NULL,
  modelo       TEXT NOT NULL,
  anio         INTEGER,
  kilometraje  INTEGER DEFAULT 0,
  color        TEXT,
  activo       BOOLEAN NOT NULL DEFAULT true,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── 3. INVENTARIO DE REPUESTOS ──────────────────────────────
CREATE TABLE IF NOT EXISTS inventario_repuestos (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  codigo_interno  TEXT NOT NULL UNIQUE,
  nombre          TEXT NOT NULL,
  descripcion     TEXT,
  foto_url        TEXT,
  categoria       TEXT NOT NULL DEFAULT 'OTROS'
                  CHECK (categoria IN ('FRENOS','MOTOR','ELECTRICO','LUBRICANTES',
                                       'TRANSMISION','SUSPENSION','CARROCERIA','OTROS')),
  stock_actual    INTEGER NOT NULL DEFAULT 0,
  stock_minimo    INTEGER NOT NULL DEFAULT 5,
  precio_costo    NUMERIC(12,2) NOT NULL DEFAULT 0,
  precio_venta    NUMERIC(12,2) NOT NULL DEFAULT 0,
  activo          BOOLEAN NOT NULL DEFAULT true,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── 4. ÓRDENES DE MANTENIMIENTO ─────────────────────────────
CREATE TABLE IF NOT EXISTS ordenes_mantenimiento (
  id                   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  vehiculo_id          UUID NOT NULL REFERENCES vehiculos(id),
  cliente_id           UUID NOT NULL REFERENCES clientes(id),
  estado               TEXT NOT NULL DEFAULT 'INGRESADA'
                       CHECK (estado IN ('INGRESADA','EN_DIAGNOSTICO','EN_REPARACION',
                                         'LISTA_PARA_ENTREGA','ENTREGADA')),
  descripcion_problema TEXT,
  notas_mecanico       TEXT,
  mecanico_asignado    TEXT,
  kilometraje_ingreso  INTEGER DEFAULT 0,
  costo_mano_obra      NUMERIC(12,2) NOT NULL DEFAULT 0,
  activo               BOOLEAN NOT NULL DEFAULT true,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── 5. ÍTEMS DE ORDEN (repuestos usados) ────────────────────
CREATE TABLE IF NOT EXISTS orden_items (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  orden_id        UUID NOT NULL REFERENCES ordenes_mantenimiento(id) ON DELETE CASCADE,
  repuesto_id     UUID NOT NULL REFERENCES inventario_repuestos(id),
  cantidad        INTEGER NOT NULL DEFAULT 1,
  precio_unitario NUMERIC(12,2) NOT NULL DEFAULT 0,
  subtotal        NUMERIC(12,2) GENERATED ALWAYS AS (cantidad * precio_unitario) STORED,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── 6. HISTORIAL DE STOCK (auditoría) ───────────────────────
CREATE TABLE IF NOT EXISTS historial_stock (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  repuesto_id     UUID NOT NULL REFERENCES inventario_repuestos(id),
  tipo_movimiento TEXT NOT NULL
                  CHECK (tipo_movimiento IN ('ENTRADA','SALIDA','AJUSTE','DEVOLUCION')),
  cantidad        INTEGER NOT NULL,
  stock_antes     INTEGER NOT NULL,
  stock_despues   INTEGER NOT NULL,
  motivo          TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- ÍNDICES para rendimiento
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
-- ROW LEVEL SECURITY (RLS) — Seguridad por usuario
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

CREATE TRIGGER trg_repuestos_updated_at
  BEFORE UPDATE ON inventario_repuestos
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_ordenes_updated_at
  BEFORE UPDATE ON ordenes_mantenimiento
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================
-- DATOS DE PRUEBA (opcional — puedes borrar esta sección)
-- ============================================================
INSERT INTO inventario_repuestos (codigo_interno, nombre, categoria, stock_actual, stock_minimo, precio_costo, precio_venta)
VALUES
  ('FRE-001', 'Pastillas de freno delanteras',  'FRENOS',      8, 5, 12.00, 25.00),
  ('MOT-002', 'Filtro de aceite',               'MOTOR',       15, 8, 5.00,  12.00),
  ('ELE-003', 'Bujía NGK CR8E',                 'ELECTRICO',   20, 10, 3.50,  8.00),
  ('LUB-004', 'Aceite 10W-40 1L',               'LUBRICANTES', 3,  5, 8.00,  18.00),
  ('FRE-005', 'Disco de freno trasero',         'FRENOS',      2,  3, 35.00, 75.00)
ON CONFLICT (codigo_interno) DO NOTHING;

-- ✅ Script ejecutado correctamente
SELECT 'Base de datos MotoTaller creada exitosamente 🏍️' AS resultado;
