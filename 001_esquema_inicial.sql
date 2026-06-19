-- ============================================================
-- SERVICIO EXPRESS THIMPSON
-- Esquema inicial de base de datos — nombres en español
-- ============================================================
-- Repositorio  : ThimpsonExpressDB
-- Plataforma   : Supabase (PostgreSQL 15+ con PostGIS)
-- Versión      : 2.0.0
-- Autor        : DenDev93
-- Ocotal, Nueva Segovia, Nicaragua
-- ============================================================
-- DESCRIPCIÓN GENERAL:
-- Crea la estructura completa de la base de datos para el
-- ecosistema Servicio Express Thimpson, que incluye:
--   • Gestión de sucursales (multi-tenant / multi-sede)
--   • Usuarios: clientes, motorizados, admins y propietarios de negocios
--   • Catálogo de 7 servicios propios (mandado, delivery, encomienda, etc.)
--   • Marketplace de negocios afiliados con planes gratis/premium
--   • Solicitudes de servicio con ciclo de vida completo
--   • Asignación automática de motorizados (radio 3.5 km, máx. 3 órdenes)
--   • Control de ganancias por motorizado (diario/semanal/mensual/anual)
--   • CMS: contenidos web programables por rango de fechas
--   • Suscripciones para clientes y negocios afiliados
--   • Notificaciones push / in-app
--   • Sesiones de chatbot IA (web + WhatsApp Business)
--   • Galería de imágenes del negocio
--
-- INSTRUCCIONES DE INSTALACIÓN:
--   1. Abre app.supabase.com → tu proyecto
--   2. Database → Extensions → activa: uuid-ossp, postgis, pgcrypto
--   3. SQL Editor → New Query → pega este archivo → clic en RUN
--   4. Luego ejecuta: 002_caracteres_latinoamerica.sql
-- ============================================================


-- ============================================================
-- EXTENSIONES DE POSTGRESQL
-- Funcionalidades adicionales que necesita la base de datos
-- ============================================================

-- uuid-ossp: genera identificadores únicos universales (UUID v4)
-- Todas las tablas usan UUID como clave primaria para evitar
-- IDs predecibles o secuenciales que son un riesgo de seguridad
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- postgis: habilita el almacenamiento y consulta de datos GPS
-- Se usa para la ubicación en tiempo real de los motorizados
-- y para calcular distancias geográficas precisas en metros
CREATE EXTENSION IF NOT EXISTS "postgis";

-- pgcrypto: funciones de encriptación y generación de tokens
-- Se usa para operaciones criptográficas en datos sensibles
CREATE EXTENSION IF NOT EXISTS "pgcrypto";


-- ============================================================
-- TIPOS PERSONALIZADOS (ENUMERACIONES)
-- ============================================================
-- Una enumeración define un conjunto cerrado de valores
-- permitidos para un campo. Usar enumeraciones en lugar de
-- texto libre evita errores de escritura y mantiene la
-- consistencia de los datos en toda la base de datos.
-- Ejemplo: un campo 'estado' solo puede ser 'pendiente',
-- 'asignado', etc. Si alguien intenta guardar 'en espera',
-- la base de datos lo rechazará automáticamente.
--
-- Para agregar un valor nuevo: ALTER TYPE nombre_tipo ADD VALUE 'nuevo_valor';
-- Para cambiar o eliminar valores se requiere una migración cuidadosa.
-- ============================================================

-- Roles de usuario: determina qué puede hacer cada usuario en el sistema
CREATE TYPE rol_usuario AS ENUM (
  'super_administrador', -- Propietario / CEO. Acceso total. Define precios manuales.
  'administrador',       -- Gestor de sucursal. Supervisa pedidos y motorizados.
  'cliente',             -- Usuario final que solicita servicios por cualquier canal.
  'motorizado',          -- Repartidor. Recibe y ejecuta las solicitudes asignadas.
  'propietario_negocio'  -- Dueño de negocio afiliado al marketplace de Thimpson.
);

-- Tipos de servicio que ofrece Servicio Express Thimpson en Ocotal
CREATE TYPE tipo_servicio AS ENUM (
  'mandado',       -- Diligencias dentro de Ocotal.             Precio fijo: C$40/parada.
  'delivery',      -- Entrega de productos a domicilio.         Precio fijo: C$40/parada.
  'encomienda',    -- Envío de paquetes dentro de la ciudad.    Precio fijo: C$40/parada.
  'viaje_expreso', -- Viaje al norte, centro o pacífico de NI.  Precio manual (define CEO).
  'transporte',    -- Transporte de personas o carga general.   Precio manual (define CEO).
  'acarreo',       -- Traslado de materiales, muebles o equipo. Precio manual (define CEO).
  'mudanza'        -- Mudanza completa de hogar o negocio.      Precio manual (define CEO).
);

-- Ciclo de vida de una solicitud de servicio
CREATE TYPE estado_servicio AS ENUM (
  'pendiente',  -- Registrada. El agente IA busca motorizado disponible.
  'asignado',   -- Motorizado asignado y notificado. Aún no ha iniciado.
  'en_camino',  -- Motorizado inició el servicio y está en movimiento.
  'entregado',  -- Servicio completado exitosamente. Se registran ganancias.
  'cancelado',  -- Cancelado por el cliente antes de completarse.
  'declinado'   -- Rechazado por el motorizado. Se buscará otro disponible.
);

-- Planes de suscripción para clientes y negocios afiliados
CREATE TYPE tipo_plan AS ENUM (
  'gratis',   -- Sin costo. Funciones básicas: ver servicios y precios.
  'premium'   -- De pago mensual. Marketplace completo y pedidos ilimitados.
);

-- Estados por los que puede pasar una suscripción
CREATE TYPE estado_suscripcion AS ENUM (
  'activa',    -- Vigente. El suscriptor tiene acceso completo a su plan.
  'inactiva',  -- Creada pero aún no activada, o pausada temporalmente.
  'vencida',   -- La fecha de expiración llegó y no fue renovada.
  'cancelada'  -- El suscriptor solicitó cancelar antes de que venciera.
);

-- Tipos de contenido que puede gestionar el CMS de la web pública
CREATE TYPE tipo_contenido AS ENUM (
  'banner',               -- Imagen o slider principal en la portada de la web.
  'promocion',            -- Oferta o descuento de tiempo limitado.
  'anuncio',              -- Comunicado o novedad importante del negocio.
  'galeria',              -- Álbum de fotos (equipo, vehículos, instalaciones).
  'testimonio_destacado', -- Testimonio de cliente seleccionado para portada.
  'servicio_destacado'    -- Servicio Thimpson resaltado en sección especial.
);

-- Estado del contenido CMS según su programación de fechas
-- El trigger 'trg_estado_contenido_cms' lo calcula automáticamente
CREATE TYPE estado_contenido AS ENUM (
  'borrador',   -- En edición. No visible en ningún canal todavía.
  'programado', -- Listo, pero la fecha_inicio aún no ha llegado.
  'activo',     -- Visible ahora mismo (entre fecha_inicio y fecha_fin).
  'vencido'     -- La fecha_fin ya pasó; se archiva automáticamente.
);

-- Canal por el que llegó una solicitud o conversación de chat
CREATE TYPE canal_chat AS ENUM (
  'web',         -- Chatbot o formulario de la aplicación web pública.
  'whatsapp',    -- Bot de WhatsApp Business API Cloud.
  'app_movil',   -- App móvil del cliente (iOS o Android).
  'panel_admin'  -- Solicitud registrada manualmente por un administrador.
);

-- Tipos de vehículo que puede registrar un motorizado
CREATE TYPE tipo_vehiculo AS ENUM (
  'moto',    -- Motocicleta. La más común para mandados y delivery en Ocotal.
  'carro',   -- Automóvil. Para encomiendas y servicios que requieren espacio.
  'pickup',  -- Camioneta pickup. Para acarreo y carga mediana.
  'camion'   -- Camión. Para mudanzas completas o cargas muy voluminosas.
);


