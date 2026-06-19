-- ============================================================
-- SERVICIO EXPRESS THIMPSON
-- Migración 002: Soporte completo de caracteres latinoamericanos
-- ============================================================
-- Repositorio: ThimpsonExpressDB
-- Versión    : 2.0.0
-- ⚠️  Ejecutar DESPUÉS de 001_esquema_inicial.sql
-- ============================================================
-- Qué instala este archivo:
--   ✅ Extensión unaccent (búsquedas sin acentos: café = cafe)
--   ✅ Collation ICU es-419 (español latinoamericano, estándar Unicode)
--   ✅ Ordenamiento correcto: ñ entre n y o, á ordena como a
--   ✅ Collation insensible a mayúsculas: Juan = juan = JUAN
--   ✅ Configuración de búsqueda de texto en español
--   ✅ Función normalizar_texto() para comparaciones limpias
--   ✅ Full-text search en español para el marketplace
--   ✅ Búsquedas sin importar acentos ni mayúsculas
-- ============================================================


-- ============================================================
-- EXTENSIONES ADICIONALES
-- ============================================================

-- unaccent: elimina acentos antes de comparar o buscar textos
-- Ejemplo: café → cafe, Ñoño → Nono, José → Jose
-- Sin esta extensión, buscar "cafe" no encontraría "café"
CREATE EXTENSION IF NOT EXISTS unaccent;

-- btree_gist: permite crear índices combinados (texto + geo, texto + fecha)
-- Útil para búsquedas complejas que mezclan múltiples columnas
CREATE EXTENSION IF NOT EXISTS btree_gist;


-- ============================================================
-- COLLATIONS ICU PARA ESPAÑOL LATINOAMERICANO
-- ============================================================
-- Un collation define las reglas de comparación y ordenamiento
-- de texto en un idioma específico. Sin un collation correcto:
--   • 'ñ' se ordenaría en posiciones incorrectas
--   • 'á' no se reconocería como variante de 'a' al comparar
--   • 'Ocotal' y 'ocotal' se tratarían como distintas
--
-- Los collations ICU usan el estándar internacional BCP 47 de Unicode.
-- 'es-419' = Español para América Latina y el Caribe (ISO 639-1 + UN M.49)
-- Esto garantiza compatibilidad con todos los caracteres del español
-- de Nicaragua, Honduras, México, Colombia y toda Latinoamérica.
-- ============================================================

-- Collation estándar para ordenar textos en español latinoamericano
-- Uso: columnas TEXT con orden natural en español
-- DETERMINISTIC = TRUE → puede usarse en columnas UNIQUE y PRIMARY KEY
CREATE COLLATION IF NOT EXISTS latinoamericano (
  PROVIDER      = icu,
  LOCALE        = 'es-419',
  DETERMINISTIC = TRUE
);

-- Collation insensible a mayúsculas para búsquedas
-- Ejemplo: 'ocotal' = 'Ocotal' = 'OCOTAL'
-- ⚠️  DETERMINISTIC = FALSE → NO puede usarse en columnas UNIQUE ni PRIMARY KEY
--     Solo se usa en índices de búsqueda y comparaciones, no en constraints
CREATE COLLATION IF NOT EXISTS latinoamericano_ci (
  PROVIDER      = icu,
  LOCALE        = 'es-419-u-ks-level2', -- ks-level2 activa la comparación insensible a mayúsculas
  DETERMINISTIC = FALSE
);


-- ============================================================
-- CONFIGURACIÓN DE BÚSQUEDA DE TEXTO EN ESPAÑOL
-- ============================================================
-- PostgreSQL incluye un motor de búsqueda de texto completo.
-- Para español necesitamos configurarlo con:
--   1. Diccionario de stopwords en español (ignora: el, la, de, y, en...)
--   2. Stemming en español (pedido → pedir, corriendo → correr)
--   3. Unaccent (café → cafe antes de indexar)
-- Con estas tres capas, buscar "cafe" encuentra "café",
-- buscar "pedidos" encuentra "pedido" y "pedir",
-- y "el delivery" elimina "el" (stopword) y busca solo "delivery".
-- ============================================================
CREATE TEXT SEARCH CONFIGURATION IF NOT EXISTS espanol_sin_acento (COPY = spanish);

