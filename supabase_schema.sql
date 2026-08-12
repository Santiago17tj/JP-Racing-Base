-- ============================================================================
--  Mecanix — esquema REAL de la nube
--  Proyecto: snzqauzmtydcheryfwmd (JP Racing Base)
--
--  ⚠ Este archivo es un RETRATO de la base de producción, no su fuente de
--    verdad. La fuente de verdad es la base. Durante meses este archivo
--    describió un esquema que no existía y nadie lo notó: por ahí se colaron
--    las columnas que la app enviaba y Postgres rechazaba, perdiendo datos en
--    silencio.
--
--  La defensa real contra esa deriva es `test/contrato_esquema_nube_test.dart`,
--  que compara lo que la app envía contra las columnas reales. Si tocas el
--  esquema, actualiza el fixture de esa prueba, no solo este archivo.
--
--  Regenerar con:
--    SELECT table_name, column_name, data_type, is_nullable, column_default,
--           is_generated, generation_expression
--    FROM information_schema.columns WHERE table_schema='public'
--    ORDER BY table_name, ordinal_position;
--
--  Verificado el 11 de agosto de 2026.
-- ============================================================================


-- ── perfil_taller ───────────────────────────────────────────────────────────
-- Un taller por cuenta. `id` es el `taller_id` que llevan las demás tablas y
-- el eje de todas las políticas RLS.
CREATE TABLE public.perfil_taller (
  id                           uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  usuario_administrador_id     uuid NOT NULL UNIQUE REFERENCES auth.users(id),
  nombre_taller                text NOT NULL DEFAULT 'Mi Taller',
  logo_url                     text,
  telefono                     text,
  direccion                    text,
  ciudad                       text,
  moneda                       text NOT NULL DEFAULT 'COP',
  porcentaje_impuesto_defecto  numeric NOT NULL DEFAULT 0.00,
  terminos_condiciones_factura text,
  created_at                   timestamptz NOT NULL DEFAULT now(),
  updated_at                   timestamptz NOT NULL DEFAULT now()
);


-- ── clientes ────────────────────────────────────────────────────────────────
-- Los tres últimos campos son de facturación DIAN. Se añadieron al modelo de
-- la app antes que a la nube: desde el 30/07/2026 hasta el 11/08/2026 ningún
-- cliente nuevo llegó a sincronizar, porque PostgREST rechazaba la fila entera
-- por columna inexistente y el error moría en un `catch`.
CREATE TABLE public.clientes (
  id                    uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  taller_id             uuid REFERENCES public.perfil_taller(id),
  nombre                text NOT NULL,
  apellido              text,
  tipo_documento        text DEFAULT 'DNI',
  numero_documento      text,
  digito_verificacion   text,
  regimen_fiscal        text,
  codigo_municipio_dane text,
  telefono              text,
  email                 text,
  direccion             text,
  ciudad                text,
  notas                 text,
  activo                boolean NOT NULL DEFAULT true,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now()
);


-- ── vehiculos ───────────────────────────────────────────────────────────────
-- Tiene los nombres viejos y los nuevos a la vez: `placa`/`placa_patente` y
-- `kilometraje`/`kilometraje_actual`. La app escribe el nombre nuevo y
-- `_prepareToDb` copia al viejo, que es el NOT NULL.
CREATE TABLE public.vehiculos (
  id                 uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  taller_id          uuid REFERENCES public.perfil_taller(id),
  cliente_id         uuid NOT NULL REFERENCES public.clientes(id),
  placa              text NOT NULL,
  placa_patente      text,
  marca              text NOT NULL,
  modelo             text NOT NULL,
  anio               integer,
  kilometraje        integer DEFAULT 0,
  kilometraje_actual integer DEFAULT 0,
  color              text,
  numero_motor       text,
  numero_chasis      text,
  notas              text,
  activo             boolean NOT NULL DEFAULT true,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz DEFAULT now()
);


-- ── inventario_repuestos ────────────────────────────────────────────────────
-- Contiene además los dos repuestos ficticios del sistema:
--   00000000-0000-4000-8000-000000000001  mano de obra
--   00000000-0000-4000-8000-000000000002  repuesto externo
-- Existen porque `orden_items.repuesto_id` es UUID con llave foránea: sin ellos
-- no se puede registrar un concepto de mano de obra.
CREATE TABLE public.inventario_repuestos (
  id                uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  taller_id         uuid REFERENCES public.perfil_taller(id),
  codigo_interno    text NOT NULL,
  nombre            text NOT NULL,
  descripcion       text,
  foto_url          text,
  categoria         text NOT NULL DEFAULT 'OTROS',
  subcategoria      text,
  marca_repuesto    text,
  numero_parte      text,
  stock_actual      integer NOT NULL DEFAULT 0,
  stock_minimo      integer NOT NULL DEFAULT 5,
  precio_costo      numeric NOT NULL DEFAULT 0,
  precio_venta      numeric NOT NULL DEFAULT 0,
  ubicacion_almacen text,
  unidad_medida     text DEFAULT 'unidad',
  activo            boolean NOT NULL DEFAULT true,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now()
);

-- Único POR TALLER, no global (corregido el 11/08/2026): antes dos talleres no
-- podían usar el mismo código interno.
CREATE UNIQUE INDEX repuestos_codigo_por_taller
  ON public.inventario_repuestos (taller_id, codigo_interno);