-- ============================================================
-- TABLA: sucursales
-- ============================================================
-- Representa cada punto de operación del negocio.
-- El diseño es multi-tenant: casi todas las demás tablas tienen
-- un campo 'sucursal_id' que permite a múltiples sedes compartir
-- la misma base de datos sin mezclar sus datos entre sí.
-- Actualmente: 1 sucursal en Ocotal. En el futuro: Estelí, Jalapa, etc.
-- ============================================================
CREATE TABLE sucursales (
  id             UUID DEFAULT uuid_generate_v4() PRIMARY KEY, -- Identificador único de la sucursal
  nombre         TEXT NOT NULL,                               -- Nombre comercial (ej: "Servicio Express Thimpson — Ocotal")
  direccion      TEXT,                                        -- Dirección física completa de la sede
  ciudad         TEXT NOT NULL DEFAULT 'Ocotal',              -- Ciudad de operación
  departamento   TEXT NOT NULL DEFAULT 'Nueva Segovia',       -- Departamento de Nicaragua
  pais           TEXT NOT NULL DEFAULT 'Nicaragua',           -- País
  telefono_claro TEXT,                                        -- Número de contacto Claro (+50584159112)
  telefono_tigo  TEXT,                                        -- Número de contacto Tigo  (+50585932295)
  correo         TEXT,                                        -- Correo electrónico de la sucursal
  activo         BOOLEAN DEFAULT TRUE,                        -- FALSE = sucursal deshabilitada temporalmente
  creado_en      TIMESTAMPTZ DEFAULT NOW(),                   -- Fecha y hora de creación del registro
  actualizado_en TIMESTAMPTZ DEFAULT NOW()                    -- Última vez que se modificó este registro
);

-- Sucursal principal: Servicio Express Thimpson en Ocotal, Nicaragua
INSERT INTO sucursales (nombre, ciudad, departamento, pais, telefono_claro, telefono_tigo)
VALUES (
  'Servicio Express Thimpson — Ocotal',
  'Ocotal',
  'Nueva Segovia',
  'Nicaragua',
  '+50584159112',
  '+50585932295'
);