-- Agrega unaccent al flujo de análisis de texto para palabras, títulos y URLs
ALTER TEXT SEARCH CONFIGURATION espanol_sin_acento
  ALTER MAPPING FOR hword, compound, word, hword_part, url, email
  WITH unaccent, spanish_stem;

-- Intentar establecer espanol_sin_acento como configuración por defecto del proyecto.
-- Requiere permisos de superusuario. Si falla, usar el parámetro explícitamente:
-- TO_TSVECTOR('espanol_sin_acento', texto)
DO $$
BEGIN
  EXECUTE 'ALTER DATABASE postgres SET default_text_search_config = ''espanol_sin_acento''';
EXCEPTION WHEN others THEN
  RAISE NOTICE
    'Aviso: No se pudo setear default_text_search_config a nivel de DB. '
    'Usar ''espanol_sin_acento'' explícitamente en cada query de búsqueda de texto.';
END;
$$;


-- ============================================================
-- FUNCIÓN: normalizar_texto
-- ============================================================
-- Convierte cualquier texto a minúsculas sin acentos.
-- Se usa en índices de búsqueda para que las consultas
-- encuentren resultados sin importar cómo el usuario escribió.
-- Ejemplos:
--   normalizar_texto('José Ñoño')     → 'jose nono'
--   normalizar_texto('CAFÉ Ocotal')   → 'cafe ocotal'
--   normalizar_texto('Mandado Rápido') → 'mandado rapido'
-- Uso en búsquedas: WHERE normalizar_texto(nombre) LIKE '%' || normalizar_texto(busqueda) || '%'
-- ============================================================
CREATE OR REPLACE FUNCTION normalizar_texto(texto_entrada TEXT)
RETURNS TEXT
LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE AS $$
  SELECT LOWER(UNACCENT(texto_entrada))
$$;

-- Prueba rápida de verificación (descomentar y ejecutar para confirmar):
-- SELECT normalizar_texto('Ñoño trabaja en Ocotal, Nicaragüa con café y pasión');
-- Resultado esperado: 'nono trabaja en ocotal, nicaragua con cafe y pasion'


-- ============================================================
-- ACTUALIZAR COLLATION EN COLUMNAS DE TEXTO
-- ============================================================
-- Aplica el collation latinoamericano a todas las columnas de
-- texto que contienen nombres, descripciones y direcciones en español.
-- Esto garantiza que el ordenamiento sea correcto:
--   • Lista de negocios: "Ñico's Comida" aparece entre N y O
--   • Lista de clientes: "Álvarez" y "Alvarez" ordenan juntos
--   • Direcciones: "Barrio San José" ordena correctamente
-- ============================================================

-- Tabla: sucursales
-- Nombres de ciudades, departamentos y países con caracteres latinos
ALTER TABLE sucursales
  ALTER COLUMN nombre      TYPE TEXT COLLATE latinoamericano,
  ALTER COLUMN direccion   TYPE TEXT COLLATE latinoamericano,
  ALTER COLUMN ciudad      TYPE TEXT COLLATE latinoamericano,
  ALTER COLUMN departamento TYPE TEXT COLLATE latinoamericano,
  ALTER COLUMN pais        TYPE TEXT COLLATE latinoamericano;

-- Tabla: perfiles
-- Nombres de personas: María, José, Ñoño, Óscar, etc.
ALTER TABLE perfiles
  ALTER COLUMN nombre_completo TYPE TEXT COLLATE latinoamericano;

-- Tabla: catalogo_servicios
-- Nombres y descripciones de los servicios de Thimpson
ALTER TABLE catalogo_servicios
  ALTER COLUMN nombre_mostrar TYPE TEXT COLLATE latinoamericano,
  ALTER COLUMN descripcion    TYPE TEXT COLLATE latinoamericano,
  ALTER COLUMN nombre_icono   TYPE TEXT COLLATE latinoamericano;

