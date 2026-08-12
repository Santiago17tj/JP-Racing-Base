-- ============================================================================
--  Mecanix — Alinear el esquema de Supabase con lo que la app envía
--  Proyecto: snzqauzmtydcheryfwmd (JP Racing Base)
--  Escrito el 11/08/2026 sobre el esquema REAL consultado ese día.
--
--  POR QUÉ
--  Al guardar un repuesto en una orden, la app manda columnas que no existen
--  en la nube. Supabase rechaza la escritura entera, la app cae a su base
--  local sin avisar y el detalle se queda en el teléfono. Resultado hoy:
--  14 órdenes en la nube con totales correctos pero CERO ítems.
--
--  Errores capturados en consola:
--    · Could not find the 'descripcion' column of 'orden_items'   (PGRST204)
--    · Could not find the 'orden_id' column of 'historial_stock'  (PGRST204)
--    · column ordenes_mantenimiento.fecha_ingreso does not exist  (42703)
--
--  TODO ES ADITIVO: agrega columnas, no borra ni renombra nada.
--  Ejecutar completo en SQL Editor → Run.
-- ============================================================================


-- ── 1. orden_items — la que rompe el detalle de las facturas ────────────────
-- La app guarda aquí el nombre del trabajo o del repuesto comprado afuera.
-- Sin 'descripcion' no hay forma de saber qué se cobró.
ALTER TABLE orden_items
  ADD COLUMN IF NOT EXISTS descripcion TEXT NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS descuento   NUMERIC(12,2) NOT NULL DEFAULT 0;


-- ── 2. historial_stock — trazabilidad de qué orden consumió el repuesto ─────
-- Las columnas stock_antes / stock_despues ya existen y la app fue ajustada
-- para usar esos nombres; aquí solo falta el vínculo con la orden.
ALTER TABLE historial_stock
  ADD COLUMN IF NOT EXISTS orden_id UUID
    REFERENCES ordenes_mantenimiento(id) ON DELETE SET NULL;


-- ── 3. ordenes_mantenimiento — fecha de ingreso y estado de pago ────────────
-- Sin fecha_ingreso no se puede ordenar el historial en el servidor ni saber
-- cuántos días lleva una moto en el taller.
-- Sin las de pago, los abonos solo viven en el teléfono.
ALTER TABLE ordenes_mantenimiento
  ADD COLUMN IF NOT EXISTS fecha_ingreso   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS monto_pagado    NUMERIC(12,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS saldo_pendiente NUMERIC(12,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS estado_pago     TEXT NOT NULL DEFAULT 'pendiente';

-- Las órdenes que ya existen se quedan con fecha_ingreso = ahora, que no es
-- su fecha real. Se corrige con la fecha de creación, que sí es fiable:
UPDATE ordenes_mantenimiento
SET fecha_ingreso = created_at
WHERE created_at IS NOT NULL;


-- ── 4. Repuestos internos del sistema ───────────────────────────────────────
-- La mano de obra y los repuestos comprados afuera se registran contra estos
-- dos. orden_items.repuesto_id apunta a inventario_repuestos, así que deben
-- existir. Toma tu id de taller de aquí:
--     SELECT id, nombre_taller FROM perfil_taller;
-- y reemplaza <TU_TALLER_ID> en las dos filas.

-- INSERT INTO inventario_repuestos
--   (id, taller_id, nombre, codigo_interno, precio_costo, precio_venta,
--    stock_actual, stock_minimo, categoria, activo)
-- VALUES
--   ('00000000-0000-4000-8000-000000000001', '<TU_TALLER_ID>',
--    'Mano de Obra (Generada)',  'MO-001',  0, 0, 999999, 0, 'otros', true),
--   ('00000000-0000-4000-8000-000000000002', '<TU_TALLER_ID>',
--    'Repuesto Externo General', 'EXT-001', 0, 0, 999999, 0, 'otros', true)
-- ON CONFLICT (id) DO NOTHING;


-- ── 5. Comprobación ─────────────────────────────────────────────────────────
-- ¿'subtotal' de orden_items es una columna calculada? La app la omite al
-- escribir porque en algún momento lo fue. Si esto devuelve 'NEVER', hay que
-- quitar esa omisión en el código (avísame y lo hago).
SELECT column_name, is_generated
FROM information_schema.columns
WHERE table_name = 'orden_items' AND column_name = 'subtotal';

-- Después de migrar: agrega un repuesto desde la app, recarga la página y
-- vuelve a contar. Debe pasar de 0 a 1.
SELECT count(*) AS items_en_la_nube FROM orden_items;


-- ============================================================================
--  AVISO: los ítems de las 14 órdenes anteriores NO se recuperan con esto.
--  Solo existen en el teléfono donde se crearon. Lo que se arregla es que de
--  aquí en adelante sí se guarden en la nube.
-- ============================================================================