-- ============================================================
-- TABLA: perfiles
-- ============================================================
-- Almacena la información de todos los usuarios del sistema.
-- Extiende auth.users de Supabase Auth, que maneja el correo,
-- contraseña y tokens de sesión. Por cada registro en auth.users
-- existe exactamente un registro aquí con el mismo UUID.
-- El trigger 'trg_nuevo_usuario' crea el perfil automáticamente
-- cuando alguien se registra por cualquier canal de acceso.
-- ============================================================
CREATE TABLE perfiles (
  id              UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
                  -- ON DELETE CASCADE: si se elimina el usuario de auth, se elimina su perfil también
  rol             rol_usuario DEFAULT 'cliente',  -- Qué puede hacer este usuario en el sistema
  nombre_completo TEXT NOT NULL,                  -- Nombre y apellidos (soporta ñ y acentos)
  telefono        TEXT,                           -- Número de teléfono (Claro, Tigo u otro operador)
  url_avatar      TEXT,                           -- URL de la foto de perfil en Supabase Storage
  sucursal_id     UUID REFERENCES sucursales(id), -- Sucursal a la que pertenece este usuario
  activo          BOOLEAN DEFAULT TRUE,           -- FALSE = cuenta suspendida o deshabilitada
  creado_en       TIMESTAMPTZ DEFAULT NOW(),
  actualizado_en  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_perfiles_rol      ON perfiles(rol);         -- Consultar todos los clientes, todos los motorizados, etc.
CREATE INDEX idx_perfiles_sucursal ON perfiles(sucursal_id); -- Usuarios de una sucursal específica
CREATE INDEX idx_perfiles_telefono ON perfiles(telefono);    -- Buscar usuario por número de teléfono


-- ============================================================
-- TABLA: motorizados
-- ============================================================
-- Almacena información específica de los repartidores de Thimpson.
-- Cada motorizado tiene su perfil en 'perfiles' con rol = 'motorizado'.
-- El campo 'ubicacion_actual' se actualiza en tiempo real desde la
-- app de motorizados usando Supabase Realtime (WebSockets).
--
-- Reglas de negocio implementadas en esta tabla:
--   • ordenes_activas: CHECK garantiza máximo 3 órdenes simultáneas
--   • disponible = FALSE cuando el motorizado está fuera de servicio
--   • El trigger actualiza ordenes_activas automáticamente
-- ============================================================
CREATE TABLE motorizados (
  id               UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  perfil_id        UUID REFERENCES perfiles(id) ON DELETE CASCADE UNIQUE NOT NULL,
                   -- UNIQUE: cada perfil puede ser motorizado una sola vez
                   -- ON DELETE CASCADE: al eliminar el perfil se elimina el registro de motorizado
  tipo_vehiculo    tipo_vehiculo DEFAULT 'moto',       -- Con qué vehículo trabaja actualmente
  placa            TEXT,                               -- Número de placa del vehículo para identificación
  ubicacion_actual GEOGRAPHY(Point, 4326),             -- Coordenadas GPS en tiempo real (PostGIS)
                                                       -- GEOGRAPHY usa el sistema WGS84 (el de Google Maps)
                                                       -- Almacena punto: latitud y longitud del motorizado
  disponible       BOOLEAN DEFAULT TRUE,               -- TRUE = puede recibir nuevas solicitudes ahora mismo
  ordenes_activas  INT DEFAULT 0                       -- Cuántas solicitudes tiene actualmente en ejecución
                   CHECK (ordenes_activas >= 0         -- No puede ser negativo (protección contra bugs)
                     AND  ordenes_activas <= 3),       -- Máximo 3 órdenes simultáneas (regla de negocio)
  sucursal_id      UUID REFERENCES sucursales(id),     -- Sucursal Thimpson a la que está asignado
  activo           BOOLEAN DEFAULT TRUE,               -- FALSE = motorizado dado de baja o suspendido
  creado_en        TIMESTAMPTZ DEFAULT NOW(),
  actualizado_en   TIMESTAMPTZ DEFAULT NOW()
);

-- Índice espacial GiST: esencial para buscar motorizados cercanos eficientemente
-- Sin este índice, la búsqueda recorrería TODA la tabla aunque haya miles de motorizados
CREATE INDEX idx_motorizados_ubicacion  ON motorizados USING GIST(ubicacion_actual);
-- Índice compuesto para el filtro de disponibilidad (la consulta más frecuente del sistema)
CREATE INDEX idx_motorizados_disponible ON motorizados(disponible, ordenes_activas, activo);


-- ============================================================
-- TABLA: catalogo_servicios
-- ============================================================
-- Define los 7 tipos de servicio que ofrece Servicio Express Thimpson.
-- Los primeros 3 tienen precio fijo: C$40 por parada.
-- Los últimos 4 tienen precio_manual = TRUE: el CEO cotiza el precio
-- según la distancia, la carga y las características del trabajo.
-- Esta tabla alimenta el catálogo visible en la web y las apps.
-- ============================================================
CREATE TABLE catalogo_servicios (
  id               UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  tipo_servicio    tipo_servicio UNIQUE NOT NULL,  -- El tipo de servicio (no puede repetirse)
  nombre_mostrar   TEXT NOT NULL,                  -- Cómo se llama en la UI para el cliente
  descripcion      TEXT,                           -- Descripción del servicio para el cliente
  precio_base      DECIMAL(10,2) DEFAULT 40.00,    -- Precio inicial en córdobas (C$)
  precio_por_parada DECIMAL(10,2) DEFAULT 40.00,  -- Costo adicional por cada parada extra
  nombre_icono     TEXT,                           -- Nombre del ícono en la librería de íconos de la UI
  precio_manual    BOOLEAN DEFAULT FALSE,          -- TRUE = el CEO define el precio, no es automático
  activo           BOOLEAN DEFAULT TRUE,           -- FALSE = servicio temporalmente no disponible
  orden            INT DEFAULT 0,                  -- Posición en la lista de servicios (1 = primero)
  creado_en        TIMESTAMPTZ DEFAULT NOW(),
  actualizado_en   TIMESTAMPTZ DEFAULT NOW()
);

-- Los 7 servicios de Servicio Express Thimpson (Ocotal, Nicaragua)
INSERT INTO catalogo_servicios
  (tipo_servicio, nombre_mostrar, descripcion, precio_base, precio_por_parada, precio_manual, orden)
VALUES
  ('mandado',       'Mandado',
   'Realizamos tus mandados dentro de Ocotal. Precio: C$40 por parada.',
   40.00, 40.00, FALSE, 1),
  ('delivery',      'Delivery',
   'Entregamos tus productos a domicilio con seguridad. Precio: C$40 por parada.',
   40.00, 40.00, FALSE, 2),
  ('encomienda',    'Encomienda',
   'Enviamos tus paquetes y encomiendas con cuidado. Precio: C$40 por parada.',
   40.00, 40.00, FALSE, 3),
  ('viaje_expreso', 'Viaje Expreso',
   'Viajes expresos al norte, centro y pacífico de Nicaragua. Precio según destino.',
   0.00, 0.00, TRUE, 4),
  ('transporte',    'Transporte',
   'Transporte personalizado de personas o carga. Precio a convenir.',
   0.00, 0.00, TRUE, 5),
  ('acarreo',       'Acarreo',
   'Movemos materiales, muebles o equipo a donde los necesites. Precio a convenir.',
   0.00, 0.00, TRUE, 6),
  ('mudanza',       'Mudanza',
   'Mudanza completa de tu hogar o negocio con seguridad. Precio a convenir.',
   0.00, 0.00, TRUE, 7);


-- ============================================================
-- TABLA: negocios
-- ============================================================
-- Registra los negocios afiliados al marketplace de Thimpson.
-- Puede ser una persona natural, microempresa o empresa formal.
-- Cada negocio publica su catálogo de productos para que los
-- clientes pidan delivery a través de Servicio Express Thimpson.
-- El plan del negocio (gratis o premium) determina las funciones
-- a las que tiene acceso en el marketplace.
-- ============================================================
CREATE TABLE negocios (
  id                    UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  perfil_propietario_id UUID REFERENCES perfiles(id), -- Propietario con rol 'propietario_negocio'
  nombre                TEXT NOT NULL,                -- Nombre comercial del negocio afiliado
  descripcion           TEXT,                         -- Descripción de lo que ofrece el negocio
  mision                TEXT,                         -- Misión del negocio (para su perfil en marketplace)
  vision                TEXT,                         -- Visión del negocio
  categoria             TEXT,             -- Rubro: 'comida', 'farmacia', 'supermercado', 'ropa', etc.
  url_logo              TEXT,             -- URL del logo del negocio en Supabase Storage
  url_portada           TEXT,             -- URL de la imagen de portada en Supabase Storage
  telefono              TEXT,             -- Teléfono de contacto del negocio
  direccion             TEXT,             -- Dirección física del establecimiento
  ubicacion             GEOGRAPHY(Point, 4326), -- Coordenadas GPS (para mostrar en mapa del marketplace)
  tipo_plan             tipo_plan DEFAULT 'gratis',     -- Plan actual: gratis o premium
  suscripcion_activa    BOOLEAN DEFAULT TRUE,           -- FALSE = plan expirado, sin acceso a funciones
  suscripcion_vence_en  TIMESTAMPTZ,                   -- Cuándo expira el plan. NULL = gratis indefinido
  activo                BOOLEAN DEFAULT TRUE,           -- FALSE = negocio suspendido o dado de baja
  verificado            BOOLEAN DEFAULT FALSE,          -- TRUE = Thimpson verificó la autenticidad del negocio
  sucursal_id           UUID REFERENCES sucursales(id), -- Sucursal que gestiona este negocio afiliado
  creado_en             TIMESTAMPTZ DEFAULT NOW(),
  actualizado_en        TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_negocios_ubicacion  ON negocios USING GIST(ubicacion);          -- Negocios cercanos al cliente
CREATE INDEX idx_negocios_categoria  ON negocios(categoria);                     -- Filtrar por rubro
CREATE INDEX idx_negocios_plan       ON negocios(tipo_plan, suscripcion_activa); -- Ver quiénes tienen plan activo
CREATE INDEX idx_negocios_activo     ON negocios(activo);                        -- Solo negocios visibles


-- ============================================================
-- TABLA: productos_negocio
-- ============================================================
-- Catálogo de productos o servicios de un negocio afiliado.
-- Ejemplo de una pupusería: 'Pupusas de queso C$15',
--   'Combo familiar C$80', 'Fresco natural C$25', etc.
-- Los clientes pueden pedir delivery de estos productos
-- directamente desde el marketplace de Thimpson.
-- ============================================================
CREATE TABLE productos_negocio (
  id             UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  negocio_id     UUID REFERENCES negocios(id) ON DELETE CASCADE, -- Negocio dueño del producto
                 -- ON DELETE CASCADE: al eliminar el negocio, se eliminan sus productos
  nombre         TEXT NOT NULL,             -- Nombre del producto (ej: 'Pollo asado con arroz y ensalada')
  descripcion    TEXT,                      -- Detalles del producto (ingredientes, tamaño, variantes)
  precio         DECIMAL(10,2) NOT NULL,   -- Precio en córdobas nicaragüenses (C$)
  url_imagen     TEXT,                     -- URL de la foto del producto en Supabase Storage
  categoria      TEXT,                     -- Subcategoría: 'entrada', 'plato fuerte', 'bebida', 'postre'
  inventario     INT,                      -- Unidades disponibles. NULL = sin control de inventario
  disponible     BOOLEAN DEFAULT TRUE,     -- FALSE = producto agotado temporalmente
  orden          INT DEFAULT 0,            -- Posición en el menú del negocio (0 = primero)
  creado_en      TIMESTAMPTZ DEFAULT NOW(),
  actualizado_en TIMESTAMPTZ DEFAULT NOW()
);

-- Consultar productos disponibles de un negocio (la consulta más frecuente del marketplace)
CREATE INDEX idx_productos_negocio ON productos_negocio(negocio_id, disponible);


-- ============================================================
-- TABLA: solicitudes_servicio
-- ============================================================
-- Es el corazón del sistema. Registra cada solicitud de servicio
-- que llega por cualquier canal (web, WhatsApp, app móvil o admin).
-- El agente IA administrador lee esta tabla continuamente para
-- detectar solicitudes en estado 'pendiente' y asignar motorizados.
--
-- El campo 'paradas' es JSON para soportar múltiples paradas:
-- [{"direccion": "Mercado central", "latitud": 13.47, "longitud": -86.35, "notas": "comprar pan"}]
--
-- El campo 'detalles_servicio' guarda info extra para servicios manuales:
-- {"zona_destino": "norte", "es_ida_y_vuelta": true, "horas_estimadas": 3}
-- ============================================================
CREATE TABLE solicitudes_servicio (
  id                UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  perfil_cliente_id UUID REFERENCES perfiles(id),          -- Quién solicitó. NULL si llegó por WhatsApp anónimo.
  tipo_servicio     tipo_servicio NOT NULL,                 -- Qué tipo de servicio se solicita
  estado            estado_servicio DEFAULT 'pendiente',    -- En qué etapa del proceso está la solicitud
  -- ── Punto de origen ──────────────────────────────────────
  direccion_origen  TEXT NOT NULL,                          -- Dirección escrita del punto de recogida
  ubicacion_origen  GEOGRAPHY(Point, 4326),                 -- Coordenadas GPS del origen (para buscar motorizados)
  -- ── Paradas intermedias ───────────────────────────────────
  -- Cada parada: {"direccion": "...", "latitud": 0.0, "longitud": 0.0, "notas": "..."}
  paradas           JSONB DEFAULT '[]'::jsonb,              -- Lista de paradas intermedias entre origen y destino
  cantidad_paradas  INT DEFAULT 1,                          -- Número total de paradas (calcula el precio)
  -- ── Destino final ────────────────────────────────────────
  direccion_destino  TEXT,                                  -- Dirección escrita del punto de entrega final
  ubicacion_destino  GEOGRAPHY(Point, 4326),                -- Coordenadas GPS del destino final
  -- ── Precio ───────────────────────────────────────────────
  precio_total      DECIMAL(10,2) DEFAULT 0,                -- Total en C$. Cero si requiere cotización manual del CEO.
  -- ── Información del servicio ─────────────────────────────
  contenido_paquete TEXT,     -- Para encomiendas/delivery: qué contiene el paquete
  notas             TEXT,     -- Instrucciones especiales del cliente al motorizado
  detalles_servicio JSONB DEFAULT '{}'::jsonb,   -- Info extra para cotización manual (zona, horas, etc.)
  -- ── Trazabilidad ─────────────────────────────────────────
  canal_origen      canal_chat DEFAULT 'web',               -- Por qué canal llegó la solicitud
  negocio_id        UUID REFERENCES negocios(id),           -- Si es pedido a negocio afiliado, cuál negocio
  sucursal_id       UUID REFERENCES sucursales(id),         -- Sucursal Thimpson que atiende esta solicitud
  creado_en         TIMESTAMPTZ DEFAULT NOW(),
  actualizado_en    TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_solicitudes_estado    ON solicitudes_servicio(estado);                       -- Filtrar pendientes
CREATE INDEX idx_solicitudes_cliente   ON solicitudes_servicio(perfil_cliente_id);            -- Historial del cliente
CREATE INDEX idx_solicitudes_tipo      ON solicitudes_servicio(tipo_servicio);                -- Por tipo de servicio
CREATE INDEX idx_solicitudes_ubicacion ON solicitudes_servicio USING GIST(ubicacion_origen); -- Búsqueda geoespacial
CREATE INDEX idx_solicitudes_fecha     ON solicitudes_servicio(creado_en DESC);               -- Más recientes primero
CREATE INDEX idx_solicitudes_negocio   ON solicitudes_servicio(negocio_id);                   -- Pedidos por negocio


-- ============================================================
-- TABLA: asignaciones
-- ============================================================
-- Vincula una solicitud de servicio con el motorizado que la atiende.
-- Una solicitud solo puede tener UNA asignación activa (UNIQUE).
-- El trigger 'trg_ordenes_activas_motorizado' actualiza automáticamente
-- el campo 'ordenes_activas' en la tabla 'motorizados' cuando el
-- estado aquí cambia (ej: de 'asignado' a 'entregado' → resta 1).
-- El trigger 'trg_sincronizar_estado_solicitud' mantiene sincronizado
-- el estado de la solicitud con el estado de la asignación.
-- ============================================================
CREATE TABLE asignaciones (
  id               UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  solicitud_id     UUID REFERENCES solicitudes_servicio(id) ON DELETE CASCADE UNIQUE,
                   -- UNIQUE: una solicitud no puede tener dos asignaciones simultáneas
  motorizado_id    UUID REFERENCES motorizados(id),      -- Qué motorizado atiende esta solicitud
  estado           estado_servicio DEFAULT 'asignado',   -- Estado actual de la ejecución
  asignado_en      TIMESTAMPTZ DEFAULT NOW(),            -- Cuándo se asignó el motorizado
  iniciado_en      TIMESTAMPTZ,                          -- Cuándo el motorizado marcó inicio del servicio
  completado_en    TIMESTAMPTZ,                          -- Cuándo se marcó como entregado/completado
  cancelado_en     TIMESTAMPTZ,                          -- Cuándo fue cancelado o declinado (si aplica)
  notas_motorizado TEXT,                                 -- Observaciones del motorizado sobre el servicio
  creado_en        TIMESTAMPTZ DEFAULT NOW(),
  actualizado_en   TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_asignaciones_motorizado ON asignaciones(motorizado_id, estado); -- Asignaciones activas por motorizado
CREATE INDEX idx_asignaciones_solicitud  ON asignaciones(solicitud_id);           -- Asignación de una solicitud


-- ============================================================
-- TABLA: ganancias
-- ============================================================
-- Registra cada ingreso del motorizado al completar un servicio.
-- La vista 'resumen_ganancias_motorizados' agrega estos registros
-- por período (hoy / semana / mes / trimestre / semestre / año).
-- La app de motorizados usa esa vista para el dashboard de ingresos.
-- El panel admin la usa para los reportes financieros por motorizado.
-- ============================================================
CREATE TABLE ganancias (
  id             UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  motorizado_id  UUID REFERENCES motorizados(id),   -- Qué motorizado generó esta ganancia
  asignacion_id  UUID REFERENCES asignaciones(id),  -- De qué asignación completada proviene
  monto          DECIMAL(10,2) NOT NULL,             -- Cuánto ganó el motorizado (en C$)
  fecha_periodo  DATE DEFAULT CURRENT_DATE,          -- Fecha del servicio (para reportes por período)
  creado_en      TIMESTAMPTZ DEFAULT NOW()
);

-- Consultas de reportes ordenadas de la ganancia más reciente a la más antigua
CREATE INDEX idx_ganancias_motorizado ON ganancias(motorizado_id, fecha_periodo DESC);


-- ============================================================
-- TABLA: suscripciones
-- ============================================================
-- Gestiona los planes de suscripción de los clientes finales.
-- Sin suscripción activa, el cliente tiene acceso limitado
-- (puede ver información básica pero no hacer pedidos ilimitados).
-- Con suscripción premium, acceso completo al marketplace.
-- ============================================================
CREATE TABLE suscripciones (
  id             UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  perfil_id      UUID REFERENCES perfiles(id) ON DELETE CASCADE UNIQUE,
                 -- UNIQUE: un cliente solo puede tener un plan activo a la vez
  estado         estado_suscripcion DEFAULT 'activa', -- Estado actual
  iniciado_en    TIMESTAMPTZ DEFAULT NOW(),           -- Cuándo empezó la suscripción
  vence_en       TIMESTAMPTZ,                         -- Cuándo expira. NULL = gratis indefinido
  creado_en      TIMESTAMPTZ DEFAULT NOW(),
  actualizado_en TIMESTAMPTZ DEFAULT NOW()
);


-- ============================================================
-- TABLA: suscripciones_negocio
-- ============================================================
-- Gestiona los planes de los negocios afiliados al marketplace.
-- Plan gratis: visibilidad básica, catálogo limitado.
-- Plan premium: posición destacada, catálogo ilimitado, estadísticas.
-- El precio mensual en C$ lo define el CEO de Thimpson.
-- ============================================================
CREATE TABLE suscripciones_negocio (
  id              UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  negocio_id      UUID REFERENCES negocios(id) ON DELETE CASCADE UNIQUE,
                  -- UNIQUE: un negocio solo puede tener un plan activo a la vez
  tipo_plan       tipo_plan DEFAULT 'gratis',            -- Plan actual del negocio
  estado          estado_suscripcion DEFAULT 'activa',   -- Estado actual del plan
  precio_mensual  DECIMAL(10,2) DEFAULT 0,              -- Cuánto paga el negocio por mes (0 = gratis)
  iniciado_en     TIMESTAMPTZ DEFAULT NOW(),             -- Cuándo empezó el plan actual
  vence_en        TIMESTAMPTZ,                           -- Cuándo expira. NULL = gratis indefinido
  creado_en       TIMESTAMPTZ DEFAULT NOW(),
  actualizado_en  TIMESTAMPTZ DEFAULT NOW()
);


-- ============================================================
-- TABLA: contenido_cms
-- ============================================================
-- Sistema de gestión de contenido web programable por fechas.
-- El Super Administrador crea piezas de contenido asignándoles
-- una fecha de inicio y una fecha de fin.
-- Un trigger calcula automáticamente el 'estado':
--   → 'borrador'   si no tiene fechas aún
--   → 'programado' si fecha_inicio > ahora
--   → 'activo'     si estamos entre fecha_inicio y fecha_fin
--   → 'vencido'    si fecha_fin < ahora
-- La vista 'contenido_cms_activo' devuelve solo lo visible ahora.
-- El campo 'contenido' es JSON flexible según el tipo_contenido:
--   banner:    {"url_imagen": "...", "texto_cta": "Solicita ahora", "enlace": "/servicios"}
--   promocion: {"titulo": "20% off", "descripcion": "...", "url_imagen": "..."}
--   galeria:   {"imagenes": ["url1", "url2", "url3"]}
-- ============================================================
CREATE TABLE contenido_cms (
  id              UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  titulo          TEXT NOT NULL,             -- Nombre interno para identificar el contenido en el admin
  tipo_contenido  tipo_contenido NOT NULL,   -- Qué tipo de contenido es
  contenido       JSONB NOT NULL DEFAULT '{}'::jsonb, -- Datos flexibles según el tipo (JSON)
  seccion_destino TEXT,   -- Sección de la web donde aparece: 'hero', 'promociones', 'galeria', etc.
  fecha_inicio    TIMESTAMPTZ NOT NULL,      -- Cuándo empieza a mostrarse este contenido
  fecha_fin       TIMESTAMPTZ NOT NULL,      -- Cuándo deja de mostrarse
  estado          estado_contenido DEFAULT 'borrador', -- Calculado automáticamente por trigger
  prioridad       INT DEFAULT 0,             -- Si hay varios activos en la misma sección, el mayor va primero
  activo          BOOLEAN DEFAULT TRUE,      -- FALSE = deshabilitado manualmente sin importar las fechas
  creado_por      UUID REFERENCES perfiles(id), -- Administrador que creó este contenido
  sucursal_id     UUID REFERENCES sucursales(id), -- Para qué sucursal aplica el contenido
  creado_en       TIMESTAMPTZ DEFAULT NOW(),
  actualizado_en  TIMESTAMPTZ DEFAULT NOW(),
  -- Restricción: la fecha de fin SIEMPRE debe ser posterior a la de inicio
  CONSTRAINT fechas_validas CHECK (fecha_fin > fecha_inicio)
);

CREATE INDEX idx_cms_estado   ON contenido_cms(estado, activo);         -- Consultar contenido publicable ahora
CREATE INDEX idx_cms_fechas   ON contenido_cms(fecha_inicio, fecha_fin); -- Filtrar por rango de fechas
CREATE INDEX idx_cms_seccion  ON contenido_cms(seccion_destino);         -- Contenido de una sección específica


-- ============================================================
-- TABLA: testimonios
-- ============================================================
-- Testimonios de clientes satisfechos que se muestran en la
-- web pública para generar confianza en nuevos usuarios.
-- El administrador controla cuáles son visibles y en qué orden.
-- ============================================================
CREATE TABLE testimonios (
  id             UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  nombre_cliente TEXT NOT NULL,        -- Nombre del cliente que da el testimonio
  contenido      TEXT NOT NULL,        -- Texto completo del testimonio
  calificacion   INT CHECK (calificacion >= 1 AND calificacion <= 5), -- Estrellas (1 a 5)
  url_avatar     TEXT,                 -- Foto del cliente (opcional, con permiso del cliente)
  visible        BOOLEAN DEFAULT TRUE, -- FALSE = oculto sin eliminar (para moderación)
  orden          INT DEFAULT 0,        -- Posición en la sección de testimonios de la web
  creado_en      TIMESTAMPTZ DEFAULT NOW()
);


-- ============================================================
-- TABLA: notificaciones
-- ============================================================
-- Notificaciones push e in-app para todos los usuarios del sistema.
-- El campo 'tipo' agrupa las notificaciones para darles estilos:
--   'actualizacion_pedido' → cliente sabe que su motorizado ya viene
--   'nueva_asignacion'     → el motorizado recibe una solicitud nueva
--   'promocion'            → oferta especial del marketplace o Thimpson
--   'general'              → comunicado del negocio
-- El campo 'datos' permite que la app navegue a la pantalla correcta
-- cuando el usuario toca la notificación (deep linking).
-- ============================================================
CREATE TABLE notificaciones (
  id        UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  perfil_id UUID REFERENCES perfiles(id) ON DELETE CASCADE, -- A quién va dirigida
  titulo    TEXT NOT NULL,              -- Título corto visible en la notificación
  cuerpo    TEXT NOT NULL,              -- Mensaje completo de la notificación
  tipo      TEXT DEFAULT 'general',     -- Categoría para filtros y estilos en la app
  -- Payload para navegación: {"solicitud_id": "...", "pantalla": "seguimiento_pedido"}
  datos     JSONB DEFAULT '{}'::jsonb,
  leido     BOOLEAN DEFAULT FALSE,      -- TRUE = el usuario ya leyó o abrió la notificación
  creado_en TIMESTAMPTZ DEFAULT NOW()
);

-- Notificaciones no leídas de un usuario, ordenadas de más nueva a más antigua
CREATE INDEX idx_notificaciones_perfil ON notificaciones(perfil_id, leido, creado_en DESC);


-- ============================================================
-- TABLA: sesiones_chat_ia
-- ============================================================
-- Almacena el historial completo de conversaciones con el chatbot IA.
-- Opera en dos canales: chatbot de la web pública y bot de WhatsApp.
-- El campo 'mensajes' guarda toda la conversación en JSON:
--   [{"rol": "usuario",    "contenido": "quiero pedir un mandado", "timestamp": "..."},
--    {"rol": "asistente",  "contenido": "Claro! ¿Cuál es la dirección de origen?", "timestamp": "..."}]
-- Si la conversación resultó en un pedido formal, 'solicitud_generada_id'
-- apunta a la solicitud_servicio que se creó a partir del chat.
-- ============================================================
CREATE TABLE sesiones_chat_ia (
  id                    UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  perfil_id             UUID REFERENCES perfiles(id), -- NULL si el usuario es anónimo (no registrado)
  canal                 canal_chat DEFAULT 'web',      -- Por qué canal se dio la conversación
  telefono_whatsapp     TEXT,                          -- Número de WhatsApp (solo para canal 'whatsapp')
  mensajes              JSONB DEFAULT '[]'::jsonb,    -- Historial completo de la conversación con el bot
  estado                TEXT DEFAULT 'activa',         -- 'activa' | 'completada' | 'abandonada'
  solicitud_generada_id UUID REFERENCES solicitudes_servicio(id), -- Si el chat generó un pedido formal
  creado_en             TIMESTAMPTZ DEFAULT NOW(),
  actualizado_en        TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_chat_perfil    ON sesiones_chat_ia(perfil_id);              -- Sesiones por usuario registrado
CREATE INDEX idx_chat_whatsapp  ON sesiones_chat_ia(telefono_whatsapp);      -- Retomar conversación de WhatsApp
CREATE INDEX idx_chat_canal     ON sesiones_chat_ia(canal, estado);          -- Sesiones activas por canal


-- ============================================================
-- TABLA: galeria
-- ============================================================
-- Imágenes de la galería de la web pública de Thimpson.
-- Muestra el equipo de trabajo, los vehículos, los servicios
-- en acción, las instalaciones y momentos del negocio.
-- El admin controla qué fotos son visibles y en qué orden aparecen.
-- ============================================================
CREATE TABLE galeria (
  id          UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  url_imagen  TEXT NOT NULL,         -- URL de la imagen almacenada en Supabase Storage
  pie_foto    TEXT,                  -- Texto descriptivo de la imagen (para SEO y accesibilidad)
  categoria   TEXT,                  -- Categoría: 'equipo', 'vehiculos', 'servicios', 'instalaciones'
  orden       INT DEFAULT 0,         -- Posición en la galería (menor número = aparece primero)
  visible     BOOLEAN DEFAULT TRUE,  -- FALSE = foto oculta sin borrar del servidor
  sucursal_id UUID REFERENCES sucursales(id), -- Sucursal a la que pertenecen estas fotos
  creado_en   TIMESTAMPTZ DEFAULT NOW()
);


-- ============================================================
-- VISTAS
-- ============================================================
-- Las vistas son consultas SQL guardadas con un nombre.
-- Se pueden usar como si fueran tablas en un SELECT.
-- Simplifican el código de la API: en lugar de escribir
-- queries complejas con múltiples filtros, se consulta la vista.
-- ============================================================

-- Vista: contenido_cms_activo
-- Devuelve el contenido del CMS que se debe mostrar ahora mismo
-- en la web pública. Filtra por estado 'activo', activo = TRUE
-- y que la fecha actual esté dentro del rango del contenido.
CREATE VIEW contenido_cms_activo AS
SELECT *
FROM   contenido_cms
WHERE  activo        = TRUE
  AND  estado        = 'activo'
  AND  fecha_inicio  <= NOW()
  AND  fecha_fin     >= NOW()
ORDER  BY prioridad DESC; -- El contenido con mayor prioridad aparece primero


-- Vista: motorizados_disponibles
-- Lista todos los motorizados que PUEDEN recibir nuevas solicitudes ahora:
--   • disponible = TRUE  → no están fuera de servicio
--   • activo = TRUE      → no han sido dados de baja
--   • ordenes_activas < 3 → no han llegado al máximo de 3 órdenes
--   • ubicacion_actual no es NULL → están enviando su GPS en tiempo real
CREATE VIEW motorizados_disponibles AS
SELECT
  m.*,
  p.nombre_completo,
  p.telefono
FROM   motorizados m
JOIN   perfiles    p ON m.perfil_id = p.id
WHERE  m.disponible      = TRUE
  AND  m.activo          = TRUE
  AND  m.ordenes_activas < 3
  AND  m.ubicacion_actual IS NOT NULL;


-- Vista: resumen_ganancias_motorizados
-- Agrega las ganancias de cada motorizado por período.
-- Usada en: app de motorizados (dashboard de ingresos) y
-- panel de admin (reportes financieros por motorizado).
CREATE VIEW resumen_ganancias_motorizados AS
SELECT
  m.id               AS motorizado_id,
  p.nombre_completo  AS nombre_motorizado,
  -- Ganancias del día de hoy
  COALESCE(SUM(CASE
    WHEN g.fecha_periodo = CURRENT_DATE THEN g.monto END), 0)                                 AS ganancias_hoy,
  -- Ganancias de la semana actual (desde el lunes)
  COALESCE(SUM(CASE
    WHEN g.fecha_periodo >= DATE_TRUNC('week',    CURRENT_DATE) THEN g.monto END), 0)         AS ganancias_semana,
  -- Ganancias del mes actual
  COALESCE(SUM(CASE
    WHEN g.fecha_periodo >= DATE_TRUNC('month',   CURRENT_DATE) THEN g.monto END), 0)         AS ganancias_mes,
  -- Ganancias del trimestre actual
  COALESCE(SUM(CASE
    WHEN g.fecha_periodo >= DATE_TRUNC('quarter', CURRENT_DATE) THEN g.monto END), 0)         AS ganancias_trimestre,
  -- Ganancias de los últimos 6 meses
  COALESCE(SUM(CASE
    WHEN g.fecha_periodo >= CURRENT_DATE - INTERVAL '6 months'  THEN g.monto END), 0)         AS ganancias_semestre,
  -- Ganancias del año actual
  COALESCE(SUM(CASE
    WHEN DATE_TRUNC('year', g.fecha_periodo::TIMESTAMPTZ)
       = DATE_TRUNC('year', NOW()) THEN g.monto END), 0)                                       AS ganancias_anio,
  -- Total histórico acumulado desde que empezó a trabajar
  COALESCE(SUM(g.monto), 0)                                                                    AS ganancias_total
FROM   motorizados m
JOIN   perfiles    p ON m.perfil_id = p.id
LEFT JOIN ganancias g ON m.id = g.motorizado_id
GROUP  BY m.id, p.nombre_completo;


-- ============================================================
-- FUNCIONES
-- ============================================================
-- Lógica de negocio encapsulada dentro de la base de datos.
-- Ventaja: se ejecuta en el servidor de DB directamente,
-- es más rápida que hacer múltiples queries desde la API
-- y garantiza consistencia independientemente del cliente.
-- ============================================================

-- Función: buscar_motorizados_disponibles
-- ─────────────────────────────────────────────────────────────
-- Encuentra motorizados disponibles dentro del radio configurado
-- (por defecto 3.5 km desde el origen de la solicitud).
-- Usa PostGIS para calcular distancias reales en metros.
-- Retorna resultados del motorizado más cercano al más lejano.
-- Esta función la llama el agente IA administrador para
-- asignar automáticamente el mejor motorizado.
--
-- Ejemplo: SELECT * FROM buscar_motorizados_disponibles(13.4742, -86.3538, 3.5);
CREATE OR REPLACE FUNCTION buscar_motorizados_disponibles(
  latitud  FLOAT,           -- Latitud del origen de la solicitud
  longitud FLOAT,           -- Longitud del origen de la solicitud
  radio_km FLOAT DEFAULT 3.5 -- Radio de búsqueda en km (regla de negocio: máximo 3.5 km)
)
RETURNS TABLE (
  motorizado_id   UUID,
  nombre_completo TEXT,
  telefono        TEXT,
  distancia_km    FLOAT,        -- Distancia exacta desde el origen hasta el motorizado (en km)
  ordenes_activas INT,          -- Cuántas órdenes tiene actualmente (no puede exceder 3)
  tipo_vehiculo   tipo_vehiculo -- Para saber si puede con la carga o tipo de servicio
)
LANGUAGE SQL STABLE PARALLEL SAFE AS $$
  SELECT
    m.id,
    p.nombre_completo,
    p.telefono,
    -- Distancia en kilómetros, redondeada a 2 decimales
    ROUND(
      (ST_Distance(
        m.ubicacion_actual,
        ST_MakePoint(longitud, latitud)::GEOGRAPHY
      ) / 1000)::NUMERIC, 2
    )::FLOAT AS distancia_km,
    m.ordenes_activas,
    m.tipo_vehiculo
  FROM   motorizados m
  JOIN   perfiles    p ON m.perfil_id = p.id
  WHERE  m.disponible      = TRUE           -- Solo motorizados que están disponibles
    AND  m.activo          = TRUE           -- Solo motorizados activos (no dados de baja)
    AND  m.ordenes_activas < 3              -- Con menos de 3 órdenes activas (regla de negocio)
    AND  m.ubicacion_actual IS NOT NULL     -- Que estén enviando su GPS en tiempo real
    AND  ST_DWithin(                        -- PostGIS: filtra por radio de distancia
           m.ubicacion_actual,
           ST_MakePoint(longitud, latitud)::GEOGRAPHY,
           radio_km * 1000                  -- ST_DWithin trabaja en metros (1 km = 1000 metros)
         )
  ORDER BY distancia_km ASC;               -- El más cercano primero
$$;


-- Función: calcular_precio_servicio
-- ─────────────────────────────────────────────────────────────
-- Calcula el precio total de un servicio según tipo y paradas.
-- Para servicios con precio_manual = TRUE retorna 0 (el CEO cotiza).
-- Fórmula: precio_base + precio_por_parada × (cantidad_paradas - 1)
-- La primera parada está incluida en precio_base.
-- Ejemplo:
--   mandado 1 parada: C$40 + C$40×0 = C$40
--   mandado 3 paradas: C$40 + C$40×2 = C$120
-- Uso: SELECT calcular_precio_servicio('mandado', 3); → 120.00
CREATE OR REPLACE FUNCTION calcular_precio_servicio(
  p_tipo_servicio    tipo_servicio, -- Tipo de servicio a cotizar
  p_cantidad_paradas INT DEFAULT 1  -- Total de paradas de la solicitud
)
RETURNS DECIMAL(10,2)
LANGUAGE SQL STABLE PARALLEL SAFE AS $$
  SELECT
    CASE
      WHEN precio_manual THEN 0.00  -- El CEO cotiza este servicio manualmente
      ELSE precio_base + (precio_por_parada * GREATEST(p_cantidad_paradas - 1, 0))
      -- GREATEST(..., 0) evita valores negativos si se pasa 0 paradas por error
    END
  FROM catalogo_servicios
  WHERE tipo_servicio = p_tipo_servicio;
$$;


-- ============================================================
-- TRIGGERS
-- ============================================================
-- Los triggers son funciones que se ejecutan automáticamente
-- cuando ocurre un INSERT, UPDATE o DELETE en una tabla.
-- Permiten mantener la consistencia de los datos sin que
-- la API o las apps tengan que hacer nada extra.
-- ============================================================

-- Función compartida: actualizar_timestamp
-- Se reutiliza en múltiples triggers para actualizar
-- el campo 'actualizado_en' en todas las tablas.
CREATE OR REPLACE FUNCTION actualizar_timestamp()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  -- Registra el momento exacto en que se modificó el registro
  NEW.actualizado_en = NOW();
  RETURN NEW;
END;
$$;

-- Triggers que mantienen 'actualizado_en' actualizado en cada tabla
CREATE TRIGGER trg_timestamp_sucursales   BEFORE UPDATE ON sucursales         FOR EACH ROW EXECUTE FUNCTION actualizar_timestamp();
CREATE TRIGGER trg_timestamp_perfiles     BEFORE UPDATE ON perfiles            FOR EACH ROW EXECUTE FUNCTION actualizar_timestamp();
CREATE TRIGGER trg_timestamp_motorizados  BEFORE UPDATE ON motorizados         FOR EACH ROW EXECUTE FUNCTION actualizar_timestamp();
CREATE TRIGGER trg_timestamp_negocios     BEFORE UPDATE ON negocios            FOR EACH ROW EXECUTE FUNCTION actualizar_timestamp();
CREATE TRIGGER trg_timestamp_productos    BEFORE UPDATE ON productos_negocio   FOR EACH ROW EXECUTE FUNCTION actualizar_timestamp();
CREATE TRIGGER trg_timestamp_solicitudes  BEFORE UPDATE ON solicitudes_servicio FOR EACH ROW EXECUTE FUNCTION actualizar_timestamp();
CREATE TRIGGER trg_timestamp_asignaciones BEFORE UPDATE ON asignaciones        FOR EACH ROW EXECUTE FUNCTION actualizar_timestamp();
CREATE TRIGGER trg_timestamp_cms          BEFORE UPDATE ON contenido_cms       FOR EACH ROW EXECUTE FUNCTION actualizar_timestamp();
CREATE TRIGGER trg_timestamp_chat         BEFORE UPDATE ON sesiones_chat_ia    FOR EACH ROW EXECUTE FUNCTION actualizar_timestamp();


-- Trigger: actualizar_ordenes_activas_motorizado
-- ─────────────────────────────────────────────────────────────
-- Se ejecuta cada vez que cambia el estado de una asignación.
-- Mantiene el contador 'ordenes_activas' del motorizado sincronizado.
-- Lógica:
--   • Nueva asignación creada (INSERT con estado 'asignado') → suma 1
--   • Asignación cambia a 'asignado' (de otro estado) → suma 1
--   • Asignación termina (entregado/cancelado/declinado) → resta 1
--   • GREATEST(..., 0) protege contra que el contador baje de cero
CREATE OR REPLACE FUNCTION actualizar_ordenes_activas_motorizado()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  -- Servicio terminado, cancelado o declinado: liberar una plaza del motorizado
  IF NEW.estado IN ('entregado', 'cancelado', 'declinado') THEN
    UPDATE motorizados
    SET    ordenes_activas = GREATEST(ordenes_activas - 1, 0),
           actualizado_en  = NOW()
    WHERE  id = NEW.motorizado_id;

  -- Nueva asignación activa: ocupar una plaza del motorizado
  ELSIF NEW.estado = 'asignado' AND (TG_OP = 'INSERT' OR OLD.estado != 'asignado') THEN
    UPDATE motorizados
    SET    ordenes_activas = ordenes_activas + 1,
           actualizado_en  = NOW()
    WHERE  id = NEW.motorizado_id;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_ordenes_activas_motorizado
  AFTER INSERT OR UPDATE OF estado ON asignaciones
  FOR EACH ROW EXECUTE FUNCTION actualizar_ordenes_activas_motorizado();


-- Trigger: sincronizar_estado_solicitud
-- ─────────────────────────────────────────────────────────────
-- Cuando el estado de una asignación cambia, este trigger
-- actualiza automáticamente el estado de la solicitud_servicio
-- para mantener ambas tablas siempre en sincronía.
-- Así la app del cliente ve el estado actualizado en tiempo real
-- sin que la API necesite hacer dos UPDATE separados.
CREATE OR REPLACE FUNCTION sincronizar_estado_solicitud()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  UPDATE solicitudes_servicio
  SET    estado         = NEW.estado,  -- El estado de la solicitud sigue al estado de la asignación
         actualizado_en = NOW()
  WHERE  id = NEW.solicitud_id;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_sincronizar_estado_solicitud
  AFTER UPDATE OF estado ON asignaciones
  FOR EACH ROW EXECUTE FUNCTION sincronizar_estado_solicitud();


-- Trigger: actualizar_estado_contenido_cms
-- ─────────────────────────────────────────────────────────────
-- Calcula y actualiza el campo 'estado' del contenido CMS
-- automáticamente basándose en las fechas de inicio y fin.
-- Se ejecuta al crear o modificar las fechas de un contenido.
-- Así el administrador nunca tiene que cambiar el estado manual.
CREATE OR REPLACE FUNCTION actualizar_estado_contenido_cms()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.estado := CASE
    WHEN NEW.fecha_fin   < NOW()  THEN 'vencido'     -- La fecha de fin ya pasó
    WHEN NEW.fecha_inicio > NOW() THEN 'programado'  -- La fecha de inicio aún no llega
    ELSE                               'activo'      -- Estamos en el rango → publicar
  END::estado_contenido;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_estado_contenido_cms
  BEFORE INSERT OR UPDATE OF fecha_inicio, fecha_fin ON contenido_cms
  FOR EACH ROW EXECUTE FUNCTION actualizar_estado_contenido_cms();


-- Trigger: crear_perfil_nuevo_usuario
-- ─────────────────────────────────────────────────────────────
-- Trigger especial instalado en auth.users de Supabase.
-- Se ejecuta automáticamente cada vez que alguien se registra
-- (por web, app, Google, WhatsApp o cualquier canal).
-- Crea el perfil correspondiente en nuestra tabla 'perfiles'
-- usando los datos del metadata que se envía al registrar.
CREATE OR REPLACE FUNCTION crear_perfil_nuevo_usuario()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  id_sucursal_principal UUID;
BEGIN
  -- Obtener el ID de la sucursal principal (Ocotal) para asignarla por defecto
  SELECT id INTO id_sucursal_principal FROM sucursales LIMIT 1;

  INSERT INTO perfiles (id, nombre_completo, telefono, sucursal_id)
  VALUES (
    NEW.id,
    -- El nombre viene del metadata enviado al momento del registro
    COALESCE(NEW.raw_user_meta_data->>'full_name', 'Usuario nuevo'),
    -- El teléfono viene del metadata del registro (puede ser NULL)
    NEW.raw_user_meta_data->>'phone',
    id_sucursal_principal
  );
  RETURN NEW;
END;
$$;

-- Se instala en auth.users (la tabla de Supabase Auth, no la nuestra)
CREATE TRIGGER trg_nuevo_usuario
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION crear_perfil_nuevo_usuario();


-- ============================================================
-- SEGURIDAD EN FILAS (Row Level Security — RLS)
-- ============================================================
-- RLS garantiza que cada usuario solo pueda ver y modificar
-- los datos que le corresponden según su rol, directamente
-- en el motor de base de datos, no en la API.
-- Sin RLS, cualquier usuario autenticado podría leer TODA
-- la base de datos desde el cliente de Supabase.
-- Con RLS activado, la BD misma rechaza los accesos no autorizados.
-- ⚠️  IMPORTANTE: SIEMPRE activar RLS antes de ir a producción.
-- ============================================================

ALTER TABLE perfiles              ENABLE ROW LEVEL SECURITY;
ALTER TABLE motorizados           ENABLE ROW LEVEL SECURITY;
ALTER TABLE negocios              ENABLE ROW LEVEL SECURITY;
ALTER TABLE productos_negocio     ENABLE ROW LEVEL SECURITY;
ALTER TABLE solicitudes_servicio  ENABLE ROW LEVEL SECURITY;
ALTER TABLE asignaciones          ENABLE ROW LEVEL SECURITY;
ALTER TABLE ganancias             ENABLE ROW LEVEL SECURITY;
ALTER TABLE suscripciones         ENABLE ROW LEVEL SECURITY;
ALTER TABLE suscripciones_negocio ENABLE ROW LEVEL SECURITY;
ALTER TABLE contenido_cms         ENABLE ROW LEVEL SECURITY;
ALTER TABLE notificaciones        ENABLE ROW LEVEL SECURITY;
ALTER TABLE sesiones_chat_ia      ENABLE ROW LEVEL SECURITY;

-- Función auxiliar: obtener el rol del usuario autenticado actualmente
-- auth.uid() → devuelve el UUID del usuario autenticado (de Supabase Auth)
CREATE OR REPLACE FUNCTION obtener_mi_rol()
RETURNS rol_usuario LANGUAGE SQL STABLE SECURITY DEFINER AS $$
  SELECT rol FROM perfiles WHERE id = auth.uid();
$$;

-- Función auxiliar: verificar si el usuario actual es administrador
CREATE OR REPLACE FUNCTION es_administrador()
RETURNS BOOLEAN LANGUAGE SQL STABLE AS $$
  SELECT obtener_mi_rol() IN ('administrador', 'super_administrador');
$$;

-- Políticas de perfiles: cada usuario ve y edita solo el suyo; admins ven todos
CREATE POLICY "perfiles_ver"        ON perfiles FOR SELECT USING (id = auth.uid() OR es_administrador());
CREATE POLICY "perfiles_insertar"   ON perfiles FOR INSERT WITH CHECK (id = auth.uid());
CREATE POLICY "perfiles_actualizar" ON perfiles FOR UPDATE USING (id = auth.uid() OR es_administrador());

-- Políticas de solicitudes: cliente ve las suyas; motorizados y admins ven todas
CREATE POLICY "solicitudes_ver" ON solicitudes_servicio FOR SELECT
  USING (perfil_cliente_id = auth.uid() OR es_administrador() OR obtener_mi_rol() = 'motorizado');
CREATE POLICY "solicitudes_insertar"   ON solicitudes_servicio FOR INSERT
  WITH CHECK (perfil_cliente_id = auth.uid() OR es_administrador());
CREATE POLICY "solicitudes_actualizar" ON solicitudes_servicio FOR UPDATE
  USING (es_administrador());

-- Políticas de asignaciones: motorizado ve las suyas; admins ven todas
CREATE POLICY "asignaciones_ver" ON asignaciones FOR SELECT
  USING (es_administrador() OR motorizado_id IN (SELECT id FROM motorizados WHERE perfil_id = auth.uid()));
CREATE POLICY "asignaciones_actualizar" ON asignaciones FOR UPDATE
  USING (es_administrador() OR motorizado_id IN (SELECT id FROM motorizados WHERE perfil_id = auth.uid()));

-- Políticas de ganancias: cada motorizado ve solo las suyas; admins ven todas
CREATE POLICY "ganancias_ver" ON ganancias FOR SELECT
  USING (motorizado_id IN (SELECT id FROM motorizados WHERE perfil_id = auth.uid()) OR es_administrador());

-- Políticas de notificaciones: cada usuario ve y gestiona solo las suyas
CREATE POLICY "notificaciones_ver"       ON notificaciones FOR SELECT USING (perfil_id = auth.uid());
CREATE POLICY "notificaciones_actualizar" ON notificaciones FOR UPDATE USING (perfil_id = auth.uid());

-- Políticas de CMS: lectura pública para contenido activo; escritura solo para admins
CREATE POLICY "cms_lectura_publica" ON contenido_cms FOR SELECT
  USING (estado = 'activo' AND activo = TRUE OR es_administrador());
CREATE POLICY "cms_escritura_admin" ON contenido_cms FOR ALL USING (es_administrador());

-- Políticas de negocios: activos son públicos; propietario gestiona el suyo; admins todo
CREATE POLICY "negocios_lectura_publica" ON negocios FOR SELECT
  USING (activo = TRUE OR perfil_propietario_id = auth.uid() OR es_administrador());
CREATE POLICY "negocios_actualizar" ON negocios FOR UPDATE
  USING (perfil_propietario_id = auth.uid() OR es_administrador());
CREATE POLICY "negocios_insertar"   ON negocios FOR INSERT
  WITH CHECK (perfil_propietario_id = auth.uid() OR es_administrador());

-- Políticas de productos: disponibles son públicos; propietario gestiona los suyos
CREATE POLICY "productos_lectura_publica" ON productos_negocio FOR SELECT USING (disponible = TRUE OR es_administrador());
CREATE POLICY "productos_gestion_propietario" ON productos_negocio FOR ALL
  USING (negocio_id IN (SELECT id FROM negocios WHERE perfil_propietario_id = auth.uid()) OR es_administrador());

-- Políticas de sesiones de chat: usuario ve las suyas; admins ven todas
CREATE POLICY "chat_ver"        ON sesiones_chat_ia FOR SELECT USING (perfil_id = auth.uid() OR es_administrador());
CREATE POLICY "chat_insertar"   ON sesiones_chat_ia FOR INSERT WITH CHECK (perfil_id = auth.uid() OR perfil_id IS NULL);
CREATE POLICY "chat_actualizar" ON sesiones_chat_ia FOR UPDATE USING (perfil_id = auth.uid() OR es_administrador());


-- ============================================================
-- SUPABASE REALTIME
-- ============================================================
-- Habilita actualizaciones en tiempo real (WebSockets) en las
-- tablas críticas del sistema. Con esto activo, las apps reciben
-- cambios automáticamente sin hacer polling cada N segundos.
--
-- Casos de uso:
--   • solicitudes_servicio → el cliente ve cambios de estado al instante
--   • asignaciones         → el motorizado recibe asignaciones al momento
--   • motorizados          → el admin ve el GPS de motorizados en tiempo real
--   • notificaciones       → push in-app instantáneo sin recargar la app
--   • sesiones_chat_ia     → el chatbot responde sin recargar la página
-- ============================================================
ALTER PUBLICATION supabase_realtime ADD TABLE solicitudes_servicio;
ALTER PUBLICATION supabase_realtime ADD TABLE asignaciones;
ALTER PUBLICATION supabase_realtime ADD TABLE motorizados;
ALTER PUBLICATION supabase_realtime ADD TABLE notificaciones;
ALTER PUBLICATION supabase_realtime ADD TABLE sesiones_chat_ia;


-- ============================================================
-- FIN DEL ESQUEMA INICIAL v2.0.0
-- Servicio Express Thimpson — ThimpsonExpressDB
-- Ocotal, Nueva Segovia, Nicaragua
-- ============================================================
-- ✅ Siguiente paso: ejecutar 002_caracteres_latinoamerica.sql
-- ============================================================
