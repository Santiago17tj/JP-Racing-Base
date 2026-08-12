-- ============================================================================
--  Mecanix — correcciones de seguridad de Supabase
--  Proyecto: snzqauzmtydcheryfwmd (JP Racing Base)
--
--  ESTADO: aplicado el 11 de agosto de 2026.
--  El Security Advisor pasó de 6 advertencias a 1, y la que queda no se
--  arregla con SQL (ver el final del archivo).
--
--  Se conserva como registro de qué se hizo y por qué.
--
--  ⚠ La versión anterior de este archivo NO habría funcionado: llamaba a las
--    funciones `manejar_nuevo_usuario` y `actualizar_actualizado_en`, que no
--    existen. Se llaman `handle_new_user` y `update_updated_at`. Nadie lo
--    detectó porque el archivo nunca se ejecutó. Comprobar antes de fiarse:
--
--      SELECT proname, prosecdef, proconfig FROM pg_proc p
--      JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname='public';
-- ============================================================================


-- ── 1. Fijar el search_path de las funciones ────────────────────────────────
-- Sin search_path fijo, un usuario puede crear un esquema propio con tablas
-- que suplanten a las reales y lograr que la función las use. En
-- `handle_new_user`, que es SECURITY DEFINER, eso es escalada de privilegios.
--
-- Se usa 'public' (no cadena vacía) para no romper las funciones actuales, que
-- referencian tablas sin calificar el esquema.

ALTER FUNCTION public.handle_new_user()   SET search_path = public, pg_temp;
ALTER FUNCTION public.update_updated_at() SET search_path = public, pg_temp;


-- ── 2. Quitar el permiso de ejecución pública del trigger de alta ───────────
-- `handle_new_user()` se dispara como trigger cuando nace un usuario en
-- auth.users. Nadie debería poder invocarla a mano: al ser SECURITY DEFINER,
-- llamarla directamente corre con privilegios elevados.

REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM anon;
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM authenticated;


-- ── 3. Comprobación: ninguna tabla sin RLS ni sin políticas ─────────────────
-- Debe devolver cero filas. Si aparece alguna, esa tabla está expuesta a
-- cualquiera que tenga la clave pública de la app.
-- Al 11/08/2026: las 9 tablas con RLS y una política cada una.

SELECT
  c.relname          AS tabla,
  c.relrowsecurity   AS rls_activo,
  count(p.policyname) AS politicas
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
LEFT JOIN pg_policies p
       ON p.schemaname = n.nspname AND p.tablename = c.relname
WHERE n.nspname = 'public'
  AND c.relkind = 'r'
GROUP BY c.relname, c.relrowsecurity
HAVING c.relrowsecurity = false OR count(p.policyname) = 0;


-- ── 4. Prueba de aislamiento entre talleres ────────────────────────────────
-- El SQL Editor usa rol de servicio y se salta la RLS, así que aquí no prueba
-- nada. Hay que hacerlo desde la app, autenticado con dos cuentas distintas:
--   final r = await SupabaseService.client.from('ordenes_mantenimiento').select();
-- Si una cuenta ve órdenes de la otra, hay fuga de datos.


-- ============================================================================
--  Lo que queda, y no se arregla con SQL:
--
--  a) Protección de contraseñas filtradas — Authentication → Policies →
--     activar "Leaked password protection". Es un interruptor. Bloquea
--     contraseñas aparecidas en filtraciones conocidas (HaveIBeenPwned).
--     Es la única advertencia que sigue abierta en el advisor.
--
--  b) Bucket público 'logos' — Storage → logos. Hoy cualquiera con la URL ve
--     los logos. Para un logo comercial es aceptable; si alguna vez guardas
--     ahí fotos de motos o documentos de clientes, hay que volverlo privado y
--     servir con URLs firmadas.
-- ============================================================================