-- Tabla: negocios
-- Nombres de negocios afiliados, descripciones en español
ALTER TABLE negocios
  ALTER COLUMN nombre      TYPE TEXT COLLATE latinoamericano,
  ALTER COLUMN descripcion TYPE TEXT COLLATE latinoamericano,
  ALTER COLUMN mision      TYPE TEXT COLLATE latinoamericano,
  ALTER COLUMN vision      TYPE TEXT COLLATE latinoamericano,
  ALTER COLUMN categoria   TYPE TEXT COLLATE latinoamericano,
  ALTER COLUMN direccion   TYPE TEXT COLLATE latinoamericano;

-- Tabla: productos_negocio
-- Catálogo de productos con nombres y descripciones en español
ALTER TABLE productos_negocio
  ALTER COLUMN nombre      TYPE TEXT COLLATE latinoamericano,
  ALTER COLUMN descripcion TYPE TEXT COLLATE latinoamericano,
  ALTER COLUMN categoria   TYPE TEXT COLLATE latinoamericano;

-- Tabla: solicitudes_servicio
-- Direcciones y notas escritas por los clientes en español
ALTER TABLE solicitudes_servicio
  ALTER COLUMN direccion_origen  TYPE TEXT COLLATE latinoamericano,
  ALTER COLUMN direccion_destino TYPE TEXT COLLATE latinoamericano,
  ALTER COLUMN contenido_paquete TYPE TEXT COLLATE latinoamericano,
  ALTER COLUMN notas             TYPE TEXT COLLATE latinoamericano;

-- Tabla: asignaciones
-- Notas del motorizado escritas en campo libre
ALTER TABLE asignaciones
  ALTER COLUMN notas_motorizado TYPE TEXT COLLATE latinoamericano;

-- Tabla: contenido_cms
-- Títulos y secciones del CMS en español
ALTER TABLE contenido_cms
  ALTER COLUMN titulo          TYPE TEXT COLLATE latinoamericano,
  ALTER COLUMN seccion_destino TYPE TEXT COLLATE latinoamericano;

-- Tabla: testimonios
-- Nombres y textos de testimonios en español
ALTER TABLE testimonios
  ALTER COLUMN nombre_cliente TYPE TEXT COLLATE latinoamericano,
  ALTER COLUMN contenido      TYPE TEXT COLLATE latinoamericano;

-- Tabla: notificaciones
-- Mensajes de notificaciones en español para todos los usuarios
ALTER TABLE notificaciones
  ALTER COLUMN titulo TYPE TEXT COLLATE latinoamericano,
  ALTER COLUMN cuerpo TYPE TEXT COLLATE latinoamericano;

-- Tabla: galeria
-- Pies de foto y categorías de la galería en español
ALTER TABLE galeria
  ALTER COLUMN pie_foto  TYPE TEXT COLLATE latinoamericano,
  ALTER COLUMN categoria TYPE TEXT COLLATE latinoamericano;


-- ============================================================
-- BÚSQUEDA DE TEXTO COMPLETO (Full-Text Search) EN ESPAÑOL
-- ============================================================
-- Permite búsquedas inteligentes en el marketplace:
--   • "cafe" encuentra "Café Nicaragüense"
--   • "farmacia" encuentra "Farmacia San José"
--   • "pollo" encuentra "Pollo asado", "Pechuga a la plancha"
-- Sistema de pesos para relevancia:
--   Peso A = nombre (más relevante)
--   Peso B = descripción
--   Peso C = categoría
--   Peso D = dirección (menos relevante)
-- ============================================================

-- ── BÚSQUEDA EN NEGOCIOS ──────────────────────────────────────

-- Columna que almacena el vector de búsqueda del negocio
-- (texto procesado listo para búsquedas rápidas)
ALTER TABLE negocios ADD COLUMN IF NOT EXISTS vector_busqueda TSVECTOR;

