-- ════════════════════════════════════════════════════════════════
-- Fix 005 — Corrección de nombre: "Thompson" → "Thimpson"
-- ════════════════════════════════════════════════════════════════
-- El nombre correcto de la marca es "Thimpson" (con 'i'),
-- NO "Thompson" (con 'o'). Este script limpia cualquier
-- referencia incorrecta en la base de datos.
-- ════════════════════════════════════════════════════════════════

BEGIN;

-- 1. Notificaciones con el nombre mal escrito
UPDATE notificaciones
SET    titulo  = REPLACE(titulo,  'Thompson', 'Thimpson'),
       mensaje = REPLACE(mensaje, 'Thompson', 'Thimpson'),
       updated_at = now()
WHERE  titulo  ILIKE '%Thompson%'
   OR  mensaje ILIKE '%Thompson%';

-- 2. Contenido CMS con el nombre mal escrito
UPDATE contenido_cms
SET    valor = REPLACE(valor, 'Thompson', 'Thimpson'),
       updated_at = now()
WHERE  valor ILIKE '%Thompson%';

-- 3. Testimonios con el nombre mal escrito
UPDATE testimonios
SET    nombre = REPLACE(nombre, 'Thompson', 'Thimpson'),
       texto  = REPLACE(texto,  'Thompson', 'Thimpson'),
       updated_at = now()
WHERE  nombre ILIKE '%Thompson%'
   OR  texto  ILIKE '%Thompson%';

-- 4. Sesiones de chat IA con el nombre mal escrito
UPDATE sesiones_chat_ia
SET    mensajes = (
         SELECT jsonb_agg(
           CASE
             WHEN msg->>'contenido' ILIKE '%Thompson%'
             THEN jsonb_set(msg, '{contenido}', to_jsonb(REPLACE(msg->>'contenido', 'Thompson', 'Thimpson')))
             ELSE msg
           END
         )
         FROM jsonb_array_elements(mensajes) AS msg
       ),
       updated_at = now()
WHERE  mensajes::text ILIKE '%Thompson%';

-- 5. Negocios afiliados con el nombre mal escrito
UPDATE negocios
SET    nombre = REPLACE(nombre, 'Thompson', 'Thimpson'),
       descripcion = REPLACE(descripcion, 'Thompson', 'Thimpson'),
       updated_at = now()
WHERE  nombre ILIKE '%Thompson%'
   OR  descripcion ILIKE '%Thompson%';

-- 6. Sucursales con el nombre mal escrito
UPDATE sucursales
SET    nombre = REPLACE(nombre, 'Thompson', 'Thimpson'),
       updated_at = now()
WHERE  nombre ILIKE '%Thompson%';

COMMIT;

-- Reporte de registros afectados
SELECT 'notificaciones'  AS tabla, COUNT(*) AS corregidos FROM notificaciones WHERE titulo ILIKE '%Thompson%' OR mensaje ILIKE '%Thompson%'
UNION ALL
SELECT 'contenido_cms'   AS tabla, COUNT(*) AS corregidos FROM contenido_cms WHERE valor ILIKE '%Thompson%'
UNION ALL
SELECT 'testimonios'     AS tabla, COUNT(*) AS corregidos FROM testimonios WHERE nombre ILIKE '%Thompson%' OR texto ILIKE '%Thompson%'
UNION ALL
SELECT 'negocios'        AS tabla, COUNT(*) AS corregidos FROM negocios WHERE nombre ILIKE '%Thompson%' OR descripcion ILIKE '%Thompson%'
UNION ALL
SELECT 'sucursales'      AS tabla, COUNT(*) AS corregidos FROM sucursales WHERE nombre ILIKE '%Thompson%';