-- ── ordenes_mantenimiento ───────────────────────────────────────────────────
-- `costo_mano_obra` es el valor real de la mano de obra. Los ítems de mano de
-- obra en `orden_items` existen solo para el detalle de la factura: sumarlos a
-- `subtotal_repuestos` la cobraría dos veces.
CREATE TABLE public.ordenes_mantenimiento (
  id                   uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  taller_id            uuid REFERENCES public.perfil_taller(id),
  numero_orden         text,
  cliente_id           uuid NOT NULL REFERENCES public.clientes(id),
  vehiculo_id          uuid NOT NULL REFERENCES public.vehiculos(id),
  estado               text NOT NULL DEFAULT 'INGRESADA',
  tipo_servicio        text DEFAULT 'Mantenimiento',
  kilometraje_ingreso  integer DEFAULT 0,
  descripcion_problema text,
  diagnostico          text,
  notas_mecanico       text,
  mecanico_asignado    text,
  fotos_estado         text,
  costo_mano_obra      numeric NOT NULL DEFAULT 0,
  subtotal_repuestos   numeric DEFAULT 0,
  total_estimado       numeric DEFAULT 0,
  monto_pagado         numeric NOT NULL DEFAULT 0,
  saldo_pendiente      numeric NOT NULL DEFAULT 0,
  estado_pago          text NOT NULL DEFAULT 'pendiente',
  es_cotizacion        boolean DEFAULT false,
  activo               boolean NOT NULL DEFAULT true,
  fecha_ingreso        timestamptz NOT NULL DEFAULT now(),
  fecha_promesa        timestamptz,
  fecha_entrega        timestamptz,
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now()
);

-- Único POR TALLER (corregido el 11/08/2026). Antes era global, y como la app
-- calcula el folio por taller —la RLS solo le deja ver los suyos— dos talleres
-- chocaban y la orden no se creaba.
CREATE UNIQUE INDEX ordenes_numero_por_taller
  ON public.ordenes_mantenimiento (taller_id, numero_orden);


-- ── orden_items ─────────────────────────────────────────────────────────────
-- ⚠ `subtotal` es GENERATED ALWAYS: la app NO debe enviarla nunca.
--   `_prepareToDb` la quita; `test/contrato_esquema_nube_test.dart` lo vigila.
--   Desde el 11/08/2026 la expresión respeta el descuento, igual que
--   `OrdenItem.subtotal` en la app; antes lo ignoraba y las dos cifras no
--   coincidían.
CREATE TABLE public.orden_items (
  id              uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  orden_id        uuid NOT NULL REFERENCES public.ordenes_mantenimiento(id),
  repuesto_id     uuid NOT NULL REFERENCES public.inventario_repuestos(id),
  descripcion     text NOT NULL DEFAULT '',
  cantidad        integer NOT NULL DEFAULT 1,
  precio_unitario numeric NOT NULL DEFAULT 0,
  descuento       numeric NOT NULL DEFAULT 0,
  subtotal        numeric GENERATED ALWAYS AS
                    (cantidad::numeric * precio_unitario
                     * (1 - COALESCE(descuento, 0) / 100)) STORED,
  created_at      timestamptz NOT NULL DEFAULT now()
);


-- ── orden_abonos ────────────────────────────────────────────────────────────
-- Creada el 11/08/2026. Antes no existía: la app llevaba meses intentando
-- subir abonos a una tabla ausente, y cada error se perdía en un `catch`.
CREATE TABLE public.orden_abonos (
  id          uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  orden_id    uuid NOT NULL REFERENCES public.ordenes_mantenimiento(id) ON DELETE CASCADE,
  monto       numeric NOT NULL DEFAULT 0,
  metodo_pago text NOT NULL DEFAULT 'efectivo',
  fecha       timestamptz NOT NULL DEFAULT now(),
  notas       text,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_orden_abonos_orden ON public.orden_abonos(orden_id);


-- ── historial_stock ─────────────────────────────────────────────────────────
-- ⚠ Aquí las columnas se llaman `stock_antes` / `stock_despues`. La app usa
--   `stock_anterior` / `stock_posterior` y traduce en `_prepareToDb`.
CREATE TABLE public.historial_stock (
  id              uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  repuesto_id     uuid NOT NULL REFERENCES public.inventario_repuestos(id),
  orden_id        uuid REFERENCES public.ordenes_mantenimiento(id),
  tipo_movimiento text NOT NULL,
  cantidad        integer NOT NULL,
  stock_antes     integer NOT NULL,
  stock_despues   integer NOT NULL,
  motivo          text,
  created_at      timestamptz NOT NULL DEFAULT now()
);


-- ── registro_caja ───────────────────────────────────────────────────────────
CREATE TABLE public.registro_caja (
  id            uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  taller_id     uuid REFERENCES public.perfil_taller(id),
  tipo          text NOT NULL,
  monto         numeric NOT NULL,
  concepto      text NOT NULL,
  referencia_id uuid,
  fecha         timestamptz NOT NULL DEFAULT now()
);


-- ============================================================================
--  Seguridad a nivel de fila
--
--  Las 9 tablas tienen RLS activo con una política `FOR ALL`. El criterio es
--  siempre el mismo: la fila pertenece a un taller cuyo administrador es el
--  usuario de la sesión.
--
--    taller_id IN (SELECT id FROM perfil_taller
--                  WHERE usuario_administrador_id = auth.uid())
--
--  `orden_items` y `orden_abonos` no tienen `taller_id`, así que llegan al
--  taller a través de su orden.
--
--  ⚠ Ojo al comprobarlo: el SQL Editor del dashboard usa rol de servicio y se
--    salta la RLS. El aislamiento se prueba desde la app, autenticado.
--
--  ⚠ Las llaves foráneas NO respetan RLS (Postgres las valida como dueño de la
--    tabla). Un repuesto de otro taller sigue satisfaciendo la FK aunque el
--    usuario no pueda verlo: por eso los dos repuestos ficticios funcionan
--    aunque estén registrados bajo un solo taller.
-- ============================================================================