-- Función que genera el vector de búsqueda de un negocio
-- Se llama automáticamente cuando se crea o edita un negocio
CREATE OR REPLACE FUNCTION actualizar_vector_busqueda_negocio()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.vector_busqueda :=
    -- Nombre tiene el mayor peso (A): aparece primero en resultados
    SETWEIGHT(TO_TSVECTOR('espanol_sin_acento', COALESCE(UNACCENT(NEW.nombre),      '')), 'A') ||
    -- Descripción tiene peso B
    SETWEIGHT(TO_TSVECTOR('espanol_sin_acento', COALESCE(UNACCENT(NEW.descripcion), '')), 'B') ||
    -- Categoría tiene peso C
    SETWEIGHT(TO_TSVECTOR('espanol_sin_acento', COALESCE(UNACCENT(NEW.categoria),   '')), 'C') ||
    -- Dirección tiene peso D (menos relevante para búsqueda)
    SETWEIGHT(TO_TSVECTOR('espanol_sin_acento', COALESCE(UNACCENT(NEW.direccion),   '')), 'D');
  RETURN NEW;
END;
$$;

-- Trigger: actualiza el vector automáticamente al crear o editar un negocio
CREATE TRIGGER trg_vector_busqueda_negocio
  BEFORE INSERT OR UPDATE OF nombre, descripcion, categoria, direccion
  ON negocios
  FOR EACH ROW EXECUTE FUNCTION actualizar_vector_busqueda_negocio();

-- Índice GIN: hace las búsquedas de texto completo muy rápidas
-- Sin este índice, buscar en miles de negocios sería muy lento
CREATE INDEX IF NOT EXISTS idx_negocios_busqueda ON negocios USING GIN(vector_busqueda);

-- Actualizar el vector en negocios que ya existen en la base de datos
UPDATE negocios SET vector_busqueda =
  SETWEIGHT(TO_TSVECTOR('espanol_sin_acento', COALESCE(UNACCENT(nombre),      '')), 'A') ||
  SETWEIGHT(TO_TSVECTOR('espanol_sin_acento', COALESCE(UNACCENT(descripcion), '')), 'B') ||
  SETWEIGHT(TO_TSVECTOR('espanol_sin_acento', COALESCE(UNACCENT(categoria),   '')), 'C') ||
  SETWEIGHT(TO_TSVECTOR('espanol_sin_acento', COALESCE(UNACCENT(direccion),   '')), 'D');


-- ── BÚSQUEDA EN PRODUCTOS DEL MARKETPLACE ────────────────────

-- Columna de vector de búsqueda para productos
ALTER TABLE productos_negocio ADD COLUMN IF NOT EXISTS vector_busqueda TSVECTOR;

-- Función que genera el vector de búsqueda de un producto
CREATE OR REPLACE FUNCTION actualizar_vector_busqueda_producto()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.vector_busqueda :=
    SETWEIGHT(TO_TSVECTOR('espanol_sin_acento', COALESCE(UNACCENT(NEW.nombre),      '')), 'A') ||
    SETWEIGHT(TO_TSVECTOR('espanol_sin_acento', COALESCE(UNACCENT(NEW.descripcion), '')), 'B') ||
    SETWEIGHT(TO_TSVECTOR('espanol_sin_acento', COALESCE(UNACCENT(NEW.categoria),   '')), 'C');
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_vector_busqueda_producto
  BEFORE INSERT OR UPDATE OF nombre, descripcion, categoria
  ON productos_negocio
  FOR EACH ROW EXECUTE FUNCTION actualizar_vector_busqueda_producto();

CREATE INDEX IF NOT EXISTS idx_productos_busqueda ON productos_negocio USING GIN(vector_busqueda);

UPDATE productos_negocio SET vector_busqueda =
  SETWEIGHT(TO_TSVECTOR('espanol_sin_acento', COALESCE(UNACCENT(nombre),      '')), 'A') ||
  SETWEIGHT(TO_TSVECTOR('espanol_sin_acento', COALESCE(UNACCENT(descripcion), '')), 'B') ||
  SETWEIGHT(TO_TSVECTOR('espanol_sin_acento', COALESCE(UNACCENT(categoria),   '')), 'C');


-- ============================================================
-- FUNCIONES DE BÚSQUEDA EN ESPAÑOL
-- ============================================================

-- Función: buscar_negocios
-- ─────────────────────────────────────────────────────────────
-- Busca negocios en el marketplace sin importar acentos ni mayúsculas.
-- Soporta búsquedas parciales (el query se trata como prefijo).
-- Retorna resultados ordenados por relevancia (el más relevante primero).
-- Uso: SELECT * FROM buscar_negocios('farmacia');
--      SELECT * FROM buscar_negocios('cafe', 'comida');
CREATE OR REPLACE FUNCTION buscar_negocios(
  texto_busqueda   TEXT,            -- Lo que escribió el usuario (con o sin acentos)
  filtro_categoria TEXT DEFAULT NULL -- Filtrar además por categoría (opcional)
)
RETURNS TABLE (
  id          UUID,
  nombre      TEXT,
  descripcion TEXT,
  categoria   TEXT,
  tipo_plan   tipo_plan,
  url_logo    TEXT,
  relevancia  FLOAT
)
LANGUAGE SQL STABLE PARALLEL SAFE AS $$
  WITH consulta_procesada AS (
    -- Convierte el texto del usuario a una query de búsqueda:
    -- "café nicaragüense" → 'cafe:* & nicaraguense:*' (busca ambas palabras como prefijos)
    SELECT TO_TSQUERY(
      'espanol_sin_acento',
      ARRAY_TO_STRING(
        ARRAY(
          SELECT sin_acento || ':*'
          FROM   REGEXP_SPLIT_TO_TABLE(UNACCENT(TRIM(texto_busqueda)), '\s+') AS sin_acento
          WHERE  LENGTH(sin_acento) > 1  -- Ignorar palabras de un solo carácter
        ),
        ' & '  -- AND entre palabras: todas deben aparecer en el resultado
      )
    ) AS tsq
  )
  SELECT
    n.id,
    n.nombre,
    n.descripcion,
    n.categoria,
    n.tipo_plan,
    n.url_logo,
    -- TS_RANK_CD: calcula la relevancia considerando densidad y cobertura
    TS_RANK_CD(n.vector_busqueda, c.tsq, 32) AS relevancia
  FROM   negocios n, consulta_procesada c
  WHERE  n.activo = TRUE                   -- Solo negocios activos en el marketplace
    AND  n.vector_busqueda @@ c.tsq        -- El negocio contiene las palabras buscadas
    AND  (filtro_categoria IS NULL         -- Sin filtro: mostrar todas las categorías
          OR normalizar_texto(n.categoria) -- Con filtro: comparar sin acentos ni mayúsculas
             ILIKE '%' || normalizar_texto(filtro_categoria) || '%')
  ORDER BY relevancia DESC;  -- El resultado más relevante aparece primero
$$;


-- Función: buscar_productos
-- ─────────────────────────────────────────────────────────────
-- Busca productos en el catálogo del marketplace.
-- Puede filtrar por negocio específico o buscar en todos.
-- Uso: SELECT * FROM buscar_productos('pollo asado');
--      SELECT * FROM buscar_productos('gaseosa', 'uuid-del-negocio');
CREATE OR REPLACE FUNCTION buscar_productos(
  texto_busqueda    TEXT,               -- Lo que busca el cliente
  filtro_negocio_id UUID DEFAULT NULL   -- Buscar solo en este negocio (opcional)
)
RETURNS TABLE (
  id          UUID,
  negocio_id  UUID,
  nombre      TEXT,
  descripcion TEXT,
  precio      DECIMAL,
  url_imagen  TEXT,
  relevancia  FLOAT
)
LANGUAGE SQL STABLE PARALLEL SAFE AS $$
  WITH consulta_procesada AS (
    SELECT TO_TSQUERY(
      'espanol_sin_acento',
      ARRAY_TO_STRING(
        ARRAY(
          SELECT sin_acento || ':*'
          FROM   REGEXP_SPLIT_TO_TABLE(UNACCENT(TRIM(texto_busqueda)), '\s+') AS sin_acento
          WHERE  LENGTH(sin_acento) > 1
        ),
        ' & '
      )
    ) AS tsq
  )
  SELECT
    p.id,
    p.negocio_id,
    p.nombre,
    p.descripcion,
    p.precio,
    p.url_imagen,
    TS_RANK_CD(p.vector_busqueda, c.tsq, 32) AS relevancia
  FROM   productos_negocio p, consulta_procesada c
  WHERE  p.disponible = TRUE                     -- Solo productos disponibles
    AND  p.vector_busqueda @@ c.tsq              -- El producto contiene lo buscado
    AND  (filtro_negocio_id IS NULL              -- Sin filtro: buscar en todos los negocios
          OR p.negocio_id = filtro_negocio_id)   -- Con filtro: solo en ese negocio
  ORDER BY relevancia DESC;
$$;


-- ============================================================
-- ÍNDICES ADICIONALES PARA BÚSQUEDAS NORMALIZADAS
-- ============================================================
-- Estos índices permiten búsquedas eficientes usando la función
-- normalizar_texto() directamente en los campos más consultados.
-- Ejemplo de uso: WHERE normalizar_texto(nombre) LIKE '%jose%'
-- Sin índice sería lento; con índice la búsqueda es instantánea.
-- ============================================================

-- Buscar clientes por nombre sin importar acentos ni mayúsculas
-- Ejemplo: buscar 'maria' y encontrar 'María', 'MARIA', 'maría'
CREATE INDEX IF NOT EXISTS idx_perfiles_nombre_normalizado
  ON perfiles (normalizar_texto(nombre_completo));

-- Buscar negocios por nombre en el marketplace
CREATE INDEX IF NOT EXISTS idx_negocios_nombre_normalizado
  ON negocios (normalizar_texto(nombre));

-- Buscar negocios por categoría
CREATE INDEX IF NOT EXISTS idx_negocios_categoria_normalizada
  ON negocios (normalizar_texto(categoria));

-- Buscar productos por nombre
CREATE INDEX IF NOT EXISTS idx_productos_nombre_normalizado
  ON productos_negocio (normalizar_texto(nombre));

-- Buscar solicitudes por dirección de origen
-- Útil para el panel admin al buscar solicitudes en una zona
CREATE INDEX IF NOT EXISTS idx_solicitudes_origen_normalizado
  ON solicitudes_servicio (normalizar_texto(direccion_origen));


-- ============================================================
-- VERIFICACIÓN — Descomentar para confirmar la instalación
-- ============================================================

-- 1. Verificar que las extensiones están activas
-- SELECT extname, extversion FROM pg_extension WHERE extname IN ('unaccent', 'btree_gist');

-- 2. Verificar que los collations se crearon
-- SELECT collname, collprovider, colliculocale
-- FROM   pg_collation
-- WHERE  collname IN ('latinoamericano', 'latinoamericano_ci');

-- 3. Probar la normalización de texto
-- SELECT normalizar_texto('José Ñoño trabaja en Ocotal, Nicaragüa');
-- Esperado: 'jose nono trabaja en ocotal, nicaragua'

-- 4. Probar búsqueda de negocios sin acentos
-- INSERT INTO negocios (nombre, categoria, activo, sucursal_id)
-- VALUES ('Café Nicaragüense', 'cafetería', TRUE, (SELECT id FROM sucursales LIMIT 1));
-- SELECT * FROM buscar_negocios('cafe');          -- Debe encontrar 'Café Nicaragüense'
-- SELECT * FROM buscar_negocios('CAFETERIA');      -- Debe encontrar 'cafetería'
-- SELECT * FROM buscar_negocios('nicaraguense');   -- Debe encontrar 'Nicaragüense'

-- 5. Probar ordenamiento correcto en español
-- SELECT nombre FROM negocios ORDER BY nombre COLLATE latinoamericano;
-- 'ñ' debe aparecer entre 'n' y 'o' en los resultados


-- ============================================================
-- FIN MIGRACIÓN 002 v2.0.0
-- Servicio Express Thimpson — ThimpsonExpressDB
-- Soporte completo de caracteres latinoamericanos
-- ============================================================
-- ✅ Siguiente paso: 003_datos_prueba.sql
-- ============================================================
