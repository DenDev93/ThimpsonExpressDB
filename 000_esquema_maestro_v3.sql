-- ============================================================
-- SERVICIO EXPRESS THIMPSON - ESQUEMA MAESTRO v3.0
-- Unificación: 001_esquema_inicial + 002_caracteres_latinoamerica
--            + 003_modulo_empleados + 004_cms_config + fix_005
-- Idempotente | Preserva datos existentes | PostgreSQL 15+
-- ============================================================
-- INSTRUCCIONES:
--   Abrir Supabase Dashboard → SQL Editor → New Query
--   Pegar TODO este archivo → RUN (una sola ejecución)
-- ============================================================

BEGIN;
SELECT '🚀 INICIANDO ESQUEMA MAESTRO v3.0' AS progreso;

-- ============================================================
-- SERVICIO EXPRESS THIMPSON - ESQUEMA MAESTRO v3.0
-- Unificación: 001_esquema_inicial + 002_caracteres_latinoamerica
--            + 003_modulo_empleados + 004_cms_config + fix_005
-- Idempotente | Preserva datos existentes | PostgreSQL 15+
-- ============================================================
-- INSTRUCCIONES:
--   Abrir Supabase Dashboard -> SQL Editor -> New Query
--   Pegar TODO este archivo -> RUN (una sola ejecucion)
-- ============================================================

BEGIN;
SELECT '🚀 INICIANDO ESQUEMA MAESTRO v3.0' AS progreso;

-- ============================================================
-- EXTENSIONES
-- ============================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS unaccent;
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- ============================================================
-- TIPOS PERSONALIZADOS (ENUM) - Idempotentes
-- ============================================================
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'rol_usuario') THEN
    CREATE TYPE rol_usuario AS ENUM (
      'super_administrador','administrador','cliente','motorizado','propietario_negocio'
    );
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'tipo_servicio') THEN
    CREATE TYPE tipo_servicio AS ENUM (
      'mandado','delivery','encomienda','viaje_expreso','transporte','acarreo','mudanza'
    );
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'estado_servicio') THEN
    CREATE TYPE estado_servicio AS ENUM (
      'pendiente','asignado','en_camino','entregado','cancelado','declinado'
    );
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'tipo_plan') THEN
    CREATE TYPE tipo_plan AS ENUM ('gratis','premium');
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'estado_suscripcion') THEN
    CREATE TYPE estado_suscripcion AS ENUM ('activa','inactiva','vencida','cancelada');
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'tipo_contenido') THEN
    CREATE TYPE tipo_contenido AS ENUM (
      'banner','promocion','anuncio','galeria','testimonio_destacado','servicio_destacado'
    );
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'estado_contenido') THEN
    CREATE TYPE estado_contenido AS ENUM ('borrador','programado','activo','vencido');
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'canal_chat') THEN
    CREATE TYPE canal_chat AS ENUM ('web','whatsapp','app_movil','panel_admin');
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'tipo_vehiculo') THEN
    CREATE TYPE tipo_vehiculo AS ENUM ('moto','carro','pickup','camion');
  END IF;
END $$;

-- ============================================================
-- TABLAS (CREATE TABLE IF NOT EXISTS)
-- ============================================================

-- sucursales
CREATE TABLE IF NOT EXISTS sucursales (
  id              UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  nombre          TEXT NOT NULL,
  direccion       TEXT,
  ciudad          TEXT NOT NULL DEFAULT 'Ocotal',
  departamento    TEXT NOT NULL DEFAULT 'Nueva Segovia',
  pais            TEXT NOT NULL DEFAULT 'Nicaragua',
  telefono_claro  TEXT,
  telefono_tigo   TEXT,
  correo          TEXT,
  activo          BOOLEAN DEFAULT TRUE,
  creado_en       TIMESTAMPTZ DEFAULT NOW(),
  actualizado_en  TIMESTAMPTZ DEFAULT NOW()
);

-- perfiles
CREATE TABLE IF NOT EXISTS perfiles (
  id              UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  rol             rol_usuario DEFAULT 'cliente',
  nombre_completo TEXT NOT NULL,
  telefono        TEXT,
  url_avatar      TEXT,
  sucursal_id     UUID REFERENCES sucursales(id),
  activo          BOOLEAN DEFAULT TRUE,
  creado_en       TIMESTAMPTZ DEFAULT NOW(),
  actualizado_en  TIMESTAMPTZ DEFAULT NOW()
);

-- motorizados
CREATE TABLE IF NOT EXISTS motorizados (
  id               UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  perfil_id        UUID REFERENCES perfiles(id) ON DELETE CASCADE UNIQUE NOT NULL,
  tipo_vehiculo    tipo_vehiculo DEFAULT 'moto',
  placa            TEXT,
  ubicacion_actual GEOGRAPHY(Point, 4326),
  disponible       BOOLEAN DEFAULT TRUE,
  ordenes_activas  INT DEFAULT 0 CHECK (ordenes_activas >= 0 AND ordenes_activas <= 3),
  sucursal_id      UUID REFERENCES sucursales(id),
  activo           BOOLEAN DEFAULT TRUE,
  creado_en        TIMESTAMPTZ DEFAULT NOW(),
  actualizado_en   TIMESTAMPTZ DEFAULT NOW()
);

-- catalogo_servicios
CREATE TABLE IF NOT EXISTS catalogo_servicios (
  id               UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  tipo_servicio    tipo_servicio UNIQUE NOT NULL,
  nombre_mostrar   TEXT NOT NULL,
  descripcion      TEXT,
  precio_base      DECIMAL(10,2) DEFAULT 40.00,
  precio_por_parada DECIMAL(10,2) DEFAULT 40.00,
  nombre_icono     TEXT,
  precio_manual    BOOLEAN DEFAULT FALSE,
  activo           BOOLEAN DEFAULT TRUE,
  orden            INT DEFAULT 0,
  creado_en        TIMESTAMPTZ DEFAULT NOW(),
  actualizado_en   TIMESTAMPTZ DEFAULT NOW()
);

-- negocios
CREATE TABLE IF NOT EXISTS negocios (
  id                    UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  perfil_propietario_id UUID REFERENCES perfiles(id),
  nombre                TEXT NOT NULL,
  descripcion           TEXT,
  mision                TEXT,
  vision                TEXT,
  categoria             TEXT,
  url_logo              TEXT,
  url_portada           TEXT,
  telefono              TEXT,
  direccion             TEXT,
  ubicacion             GEOGRAPHY(Point, 4326),
  tipo_plan             tipo_plan DEFAULT 'gratis',
  suscripcion_activa    BOOLEAN DEFAULT TRUE,
  suscripcion_vence_en  TIMESTAMPTZ,
  activo                BOOLEAN DEFAULT TRUE,
  verificado            BOOLEAN DEFAULT FALSE,
  sucursal_id           UUID REFERENCES sucursales(id),
  creado_en             TIMESTAMPTZ DEFAULT NOW(),
  actualizado_en        TIMESTAMPTZ DEFAULT NOW()
);

-- productos_negocio
CREATE TABLE IF NOT EXISTS productos_negocio (
  id             UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  negocio_id     UUID REFERENCES negocios(id) ON DELETE CASCADE,
  nombre         TEXT NOT NULL,
  descripcion    TEXT,
  precio         DECIMAL(10,2) NOT NULL,
  url_imagen     TEXT,
  categoria      TEXT,
  inventario     INT,
  disponible     BOOLEAN DEFAULT TRUE,
  orden          INT DEFAULT 0,
  creado_en      TIMESTAMPTZ DEFAULT NOW(),
  actualizado_en TIMESTAMPTZ DEFAULT NOW()
);

-- solicitudes_servicio
CREATE TABLE IF NOT EXISTS solicitudes_servicio (
  id                UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  perfil_cliente_id UUID REFERENCES perfiles(id),
  tipo_servicio     tipo_servicio NOT NULL,
  estado            estado_servicio DEFAULT 'pendiente',
  direccion_origen  TEXT NOT NULL,
  ubicacion_origen  GEOGRAPHY(Point, 4326),
  paradas           JSONB DEFAULT '[]'::jsonb,
  cantidad_paradas  INT DEFAULT 1,
  direccion_destino TEXT,
  ubicacion_destino GEOGRAPHY(Point, 4326),
  precio_total      DECIMAL(10,2) DEFAULT 0,
  contenido_paquete TEXT,
  notas             TEXT,
  detalles_servicio JSONB DEFAULT '{}'::jsonb,
  canal_origen      canal_chat DEFAULT 'web',
  negocio_id        UUID REFERENCES negocios(id),
  sucursal_id       UUID REFERENCES sucursales(id),
  creado_en         TIMESTAMPTZ DEFAULT NOW(),
  actualizado_en    TIMESTAMPTZ DEFAULT NOW()
);

-- asignaciones
CREATE TABLE IF NOT EXISTS asignaciones (
  id               UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  solicitud_id     UUID REFERENCES solicitudes_servicio(id) ON DELETE CASCADE UNIQUE,
  motorizado_id    UUID REFERENCES motorizados(id),
  estado           estado_servicio DEFAULT 'asignado',
  asignado_en      TIMESTAMPTZ DEFAULT NOW(),
  iniciado_en      TIMESTAMPTZ,
  completado_en    TIMESTAMPTZ,
  cancelado_en     TIMESTAMPTZ,
  notas_motorizado TEXT,
  creado_en        TIMESTAMPTZ DEFAULT NOW(),
  actualizado_en   TIMESTAMPTZ DEFAULT NOW()
);

-- ganancias
CREATE TABLE IF NOT EXISTS ganancias (
  id             UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  motorizado_id  UUID REFERENCES motorizados(id),
  asignacion_id  UUID REFERENCES asignaciones(id),
  monto          DECIMAL(10,2) NOT NULL,
  fecha_periodo  DATE DEFAULT CURRENT_DATE,
  creado_en      TIMESTAMPTZ DEFAULT NOW()
);

-- suscripciones
CREATE TABLE IF NOT EXISTS suscripciones (
  id             UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  perfil_id      UUID REFERENCES perfiles(id) ON DELETE CASCADE UNIQUE,
  estado         estado_suscripcion DEFAULT 'activa',
  iniciado_en    TIMESTAMPTZ DEFAULT NOW(),
  vence_en       TIMESTAMPTZ,
  creado_en      TIMESTAMPTZ DEFAULT NOW(),
  actualizado_en TIMESTAMPTZ DEFAULT NOW()
);

-- suscripciones_negocio
CREATE TABLE IF NOT EXISTS suscripciones_negocio (
  id              UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  negocio_id      UUID REFERENCES negocios(id) ON DELETE CASCADE UNIQUE,
  tipo_plan       tipo_plan DEFAULT 'gratis',
  estado          estado_suscripcion DEFAULT 'activa',
  precio_mensual  DECIMAL(10,2) DEFAULT 0,
  iniciado_en     TIMESTAMPTZ DEFAULT NOW(),
  vence_en        TIMESTAMPTZ,
  creado_en       TIMESTAMPTZ DEFAULT NOW(),
  actualizado_en  TIMESTAMPTZ DEFAULT NOW()
);

-- contenido_cms
CREATE TABLE IF NOT EXISTS contenido_cms (
  id              UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  titulo          TEXT NOT NULL,
  tipo_contenido  tipo_contenido NOT NULL,
  contenido       JSONB NOT NULL DEFAULT '{}'::jsonb,
  seccion_destino TEXT,
  fecha_inicio    TIMESTAMPTZ NOT NULL,
  fecha_fin       TIMESTAMPTZ NOT NULL,
  estado          estado_contenido DEFAULT 'borrador',
  prioridad       INT DEFAULT 0,
  activo          BOOLEAN DEFAULT TRUE,
  creado_por      UUID REFERENCES perfiles(id),
  sucursal_id     UUID REFERENCES sucursales(id),
  creado_en       TIMESTAMPTZ DEFAULT NOW(),
  actualizado_en  TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT fechas_validas CHECK (fecha_fin > fecha_inicio)
);

-- testimonios
CREATE TABLE IF NOT EXISTS testimonios (
  id             UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  nombre_cliente TEXT NOT NULL,
  contenido      TEXT NOT NULL,
  calificacion   INT CHECK (calificacion >= 1 AND calificacion <= 5),
  url_avatar     TEXT,
  visible        BOOLEAN DEFAULT TRUE,
  orden          INT DEFAULT 0,
  creado_en      TIMESTAMPTZ DEFAULT NOW()
);

-- notificaciones
CREATE TABLE IF NOT EXISTS notificaciones (
  id        UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  perfil_id UUID REFERENCES perfiles(id) ON DELETE CASCADE,
  titulo    TEXT NOT NULL,
  cuerpo    TEXT NOT NULL,
  tipo      TEXT DEFAULT 'general',
  datos     JSONB DEFAULT '{}'::jsonb,
  leido     BOOLEAN DEFAULT FALSE,
  creado_en TIMESTAMPTZ DEFAULT NOW()
);

-- sesiones_chat_ia
CREATE TABLE IF NOT EXISTS sesiones_chat_ia (
  id                    UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  perfil_id             UUID REFERENCES perfiles(id),
  canal                 canal_chat DEFAULT 'web',
  telefono_whatsapp     TEXT,
  mensajes              JSONB DEFAULT '[]'::jsonb,
  estado                TEXT DEFAULT 'activa',
  solicitud_generada_id UUID REFERENCES solicitudes_servicio(id),
  creado_en             TIMESTAMPTZ DEFAULT NOW(),
  actualizado_en        TIMESTAMPTZ DEFAULT NOW()
);

-- galeria
CREATE TABLE IF NOT EXISTS galeria (
  id          UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  url_imagen  TEXT NOT NULL,
  pie_foto    TEXT,
  categoria   TEXT,
  orden       INT DEFAULT 0,
  visible     BOOLEAN DEFAULT TRUE,
  sucursal_id UUID REFERENCES sucursales(id),
  creado_en   TIMESTAMPTZ DEFAULT NOW()
);

-- empleados (modulo 003)
CREATE TABLE IF NOT EXISTS empleados (
  id              UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  sucursal_id     UUID REFERENCES sucursales(id),
  perfil_id       UUID REFERENCES perfiles(id) ON DELETE SET NULL UNIQUE,
  nombre_completo TEXT NOT NULL,
  cedula          TEXT UNIQUE,
  telefono        TEXT,
  email           TEXT,
  direccion       TEXT,
  foto_url        TEXT,
  fecha_nacimiento DATE,
  cargo           TEXT NOT NULL DEFAULT 'motorizado',
  tipo_contrato   TEXT NOT NULL DEFAULT 'indefinido',
  fecha_ingreso   DATE NOT NULL DEFAULT CURRENT_DATE,
  fecha_salida    DATE,
  estado          TEXT NOT NULL DEFAULT 'activo',
  salario_base    DECIMAL(10,2) NOT NULL DEFAULT 0,
  frecuencia_pago TEXT NOT NULL DEFAULT 'mensual',
  notas           TEXT,
  creado_en       TIMESTAMPTZ DEFAULT NOW(),
  actualizado_en  TIMESTAMPTZ DEFAULT NOW()
);

-- periodos_nomina (modulo 003)
CREATE TABLE IF NOT EXISTS periodos_nomina (
  id              UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  sucursal_id     UUID REFERENCES sucursales(id),
  nombre          TEXT NOT NULL,
  fecha_inicio    DATE NOT NULL,
  fecha_fin       DATE NOT NULL,
  estado          TEXT NOT NULL DEFAULT 'borrador',
  total_pagado    DECIMAL(10,2) DEFAULT 0,
  empleados_count INT DEFAULT 0,
  creado_por      UUID REFERENCES perfiles(id),
  cerrado_en      TIMESTAMPTZ,
  creado_en       TIMESTAMPTZ DEFAULT NOW(),
  actualizado_en  TIMESTAMPTZ DEFAULT NOW()
);

-- nomina_pagos (modulo 003)
CREATE TABLE IF NOT EXISTS nomina_pagos (
  id              UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  periodo_id      UUID REFERENCES periodos_nomina(id) ON DELETE CASCADE,
  empleado_id     UUID REFERENCES empleados(id),
  salario_base    DECIMAL(10,2) NOT NULL DEFAULT 0,
  bonificaciones  DECIMAL(10,2) NOT NULL DEFAULT 0,
  deducciones     DECIMAL(10,2) NOT NULL DEFAULT 0,
  total_neto      DECIMAL(10,2) NOT NULL DEFAULT 0,
  estado          TEXT NOT NULL DEFAULT 'pendiente',
  metodo_pago     TEXT DEFAULT 'efectivo',
  notas           TEXT,
  pagado_en       TIMESTAMPTZ,
  creado_en       TIMESTAMPTZ DEFAULT NOW()
);

-- cms_config (modulo 004)
CREATE TABLE IF NOT EXISTS public.cms_config (
  clave          TEXT        PRIMARY KEY,
  valor          TEXT        NOT NULL DEFAULT '',
  actualizado_en TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- GARANTIZAR COLUMNAS EN TABLAS EXISTENTES
-- (Si la tabla ya existia de ejecucion parcial previa,
--  CREATE TABLE IF NOT EXISTS la omite, asi que agregamos
--  cada columna con ALTER TABLE ADD COLUMN IF NOT EXISTS)
-- ============================================================
ALTER TABLE sucursales              ADD COLUMN IF NOT EXISTS nombre          TEXT;
ALTER TABLE sucursales              ADD COLUMN IF NOT EXISTS direccion       TEXT;
ALTER TABLE sucursales              ADD COLUMN IF NOT EXISTS ciudad          TEXT NOT NULL DEFAULT 'Ocotal';
ALTER TABLE sucursales              ADD COLUMN IF NOT EXISTS departamento    TEXT NOT NULL DEFAULT 'Nueva Segovia';
ALTER TABLE sucursales              ADD COLUMN IF NOT EXISTS pais            TEXT NOT NULL DEFAULT 'Nicaragua';
ALTER TABLE sucursales              ADD COLUMN IF NOT EXISTS telefono_claro  TEXT;
ALTER TABLE sucursales              ADD COLUMN IF NOT EXISTS telefono_tigo   TEXT;
ALTER TABLE sucursales              ADD COLUMN IF NOT EXISTS correo          TEXT;
ALTER TABLE sucursales              ADD COLUMN IF NOT EXISTS activo          BOOLEAN DEFAULT TRUE;
ALTER TABLE sucursales              ADD COLUMN IF NOT EXISTS actualizado_en  TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE perfiles                ADD COLUMN IF NOT EXISTS rol             rol_usuario DEFAULT 'cliente';
ALTER TABLE perfiles                ADD COLUMN IF NOT EXISTS nombre_completo TEXT;
ALTER TABLE perfiles                ADD COLUMN IF NOT EXISTS telefono        TEXT;
ALTER TABLE perfiles                ADD COLUMN IF NOT EXISTS url_avatar      TEXT;
ALTER TABLE perfiles                ADD COLUMN IF NOT EXISTS sucursal_id     UUID;
ALTER TABLE perfiles                ADD COLUMN IF NOT EXISTS activo          BOOLEAN DEFAULT TRUE;
ALTER TABLE perfiles                ADD COLUMN IF NOT EXISTS actualizado_en  TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE motorizados             ADD COLUMN IF NOT EXISTS perfil_id        UUID;
ALTER TABLE motorizados             ADD COLUMN IF NOT EXISTS tipo_vehiculo    tipo_vehiculo DEFAULT 'moto';
ALTER TABLE motorizados             ADD COLUMN IF NOT EXISTS placa            TEXT;
ALTER TABLE motorizados             ADD COLUMN IF NOT EXISTS ubicacion_actual GEOGRAPHY(Point, 4326);
ALTER TABLE motorizados             ADD COLUMN IF NOT EXISTS disponible       BOOLEAN DEFAULT TRUE;
ALTER TABLE motorizados             ADD COLUMN IF NOT EXISTS ordenes_activas  INT DEFAULT 0;
ALTER TABLE motorizados             ADD COLUMN IF NOT EXISTS sucursal_id      UUID;
ALTER TABLE motorizados             ADD COLUMN IF NOT EXISTS activo           BOOLEAN DEFAULT TRUE;
ALTER TABLE motorizados             ADD COLUMN IF NOT EXISTS actualizado_en   TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE catalogo_servicios      ADD COLUMN IF NOT EXISTS tipo_servicio    tipo_servicio;
ALTER TABLE catalogo_servicios      ADD COLUMN IF NOT EXISTS nombre_mostrar   TEXT;
ALTER TABLE catalogo_servicios      ADD COLUMN IF NOT EXISTS descripcion      TEXT;
ALTER TABLE catalogo_servicios      ADD COLUMN IF NOT EXISTS precio_base      DECIMAL(10,2) DEFAULT 40.00;
ALTER TABLE catalogo_servicios      ADD COLUMN IF NOT EXISTS precio_por_parada DECIMAL(10,2) DEFAULT 40.00;
ALTER TABLE catalogo_servicios      ADD COLUMN IF NOT EXISTS nombre_icono     TEXT;
ALTER TABLE catalogo_servicios      ADD COLUMN IF NOT EXISTS precio_manual    BOOLEAN DEFAULT FALSE;
ALTER TABLE catalogo_servicios      ADD COLUMN IF NOT EXISTS activo           BOOLEAN DEFAULT TRUE;
ALTER TABLE catalogo_servicios      ADD COLUMN IF NOT EXISTS orden            INT DEFAULT 0;
ALTER TABLE catalogo_servicios      ADD COLUMN IF NOT EXISTS actualizado_en   TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE negocios                ADD COLUMN IF NOT EXISTS perfil_propietario_id UUID;
ALTER TABLE negocios                ADD COLUMN IF NOT EXISTS nombre                TEXT;
ALTER TABLE negocios                ADD COLUMN IF NOT EXISTS descripcion           TEXT;
ALTER TABLE negocios                ADD COLUMN IF NOT EXISTS mision                TEXT;
ALTER TABLE negocios                ADD COLUMN IF NOT EXISTS vision                TEXT;
ALTER TABLE negocios                ADD COLUMN IF NOT EXISTS categoria             TEXT;
ALTER TABLE negocios                ADD COLUMN IF NOT EXISTS url_logo              TEXT;
ALTER TABLE negocios                ADD COLUMN IF NOT EXISTS url_portada           TEXT;
ALTER TABLE negocios                ADD COLUMN IF NOT EXISTS telefono              TEXT;
ALTER TABLE negocios                ADD COLUMN IF NOT EXISTS direccion             TEXT;
ALTER TABLE negocios                ADD COLUMN IF NOT EXISTS ubicacion             GEOGRAPHY(Point, 4326);
ALTER TABLE negocios                ADD COLUMN IF NOT EXISTS tipo_plan             tipo_plan DEFAULT 'gratis';
ALTER TABLE negocios                ADD COLUMN IF NOT EXISTS suscripcion_activa    BOOLEAN DEFAULT TRUE;
ALTER TABLE negocios                ADD COLUMN IF NOT EXISTS suscripcion_vence_en  TIMESTAMPTZ;
ALTER TABLE negocios                ADD COLUMN IF NOT EXISTS activo                BOOLEAN DEFAULT TRUE;
ALTER TABLE negocios                ADD COLUMN IF NOT EXISTS verificado            BOOLEAN DEFAULT FALSE;
ALTER TABLE negocios                ADD COLUMN IF NOT EXISTS sucursal_id           UUID;
ALTER TABLE negocios                ADD COLUMN IF NOT EXISTS actualizado_en        TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE productos_negocio       ADD COLUMN IF NOT EXISTS negocio_id     UUID;
ALTER TABLE productos_negocio       ADD COLUMN IF NOT EXISTS nombre         TEXT;
ALTER TABLE productos_negocio       ADD COLUMN IF NOT EXISTS descripcion    TEXT;
ALTER TABLE productos_negocio       ADD COLUMN IF NOT EXISTS precio         DECIMAL(10,2);
ALTER TABLE productos_negocio       ADD COLUMN IF NOT EXISTS url_imagen     TEXT;
ALTER TABLE productos_negocio       ADD COLUMN IF NOT EXISTS categoria      TEXT;
ALTER TABLE productos_negocio       ADD COLUMN IF NOT EXISTS inventario     INT;
ALTER TABLE productos_negocio       ADD COLUMN IF NOT EXISTS disponible     BOOLEAN DEFAULT TRUE;
ALTER TABLE productos_negocio       ADD COLUMN IF NOT EXISTS orden          INT DEFAULT 0;
ALTER TABLE productos_negocio       ADD COLUMN IF NOT EXISTS actualizado_en TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE solicitudes_servicio    ADD COLUMN IF NOT EXISTS perfil_cliente_id UUID;
ALTER TABLE solicitudes_servicio    ADD COLUMN IF NOT EXISTS tipo_servicio     tipo_servicio;
ALTER TABLE solicitudes_servicio    ADD COLUMN IF NOT EXISTS estado            estado_servicio DEFAULT 'pendiente';
ALTER TABLE solicitudes_servicio    ADD COLUMN IF NOT EXISTS direccion_origen  TEXT;
ALTER TABLE solicitudes_servicio    ADD COLUMN IF NOT EXISTS ubicacion_origen  GEOGRAPHY(Point, 4326);
ALTER TABLE solicitudes_servicio    ADD COLUMN IF NOT EXISTS paradas           JSONB DEFAULT '[]'::jsonb;
ALTER TABLE solicitudes_servicio    ADD COLUMN IF NOT EXISTS cantidad_paradas  INT DEFAULT 1;
ALTER TABLE solicitudes_servicio    ADD COLUMN IF NOT EXISTS direccion_destino TEXT;
ALTER TABLE solicitudes_servicio    ADD COLUMN IF NOT EXISTS ubicacion_destino GEOGRAPHY(Point, 4326);
ALTER TABLE solicitudes_servicio    ADD COLUMN IF NOT EXISTS precio_total      DECIMAL(10,2) DEFAULT 0;
ALTER TABLE solicitudes_servicio    ADD COLUMN IF NOT EXISTS contenido_paquete TEXT;
ALTER TABLE solicitudes_servicio    ADD COLUMN IF NOT EXISTS notas             TEXT;
ALTER TABLE solicitudes_servicio    ADD COLUMN IF NOT EXISTS detalles_servicio JSONB DEFAULT '{}'::jsonb;
ALTER TABLE solicitudes_servicio    ADD COLUMN IF NOT EXISTS canal_origen      canal_chat DEFAULT 'web';
ALTER TABLE solicitudes_servicio    ADD COLUMN IF NOT EXISTS negocio_id        UUID;
ALTER TABLE solicitudes_servicio    ADD COLUMN IF NOT EXISTS sucursal_id       UUID;
ALTER TABLE solicitudes_servicio    ADD COLUMN IF NOT EXISTS actualizado_en    TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE asignaciones            ADD COLUMN IF NOT EXISTS solicitud_id     UUID;
ALTER TABLE asignaciones            ADD COLUMN IF NOT EXISTS motorizado_id    UUID;
ALTER TABLE asignaciones            ADD COLUMN IF NOT EXISTS estado           estado_servicio DEFAULT 'asignado';
ALTER TABLE asignaciones            ADD COLUMN IF NOT EXISTS asignado_en      TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE asignaciones            ADD COLUMN IF NOT EXISTS iniciado_en      TIMESTAMPTZ;
ALTER TABLE asignaciones            ADD COLUMN IF NOT EXISTS completado_en    TIMESTAMPTZ;
ALTER TABLE asignaciones            ADD COLUMN IF NOT EXISTS cancelado_en     TIMESTAMPTZ;
ALTER TABLE asignaciones            ADD COLUMN IF NOT EXISTS notas_motorizado TEXT;
ALTER TABLE asignaciones            ADD COLUMN IF NOT EXISTS actualizado_en   TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE ganancias               ADD COLUMN IF NOT EXISTS motorizado_id  UUID;
ALTER TABLE ganancias               ADD COLUMN IF NOT EXISTS asignacion_id  UUID;
ALTER TABLE ganancias               ADD COLUMN IF NOT EXISTS monto          DECIMAL(10,2);
ALTER TABLE ganancias               ADD COLUMN IF NOT EXISTS fecha_periodo  DATE DEFAULT CURRENT_DATE;
ALTER TABLE suscripciones           ADD COLUMN IF NOT EXISTS perfil_id      UUID;
ALTER TABLE suscripciones           ADD COLUMN IF NOT EXISTS estado         estado_suscripcion DEFAULT 'activa';
ALTER TABLE suscripciones           ADD COLUMN IF NOT EXISTS iniciado_en    TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE suscripciones           ADD COLUMN IF NOT EXISTS vence_en       TIMESTAMPTZ;
ALTER TABLE suscripciones           ADD COLUMN IF NOT EXISTS actualizado_en TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE suscripciones_negocio   ADD COLUMN IF NOT EXISTS negocio_id      UUID;
ALTER TABLE suscripciones_negocio   ADD COLUMN IF NOT EXISTS tipo_plan       tipo_plan DEFAULT 'gratis';
ALTER TABLE suscripciones_negocio   ADD COLUMN IF NOT EXISTS estado          estado_suscripcion DEFAULT 'activa';
ALTER TABLE suscripciones_negocio   ADD COLUMN IF NOT EXISTS precio_mensual  DECIMAL(10,2) DEFAULT 0;
ALTER TABLE suscripciones_negocio   ADD COLUMN IF NOT EXISTS iniciado_en     TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE suscripciones_negocio   ADD COLUMN IF NOT EXISTS vence_en        TIMESTAMPTZ;
ALTER TABLE suscripciones_negocio   ADD COLUMN IF NOT EXISTS actualizado_en  TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE contenido_cms           ADD COLUMN IF NOT EXISTS titulo          TEXT;
ALTER TABLE contenido_cms           ADD COLUMN IF NOT EXISTS tipo_contenido  tipo_contenido;
ALTER TABLE contenido_cms           ADD COLUMN IF NOT EXISTS contenido       JSONB DEFAULT '{}'::jsonb;
ALTER TABLE contenido_cms           ADD COLUMN IF NOT EXISTS seccion_destino TEXT;
ALTER TABLE contenido_cms           ADD COLUMN IF NOT EXISTS fecha_inicio    TIMESTAMPTZ;
ALTER TABLE contenido_cms           ADD COLUMN IF NOT EXISTS fecha_fin       TIMESTAMPTZ;
ALTER TABLE contenido_cms           ADD COLUMN IF NOT EXISTS estado          estado_contenido DEFAULT 'borrador';
ALTER TABLE contenido_cms           ADD COLUMN IF NOT EXISTS prioridad       INT DEFAULT 0;
ALTER TABLE contenido_cms           ADD COLUMN IF NOT EXISTS activo          BOOLEAN DEFAULT TRUE;
ALTER TABLE contenido_cms           ADD COLUMN IF NOT EXISTS creado_por      UUID;
ALTER TABLE contenido_cms           ADD COLUMN IF NOT EXISTS sucursal_id     UUID;
ALTER TABLE contenido_cms           ADD COLUMN IF NOT EXISTS actualizado_en  TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE testimonios             ADD COLUMN IF NOT EXISTS nombre_cliente TEXT;
ALTER TABLE testimonios             ADD COLUMN IF NOT EXISTS contenido      TEXT;
ALTER TABLE testimonios             ADD COLUMN IF NOT EXISTS calificacion   INT;
ALTER TABLE testimonios             ADD COLUMN IF NOT EXISTS url_avatar     TEXT;
ALTER TABLE testimonios             ADD COLUMN IF NOT EXISTS visible        BOOLEAN DEFAULT TRUE;
ALTER TABLE testimonios             ADD COLUMN IF NOT EXISTS orden          INT DEFAULT 0;
ALTER TABLE notificaciones          ADD COLUMN IF NOT EXISTS perfil_id UUID;
ALTER TABLE notificaciones          ADD COLUMN IF NOT EXISTS titulo    TEXT;
ALTER TABLE notificaciones          ADD COLUMN IF NOT EXISTS cuerpo    TEXT;
ALTER TABLE notificaciones          ADD COLUMN IF NOT EXISTS tipo      TEXT DEFAULT 'general';
ALTER TABLE notificaciones          ADD COLUMN IF NOT EXISTS datos     JSONB DEFAULT '{}'::jsonb;
ALTER TABLE notificaciones          ADD COLUMN IF NOT EXISTS leido     BOOLEAN DEFAULT FALSE;
ALTER TABLE sesiones_chat_ia        ADD COLUMN IF NOT EXISTS perfil_id             UUID;
ALTER TABLE sesiones_chat_ia        ADD COLUMN IF NOT EXISTS canal                 canal_chat DEFAULT 'web';
ALTER TABLE sesiones_chat_ia        ADD COLUMN IF NOT EXISTS telefono_whatsapp     TEXT;
ALTER TABLE sesiones_chat_ia        ADD COLUMN IF NOT EXISTS mensajes              JSONB DEFAULT '[]'::jsonb;
ALTER TABLE sesiones_chat_ia        ADD COLUMN IF NOT EXISTS estado                TEXT DEFAULT 'activa';
ALTER TABLE sesiones_chat_ia        ADD COLUMN IF NOT EXISTS solicitud_generada_id UUID;
ALTER TABLE sesiones_chat_ia        ADD COLUMN IF NOT EXISTS actualizado_en        TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE galeria                 ADD COLUMN IF NOT EXISTS url_imagen  TEXT;
ALTER TABLE galeria                 ADD COLUMN IF NOT EXISTS pie_foto    TEXT;
ALTER TABLE galeria                 ADD COLUMN IF NOT EXISTS categoria   TEXT;
ALTER TABLE galeria                 ADD COLUMN IF NOT EXISTS orden       INT DEFAULT 0;
ALTER TABLE galeria                 ADD COLUMN IF NOT EXISTS visible     BOOLEAN DEFAULT TRUE;
ALTER TABLE galeria                 ADD COLUMN IF NOT EXISTS sucursal_id UUID;
ALTER TABLE sucursales              ADD COLUMN IF NOT EXISTS creado_en    TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE perfiles                ADD COLUMN IF NOT EXISTS creado_en    TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE motorizados             ADD COLUMN IF NOT EXISTS creado_en    TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE catalogo_servicios      ADD COLUMN IF NOT EXISTS creado_en    TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE negocios                ADD COLUMN IF NOT EXISTS creado_en    TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE productos_negocio       ADD COLUMN IF NOT EXISTS creado_en    TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE solicitudes_servicio    ADD COLUMN IF NOT EXISTS creado_en    TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE asignaciones            ADD COLUMN IF NOT EXISTS creado_en    TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE ganancias               ADD COLUMN IF NOT EXISTS creado_en    TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE suscripciones           ADD COLUMN IF NOT EXISTS creado_en    TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE suscripciones_negocio   ADD COLUMN IF NOT EXISTS creado_en    TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE contenido_cms           ADD COLUMN IF NOT EXISTS creado_en    TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE testimonios             ADD COLUMN IF NOT EXISTS creado_en    TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE notificaciones          ADD COLUMN IF NOT EXISTS creado_en    TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE sesiones_chat_ia        ADD COLUMN IF NOT EXISTS creado_en    TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE galeria                 ADD COLUMN IF NOT EXISTS creado_en    TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE empleados               ADD COLUMN IF NOT EXISTS creado_en    TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE periodos_nomina         ADD COLUMN IF NOT EXISTS creado_en    TIMESTAMPTZ DEFAULT NOW();

-- ============================================================
-- COLLATIONS ICU - ESPANOL LATINOAMERICANO
-- ============================================================
CREATE COLLATION IF NOT EXISTS latinoamericano (
  PROVIDER = icu, LOCALE = 'es-419', DETERMINISTIC = TRUE
);

CREATE COLLATION IF NOT EXISTS latinoamericano_ci (
  PROVIDER = icu, LOCALE = 'es-419-u-ks-level2', DETERMINISTIC = FALSE
);

-- ============================================================
-- FULL-TEXT SEARCH CONFIG
-- ============================================================
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_ts_config WHERE cfgname = 'espanol_sin_acento') THEN
    CREATE TEXT SEARCH CONFIGURATION espanol_sin_acento (COPY = spanish);
  END IF;
END $$;

ALTER TEXT SEARCH CONFIGURATION espanol_sin_acento
  ALTER MAPPING FOR hword, word, hword_part, url, email
  WITH unaccent, spanish_stem;

DO $$ BEGIN
  EXECUTE 'ALTER DATABASE postgres SET default_text_search_config = ''espanol_sin_acento''';
EXCEPTION WHEN others THEN
  RAISE NOTICE 'No se pudo setear default_text_search_config a nivel de DB';
END $$;

-- ============================================================
-- INDICES
-- ============================================================
-- perfiles
CREATE INDEX IF NOT EXISTS idx_perfiles_rol       ON perfiles(rol);
CREATE INDEX IF NOT EXISTS idx_perfiles_sucursal  ON perfiles(sucursal_id);
CREATE INDEX IF NOT EXISTS idx_perfiles_telefono  ON perfiles(telefono);
CREATE INDEX IF NOT EXISTS idx_perfiles_nombre_normalizado
  ON perfiles (normalizar_texto(nombre_completo));

-- motorizados
CREATE INDEX IF NOT EXISTS idx_motorizados_ubicacion  ON motorizados USING GIST(ubicacion_actual);
CREATE INDEX IF NOT EXISTS idx_motorizados_disponible ON motorizados(disponible, ordenes_activas, activo);

-- negocios
CREATE INDEX IF NOT EXISTS idx_negocios_ubicacion   ON negocios USING GIST(ubicacion);
CREATE INDEX IF NOT EXISTS idx_negocios_categoria   ON negocios(categoria);
CREATE INDEX IF NOT EXISTS idx_negocios_plan        ON negocios(tipo_plan, suscripcion_activa);
CREATE INDEX IF NOT EXISTS idx_negocios_activo      ON negocios(activo);
CREATE INDEX IF NOT EXISTS idx_negocios_nombre_normalizado ON negocios (normalizar_texto(nombre));
CREATE INDEX IF NOT EXISTS idx_negocios_categoria_normalizada ON negocios (normalizar_texto(categoria));

-- productos
CREATE INDEX IF NOT EXISTS idx_productos_negocio ON productos_negocio(negocio_id, disponible);
CREATE INDEX IF NOT EXISTS idx_productos_nombre_normalizado ON productos_negocio (normalizar_texto(nombre));

-- solicitudes
CREATE INDEX IF NOT EXISTS idx_solicitudes_estado    ON solicitudes_servicio(estado);
CREATE INDEX IF NOT EXISTS idx_solicitudes_cliente   ON solicitudes_servicio(perfil_cliente_id);
CREATE INDEX IF NOT EXISTS idx_solicitudes_tipo      ON solicitudes_servicio(tipo_servicio);
CREATE INDEX IF NOT EXISTS idx_solicitudes_ubicacion ON solicitudes_servicio USING GIST(ubicacion_origen);
CREATE INDEX IF NOT EXISTS idx_solicitudes_fecha     ON solicitudes_servicio(creado_en DESC);
CREATE INDEX IF NOT EXISTS idx_solicitudes_negocio   ON solicitudes_servicio(negocio_id);
CREATE INDEX IF NOT EXISTS idx_solicitudes_origen_normalizado
  ON solicitudes_servicio (normalizar_texto(direccion_origen));

-- asignaciones
CREATE INDEX IF NOT EXISTS idx_asignaciones_motorizado ON asignaciones(motorizado_id, estado);
CREATE INDEX IF NOT EXISTS idx_asignaciones_solicitud  ON asignaciones(solicitud_id);

-- ganancias
CREATE INDEX IF NOT EXISTS idx_ganancias_motorizado ON ganancias(motorizado_id, fecha_periodo DESC);

-- CMS
CREATE INDEX IF NOT EXISTS idx_cms_estado  ON contenido_cms(estado, activo);
CREATE INDEX IF NOT EXISTS idx_cms_fechas  ON contenido_cms(fecha_inicio, fecha_fin);
CREATE INDEX IF NOT EXISTS idx_cms_seccion ON contenido_cms(seccion_destino);

-- chat
CREATE INDEX IF NOT EXISTS idx_chat_perfil   ON sesiones_chat_ia(perfil_id);
CREATE INDEX IF NOT EXISTS idx_chat_whatsapp ON sesiones_chat_ia(telefono_whatsapp);
CREATE INDEX IF NOT EXISTS idx_chat_canal    ON sesiones_chat_ia(canal, estado);

-- notificaciones
CREATE INDEX IF NOT EXISTS idx_notificaciones_perfil ON notificaciones(perfil_id, leido, creado_en DESC);

-- empleados
CREATE INDEX IF NOT EXISTS idx_empleados_sucursal ON empleados(sucursal_id);
CREATE INDEX IF NOT EXISTS idx_empleados_estado   ON empleados(estado);
CREATE INDEX IF NOT EXISTS idx_empleados_cargo    ON empleados(cargo);
CREATE INDEX IF NOT EXISTS idx_empleados_cedula   ON empleados(cedula);

-- nomina
CREATE INDEX IF NOT EXISTS idx_periodos_sucursal ON periodos_nomina(sucursal_id);
CREATE INDEX IF NOT EXISTS idx_periodos_estado   ON periodos_nomina(estado);
CREATE INDEX IF NOT EXISTS idx_nomina_pagos_periodo  ON nomina_pagos(periodo_id);
CREATE INDEX IF NOT EXISTS idx_nomina_pagos_empleado ON nomina_pagos(empleado_id);

-- FTS indexes
CREATE INDEX IF NOT EXISTS idx_negocios_busqueda  ON negocios USING GIN(vector_busqueda);
CREATE INDEX IF NOT EXISTS idx_productos_busqueda ON productos_negocio USING GIN(vector_busqueda);

-- ============================================================
-- VISTAS (CREATE OR REPLACE VIEW)
-- ============================================================

CREATE OR REPLACE VIEW contenido_cms_activo AS
SELECT *
FROM   contenido_cms
WHERE  activo        = TRUE
  AND  estado        = 'activo'
  AND  fecha_inicio  <= NOW()
  AND  fecha_fin     >= NOW()
ORDER  BY prioridad DESC;

CREATE OR REPLACE VIEW motorizados_disponibles AS
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

CREATE OR REPLACE VIEW resumen_ganancias_motorizados AS
SELECT
  m.id               AS motorizado_id,
  p.nombre_completo  AS nombre_motorizado,
  COALESCE(SUM(CASE WHEN g.fecha_periodo = CURRENT_DATE THEN g.monto END), 0) AS ganancias_hoy,
  COALESCE(SUM(CASE WHEN g.fecha_periodo >= DATE_TRUNC('week',    CURRENT_DATE) THEN g.monto END), 0) AS ganancias_semana,
  COALESCE(SUM(CASE WHEN g.fecha_periodo >= DATE_TRUNC('month',   CURRENT_DATE) THEN g.monto END), 0) AS ganancias_mes,
  COALESCE(SUM(CASE WHEN g.fecha_periodo >= DATE_TRUNC('quarter', CURRENT_DATE) THEN g.monto END), 0) AS ganancias_trimestre,
  COALESCE(SUM(CASE WHEN g.fecha_periodo >= CURRENT_DATE - INTERVAL '6 months'  THEN g.monto END), 0) AS ganancias_semestre,
  COALESCE(SUM(CASE WHEN DATE_TRUNC('year', g.fecha_periodo::TIMESTAMPTZ) = DATE_TRUNC('year', NOW()) THEN g.monto END), 0) AS ganancias_anio,
  COALESCE(SUM(g.monto), 0) AS ganancias_total
FROM   motorizados m
JOIN   perfiles    p ON m.perfil_id = p.id
LEFT JOIN ganancias g ON m.id = g.motorizado_id
GROUP  BY m.id, p.nombre_completo;

-- ============================================================
-- FUNCIONES (CREATE OR REPLACE FUNCTION)
-- ============================================================

CREATE OR REPLACE FUNCTION normalizar_texto(texto_entrada TEXT)
RETURNS TEXT LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE AS $$
  SELECT LOWER(UNACCENT(texto_entrada))
$$;

CREATE OR REPLACE FUNCTION buscar_motorizados_disponibles(
  latitud  FLOAT, longitud FLOAT, radio_km FLOAT DEFAULT 3.5
)
RETURNS TABLE (
  motorizado_id   UUID, nombre_completo TEXT, telefono TEXT,
  distancia_km    FLOAT, ordenes_activas INT, tipo_vehiculo tipo_vehiculo
)
LANGUAGE SQL STABLE PARALLEL SAFE AS $$
  SELECT
    m.id, p.nombre_completo, p.telefono,
    ROUND((ST_Distance(m.ubicacion_actual, ST_MakePoint(longitud, latitud)::GEOGRAPHY) / 1000)::NUMERIC, 2)::FLOAT AS distancia_km,
    m.ordenes_activas, m.tipo_vehiculo
  FROM   motorizados m
  JOIN   perfiles    p ON m.perfil_id = p.id
  WHERE  m.disponible = TRUE AND m.activo = TRUE AND m.ordenes_activas < 3
    AND  m.ubicacion_actual IS NOT NULL
    AND  ST_DWithin(m.ubicacion_actual, ST_MakePoint(longitud, latitud)::GEOGRAPHY, radio_km * 1000)
  ORDER BY distancia_km ASC;
$$;

CREATE OR REPLACE FUNCTION calcular_precio_servicio(
  p_tipo_servicio tipo_servicio, p_cantidad_paradas INT DEFAULT 1
)
RETURNS DECIMAL(10,2) LANGUAGE SQL STABLE PARALLEL SAFE AS $$
  SELECT CASE
    WHEN precio_manual THEN 0.00
    ELSE precio_base + (precio_por_parada * GREATEST(p_cantidad_paradas - 1, 0))
  END FROM catalogo_servicios WHERE tipo_servicio = p_tipo_servicio;
$$;

-- actualizar_timestamp (reutilizable)
CREATE OR REPLACE FUNCTION actualizar_timestamp()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.actualizado_en = NOW();
  RETURN NEW;
END;
$$;

-- ordenes activas motorizado
CREATE OR REPLACE FUNCTION actualizar_ordenes_activas_motorizado()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.estado IN ('entregado', 'cancelado', 'declinado') THEN
    UPDATE motorizados
    SET    ordenes_activas = GREATEST(ordenes_activas - 1, 0), actualizado_en = NOW()
    WHERE  id = NEW.motorizado_id;
  ELSIF NEW.estado = 'asignado' AND (TG_OP = 'INSERT' OR OLD.estado != 'asignado') THEN
    UPDATE motorizados
    SET    ordenes_activas = ordenes_activas + 1, actualizado_en = NOW()
    WHERE  id = NEW.motorizado_id;
  END IF;
  RETURN NEW;
END;
$$;

-- sincronizar estado solicitud
CREATE OR REPLACE FUNCTION sincronizar_estado_solicitud()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  UPDATE solicitudes_servicio
  SET    estado = NEW.estado, actualizado_en = NOW()
  WHERE  id = NEW.solicitud_id;
  RETURN NEW;
END;
$$;

-- actualizar estado contenido CMS
CREATE OR REPLACE FUNCTION actualizar_estado_contenido_cms()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.estado := CASE
    WHEN NEW.fecha_fin   < NOW() THEN 'vencido'
    WHEN NEW.fecha_inicio > NOW() THEN 'programado'
    ELSE 'activo'
  END::estado_contenido;
  RETURN NEW;
END;
$$;

-- crear perfil nuevo usuario
CREATE OR REPLACE FUNCTION crear_perfil_nuevo_usuario()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE id_sucursal_principal UUID;
BEGIN
  SELECT id INTO id_sucursal_principal FROM sucursales LIMIT 1;
  INSERT INTO perfiles (id, nombre_completo, telefono, sucursal_id)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', 'Usuario nuevo'),
    NEW.raw_user_meta_data->>'phone',
    id_sucursal_principal
  );
  RETURN NEW;
END;
$$;

-- FTS functions
CREATE OR REPLACE FUNCTION actualizar_vector_busqueda_negocio()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.vector_busqueda :=
    SETWEIGHT(TO_TSVECTOR('espanol_sin_acento', COALESCE(UNACCENT(NEW.nombre), '')), 'A') ||
    SETWEIGHT(TO_TSVECTOR('espanol_sin_acento', COALESCE(UNACCENT(NEW.descripcion), '')), 'B') ||
    SETWEIGHT(TO_TSVECTOR('espanol_sin_acento', COALESCE(UNACCENT(NEW.categoria), '')), 'C') ||
    SETWEIGHT(TO_TSVECTOR('espanol_sin_acento', COALESCE(UNACCENT(NEW.direccion), '')), 'D');
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION actualizar_vector_busqueda_producto()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.vector_busqueda :=
    SETWEIGHT(TO_TSVECTOR('espanol_sin_acento', COALESCE(UNACCENT(NEW.nombre), '')), 'A') ||
    SETWEIGHT(TO_TSVECTOR('espanol_sin_acento', COALESCE(UNACCENT(NEW.descripcion), '')), 'B') ||
    SETWEIGHT(TO_TSVECTOR('espanol_sin_acento', COALESCE(UNACCENT(NEW.categoria), '')), 'C');
  RETURN NEW;
END;
$$;

-- Search functions
CREATE OR REPLACE FUNCTION buscar_negocios(
  texto_busqueda TEXT, filtro_categoria TEXT DEFAULT NULL
)
RETURNS TABLE (
  id UUID, nombre TEXT, descripcion TEXT, categoria TEXT,
  plan_tipo public.tipo_plan, url_logo TEXT, relevancia FLOAT
)
LANGUAGE SQL STABLE PARALLEL SAFE AS $$
  WITH consulta_procesada AS (
    SELECT TO_TSQUERY('espanol_sin_acento',
      ARRAY_TO_STRING(ARRAY(
        SELECT sin_acento || ':*'
        FROM REGEXP_SPLIT_TO_TABLE(UNACCENT(TRIM(texto_busqueda)), '\s+') AS sin_acento
        WHERE LENGTH(sin_acento) > 1
      ), ' & ')
    ) AS tsq
  )
  SELECT n.id, n.nombre, n.descripcion, n.categoria, n.tipo_plan, n.url_logo,
    TS_RANK_CD(n.vector_busqueda, c.tsq, 32) AS relevancia
  FROM negocios n, consulta_procesada c
  WHERE n.activo = TRUE AND n.vector_busqueda @@ c.tsq
    AND (filtro_categoria IS NULL OR normalizar_texto(n.categoria) ILIKE '%' || normalizar_texto(filtro_categoria) || '%')
  ORDER BY relevancia DESC;
$$;

CREATE OR REPLACE FUNCTION buscar_productos(
  texto_busqueda TEXT, filtro_negocio_id UUID DEFAULT NULL
)
RETURNS TABLE (
  id UUID, negocio_id UUID, nombre TEXT, descripcion TEXT,
  precio DECIMAL, url_imagen TEXT, relevancia FLOAT
)
LANGUAGE SQL STABLE PARALLEL SAFE AS $$
  WITH consulta_procesada AS (
    SELECT TO_TSQUERY('espanol_sin_acento',
      ARRAY_TO_STRING(ARRAY(
        SELECT sin_acento || ':*'
        FROM REGEXP_SPLIT_TO_TABLE(UNACCENT(TRIM(texto_busqueda)), '\s+') AS sin_acento
        WHERE LENGTH(sin_acento) > 1
      ), ' & ')
    ) AS tsq
  )
  SELECT p.id, p.negocio_id, p.nombre, p.descripcion, p.precio, p.url_imagen,
    TS_RANK_CD(p.vector_busqueda, c.tsq, 32) AS relevancia
  FROM productos_negocio p, consulta_procesada c
  WHERE p.disponible = TRUE AND p.vector_busqueda @@ c.tsq
    AND (filtro_negocio_id IS NULL OR p.negocio_id = filtro_negocio_id)
  ORDER BY relevancia DESC;
$$;

-- RLS helper functions
CREATE OR REPLACE FUNCTION obtener_mi_rol()
RETURNS rol_usuario LANGUAGE SQL STABLE SECURITY DEFINER AS $$
  SELECT rol FROM perfiles WHERE id = auth.uid();
$$;

CREATE OR REPLACE FUNCTION es_administrador()
RETURNS BOOLEAN LANGUAGE SQL STABLE AS $$
  SELECT obtener_mi_rol() IN ('administrador', 'super_administrador');
$$;

-- ============================================================
-- TRIGGERS (DROP IF EXISTS + CREATE)
-- ============================================================

-- Timestamp triggers
DROP TRIGGER IF EXISTS trg_timestamp_sucursales ON sucursales;
CREATE TRIGGER trg_timestamp_sucursales BEFORE UPDATE ON sucursales FOR EACH ROW EXECUTE FUNCTION actualizar_timestamp();

DROP TRIGGER IF EXISTS trg_timestamp_perfiles ON perfiles;
CREATE TRIGGER trg_timestamp_perfiles BEFORE UPDATE ON perfiles FOR EACH ROW EXECUTE FUNCTION actualizar_timestamp();

DROP TRIGGER IF EXISTS trg_timestamp_motorizados ON motorizados;
CREATE TRIGGER trg_timestamp_motorizados BEFORE UPDATE ON motorizados FOR EACH ROW EXECUTE FUNCTION actualizar_timestamp();

DROP TRIGGER IF EXISTS trg_timestamp_negocios ON negocios;
CREATE TRIGGER trg_timestamp_negocios BEFORE UPDATE ON negocios FOR EACH ROW EXECUTE FUNCTION actualizar_timestamp();

DROP TRIGGER IF EXISTS trg_timestamp_productos ON productos_negocio;
CREATE TRIGGER trg_timestamp_productos BEFORE UPDATE ON productos_negocio FOR EACH ROW EXECUTE FUNCTION actualizar_timestamp();

DROP TRIGGER IF EXISTS trg_timestamp_solicitudes ON solicitudes_servicio;
CREATE TRIGGER trg_timestamp_solicitudes BEFORE UPDATE ON solicitudes_servicio FOR EACH ROW EXECUTE FUNCTION actualizar_timestamp();

DROP TRIGGER IF EXISTS trg_timestamp_asignaciones ON asignaciones;
CREATE TRIGGER trg_timestamp_asignaciones BEFORE UPDATE ON asignaciones FOR EACH ROW EXECUTE FUNCTION actualizar_timestamp();

DROP TRIGGER IF EXISTS trg_timestamp_cms ON contenido_cms;
CREATE TRIGGER trg_timestamp_cms BEFORE UPDATE ON contenido_cms FOR EACH ROW EXECUTE FUNCTION actualizar_timestamp();

DROP TRIGGER IF EXISTS trg_timestamp_chat ON sesiones_chat_ia;
CREATE TRIGGER trg_timestamp_chat BEFORE UPDATE ON sesiones_chat_ia FOR EACH ROW EXECUTE FUNCTION actualizar_timestamp();

DROP TRIGGER IF EXISTS trg_timestamp_empleados ON empleados;
CREATE TRIGGER trg_timestamp_empleados BEFORE UPDATE ON empleados FOR EACH ROW EXECUTE FUNCTION actualizar_timestamp();

DROP TRIGGER IF EXISTS trg_timestamp_periodos ON periodos_nomina;
CREATE TRIGGER trg_timestamp_periodos BEFORE UPDATE ON periodos_nomina FOR EACH ROW EXECUTE FUNCTION actualizar_timestamp();

-- Ordenes activas motorizado
DROP TRIGGER IF EXISTS trg_ordenes_activas_motorizado ON asignaciones;
CREATE TRIGGER trg_ordenes_activas_motorizado
  AFTER INSERT OR UPDATE OF estado ON asignaciones
  FOR EACH ROW EXECUTE FUNCTION actualizar_ordenes_activas_motorizado();

-- Sincronizar estado solicitud
DROP TRIGGER IF EXISTS trg_sincronizar_estado_solicitud ON asignaciones;
CREATE TRIGGER trg_sincronizar_estado_solicitud
  AFTER UPDATE OF estado ON asignaciones
  FOR EACH ROW EXECUTE FUNCTION sincronizar_estado_solicitud();

-- Estado contenido CMS
DROP TRIGGER IF EXISTS trg_estado_contenido_cms ON contenido_cms;
CREATE TRIGGER trg_estado_contenido_cms
  BEFORE INSERT OR UPDATE OF fecha_inicio, fecha_fin ON contenido_cms
  FOR EACH ROW EXECUTE FUNCTION actualizar_estado_contenido_cms();

-- Crear perfil de nuevo usuario
DROP TRIGGER IF EXISTS trg_nuevo_usuario ON auth.users;
CREATE TRIGGER trg_nuevo_usuario
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION crear_perfil_nuevo_usuario();

-- FTS triggers
DROP TRIGGER IF EXISTS trg_vector_busqueda_negocio ON negocios;
CREATE TRIGGER trg_vector_busqueda_negocio
  BEFORE INSERT OR UPDATE OF nombre, descripcion, categoria, direccion
  ON negocios FOR EACH ROW EXECUTE FUNCTION actualizar_vector_busqueda_negocio();

DROP TRIGGER IF EXISTS trg_vector_busqueda_producto ON productos_negocio;
CREATE TRIGGER trg_vector_busqueda_producto
  BEFORE INSERT OR UPDATE OF nombre, descripcion, categoria
  ON productos_negocio FOR EACH ROW EXECUTE FUNCTION actualizar_vector_busqueda_producto();

-- ============================================================
-- ALTER COLLATION EN COLUMNAS
-- ============================================================
ALTER TABLE sucursales
  ALTER COLUMN nombre      TYPE TEXT COLLATE latinoamericano,
  ALTER COLUMN direccion   TYPE TEXT COLLATE latinoamericano,
  ALTER COLUMN ciudad      TYPE TEXT COLLATE latinoamericano,
  ALTER COLUMN departamento TYPE TEXT COLLATE latinoamericano,
  ALTER COLUMN pais        TYPE TEXT COLLATE latinoamericano;

ALTER TABLE perfiles ALTER COLUMN nombre_completo TYPE TEXT COLLATE latinoamericano;

ALTER TABLE catalogo_servicios
  ALTER COLUMN nombre_mostrar TYPE TEXT COLLATE latinoamericano,
  ALTER COLUMN descripcion    TYPE TEXT COLLATE latinoamericano,
  ALTER COLUMN nombre_icono   TYPE TEXT COLLATE latinoamericano;

ALTER TABLE negocios
  ALTER COLUMN nombre      TYPE TEXT COLLATE latinoamericano,
  ALTER COLUMN descripcion TYPE TEXT COLLATE latinoamericano,
  ALTER COLUMN mision      TYPE TEXT COLLATE latinoamericano,
  ALTER COLUMN vision      TYPE TEXT COLLATE latinoamericano,
  ALTER COLUMN categoria   TYPE TEXT COLLATE latinoamericano,
  ALTER COLUMN direccion   TYPE TEXT COLLATE latinoamericano;

ALTER TABLE productos_negocio
  ALTER COLUMN nombre      TYPE TEXT COLLATE latinoamericano,
  ALTER COLUMN descripcion TYPE TEXT COLLATE latinoamericano,
  ALTER COLUMN categoria   TYPE TEXT COLLATE latinoamericano;

ALTER TABLE solicitudes_servicio
  ALTER COLUMN direccion_origen  TYPE TEXT COLLATE latinoamericano,
  ALTER COLUMN direccion_destino TYPE TEXT COLLATE latinoamericano,
  ALTER COLUMN contenido_paquete TYPE TEXT COLLATE latinoamericano,
  ALTER COLUMN notas             TYPE TEXT COLLATE latinoamericano;

ALTER TABLE asignaciones ALTER COLUMN notas_motorizado TYPE TEXT COLLATE latinoamericano;

ALTER TABLE contenido_cms
  ALTER COLUMN titulo          TYPE TEXT COLLATE latinoamericano,
  ALTER COLUMN seccion_destino TYPE TEXT COLLATE latinoamericano;

ALTER TABLE testimonios
  ALTER COLUMN nombre_cliente TYPE TEXT COLLATE latinoamericano,
  ALTER COLUMN contenido      TYPE TEXT COLLATE latinoamericano;

ALTER TABLE notificaciones
  ALTER COLUMN titulo TYPE TEXT COLLATE latinoamericano,
  ALTER COLUMN cuerpo TYPE TEXT COLLATE latinoamericano;

ALTER TABLE galeria
  ALTER COLUMN pie_foto  TYPE TEXT COLLATE latinoamericano,
  ALTER COLUMN categoria TYPE TEXT COLLATE latinoamericano;

-- ============================================================
-- FTS VECTOR COLUMNS (ADD COLUMN IF NOT EXISTS)
-- ============================================================
ALTER TABLE negocios ADD COLUMN IF NOT EXISTS vector_busqueda TSVECTOR;
ALTER TABLE productos_negocio ADD COLUMN IF NOT EXISTS vector_busqueda TSVECTOR;

-- Actualizar vectores existentes
UPDATE negocios SET vector_busqueda =
  SETWEIGHT(TO_TSVECTOR('espanol_sin_acento', COALESCE(UNACCENT(nombre), '')), 'A') ||
  SETWEIGHT(TO_TSVECTOR('espanol_sin_acento', COALESCE(UNACCENT(descripcion), '')), 'B') ||
  SETWEIGHT(TO_TSVECTOR('espanol_sin_acento', COALESCE(UNACCENT(categoria), '')), 'C') ||
  SETWEIGHT(TO_TSVECTOR('espanol_sin_acento', COALESCE(UNACCENT(direccion), '')), 'D')
WHERE vector_busqueda IS NULL;

UPDATE productos_negocio SET vector_busqueda =
  SETWEIGHT(TO_TSVECTOR('espanol_sin_acento', COALESCE(UNACCENT(nombre), '')), 'A') ||
  SETWEIGHT(TO_TSVECTOR('espanol_sin_acento', COALESCE(UNACCENT(descripcion), '')), 'B') ||
  SETWEIGHT(TO_TSVECTOR('espanol_sin_acento', COALESCE(UNACCENT(categoria), '')), 'C')
WHERE vector_busqueda IS NULL;

-- ============================================================
-- ROW LEVEL SECURITY
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
ALTER TABLE empleados             ENABLE ROW LEVEL SECURITY;
ALTER TABLE periodos_nomina       ENABLE ROW LEVEL SECURITY;
ALTER TABLE nomina_pagos          ENABLE ROW LEVEL SECURITY;
ALTER TABLE cms_config            ENABLE ROW LEVEL SECURITY;

-- Perfiles
DROP POLICY IF EXISTS "perfiles_ver" ON perfiles;
CREATE POLICY "perfiles_ver" ON perfiles FOR SELECT USING (id = auth.uid() OR es_administrador());
DROP POLICY IF EXISTS "perfiles_insertar" ON perfiles;
CREATE POLICY "perfiles_insertar" ON perfiles FOR INSERT WITH CHECK (id = auth.uid());
DROP POLICY IF EXISTS "perfiles_actualizar" ON perfiles;
CREATE POLICY "perfiles_actualizar" ON perfiles FOR UPDATE USING (id = auth.uid() OR es_administrador());

-- Solicitudes
DROP POLICY IF EXISTS "solicitudes_ver" ON solicitudes_servicio;
CREATE POLICY "solicitudes_ver" ON solicitudes_servicio FOR SELECT
  USING (perfil_cliente_id = auth.uid() OR es_administrador() OR obtener_mi_rol() = 'motorizado');
DROP POLICY IF EXISTS "solicitudes_insertar" ON solicitudes_servicio;
CREATE POLICY "solicitudes_insertar" ON solicitudes_servicio FOR INSERT
  WITH CHECK (perfil_cliente_id = auth.uid() OR es_administrador());
DROP POLICY IF EXISTS "solicitudes_actualizar" ON solicitudes_servicio;
CREATE POLICY "solicitudes_actualizar" ON solicitudes_servicio FOR UPDATE
  USING (es_administrador());

-- Asignaciones
DROP POLICY IF EXISTS "asignaciones_ver" ON asignaciones;
CREATE POLICY "asignaciones_ver" ON asignaciones FOR SELECT
  USING (es_administrador() OR motorizado_id IN (SELECT id FROM motorizados WHERE perfil_id = auth.uid()));
DROP POLICY IF EXISTS "asignaciones_actualizar" ON asignaciones;
CREATE POLICY "asignaciones_actualizar" ON asignaciones FOR UPDATE
  USING (es_administrador() OR motorizado_id IN (SELECT id FROM motorizados WHERE perfil_id = auth.uid()));

-- Ganancias
DROP POLICY IF EXISTS "ganancias_ver" ON ganancias;
CREATE POLICY "ganancias_ver" ON ganancias FOR SELECT
  USING (motorizado_id IN (SELECT id FROM motorizados WHERE perfil_id = auth.uid()) OR es_administrador());

-- Notificaciones
DROP POLICY IF EXISTS "notificaciones_ver" ON notificaciones;
CREATE POLICY "notificaciones_ver" ON notificaciones FOR SELECT USING (perfil_id = auth.uid());
DROP POLICY IF EXISTS "notificaciones_actualizar" ON notificaciones;
CREATE POLICY "notificaciones_actualizar" ON notificaciones FOR UPDATE USING (perfil_id = auth.uid());

-- CMS
DROP POLICY IF EXISTS "cms_lectura_publica" ON contenido_cms;
CREATE POLICY "cms_lectura_publica" ON contenido_cms FOR SELECT
  USING ((estado = 'activo' AND activo = TRUE) OR es_administrador());
DROP POLICY IF EXISTS "cms_escritura_admin" ON contenido_cms;
CREATE POLICY "cms_escritura_admin" ON contenido_cms FOR ALL USING (es_administrador());

-- Negocios
DROP POLICY IF EXISTS "negocios_lectura_publica" ON negocios;
CREATE POLICY "negocios_lectura_publica" ON negocios FOR SELECT
  USING (activo = TRUE OR perfil_propietario_id = auth.uid() OR es_administrador());
DROP POLICY IF EXISTS "negocios_actualizar" ON negocios;
CREATE POLICY "negocios_actualizar" ON negocios FOR UPDATE
  USING (perfil_propietario_id = auth.uid() OR es_administrador());
DROP POLICY IF EXISTS "negocios_insertar" ON negocios;
CREATE POLICY "negocios_insertar" ON negocios FOR INSERT
  WITH CHECK (perfil_propietario_id = auth.uid() OR es_administrador());

-- Productos
DROP POLICY IF EXISTS "productos_lectura_publica" ON productos_negocio;
CREATE POLICY "productos_lectura_publica" ON productos_negocio FOR SELECT
  USING (disponible = TRUE OR es_administrador());
DROP POLICY IF EXISTS "productos_gestion_propietario" ON productos_negocio;
CREATE POLICY "productos_gestion_propietario" ON productos_negocio FOR ALL
  USING (negocio_id IN (SELECT id FROM negocios WHERE perfil_propietario_id = auth.uid()) OR es_administrador());

-- Chat
DROP POLICY IF EXISTS "chat_ver" ON sesiones_chat_ia;
CREATE POLICY "chat_ver" ON sesiones_chat_ia FOR SELECT USING (perfil_id = auth.uid() OR es_administrador());
DROP POLICY IF EXISTS "chat_insertar" ON sesiones_chat_ia;
CREATE POLICY "chat_insertar" ON sesiones_chat_ia FOR INSERT
  WITH CHECK (perfil_id = auth.uid() OR perfil_id IS NULL);
DROP POLICY IF EXISTS "chat_actualizar" ON sesiones_chat_ia;
CREATE POLICY "chat_actualizar" ON sesiones_chat_ia FOR UPDATE USING (perfil_id = auth.uid() OR es_administrador());

-- Empleados (modulo 003)
DROP POLICY IF EXISTS "empleados_admin" ON empleados;
CREATE POLICY "empleados_admin" ON empleados FOR ALL USING (
  EXISTS (SELECT 1 FROM perfiles p WHERE p.id = auth.uid() AND p.rol IN ('super_administrador', 'administrador'))
);

-- Periodos nomina (modulo 003)
DROP POLICY IF EXISTS "periodos_nomina_admin" ON periodos_nomina;
CREATE POLICY "periodos_nomina_admin" ON periodos_nomina FOR ALL USING (
  EXISTS (SELECT 1 FROM perfiles p WHERE p.id = auth.uid() AND p.rol IN ('super_administrador', 'administrador'))
);

-- Nomina pagos (modulo 003)
DROP POLICY IF EXISTS "nomina_pagos_admin" ON nomina_pagos;
CREATE POLICY "nomina_pagos_admin" ON nomina_pagos FOR ALL USING (
  EXISTS (SELECT 1 FROM perfiles p WHERE p.id = auth.uid() AND p.rol IN ('super_administrador', 'administrador'))
);

-- CMS config (modulo 004) 
DROP POLICY IF EXISTS "cms_config_public_read" ON cms_config;
CREATE POLICY "cms_config_public_read" ON public.cms_config FOR SELECT USING (true);
DROP POLICY IF EXISTS "cms_config_admin_write" ON cms_config;
CREATE POLICY "cms_config_admin_write" ON public.cms_config FOR ALL USING (
  EXISTS (SELECT 1 FROM public.perfiles WHERE id = auth.uid() AND rol IN ('super_admin', 'admin') AND activo = true)
);

-- ============================================================
-- DATOS SEMILLA (INSERT ... ON CONFLICT DO NOTHING)
-- ============================================================

-- Sucursal principal (solo si no existe ya)
INSERT INTO sucursales (nombre, ciudad, departamento, pais, telefono_claro, telefono_tigo)
SELECT 'Servicio Express Thimpson — Ocotal', 'Ocotal', 'Nueva Segovia', 'Nicaragua',
       '+50584159112', '+50585932295'
WHERE NOT EXISTS (SELECT 1 FROM sucursales WHERE nombre = 'Servicio Express Thimpson — Ocotal');

-- Catalogo de 7 servicios
INSERT INTO catalogo_servicios
  (tipo_servicio, nombre_mostrar, descripcion, precio_base, precio_por_parada, precio_manual, orden)
VALUES
  ('mandado',       'Mandado',       'Mandados dentro de Ocotal. C por parada.', 40.00, 40.00, FALSE, 1),
  ('delivery',      'Delivery',      'Entrega a domicilio. C por parada.',       40.00, 40.00, FALSE, 2),
  ('encomienda',    'Encomienda',    'Envio de paquetes. C por parada.',          40.00, 40.00, FALSE, 3),
  ('viaje_expreso', 'Viaje Expreso', 'Viajes al norte, centro y pacifico.',          0.00,  0.00,  TRUE,  4),
  ('transporte',    'Transporte',    'Transporte de personas o carga.',              0.00,  0.00,  TRUE,  5),
  ('acarreo',       'Acarreo',       'Traslado de materiales o muebles.',            0.00,  0.00,  TRUE,  6),
  ('mudanza',       'Mudanza',       'Mudanza completa.',                            0.00,  0.00,  TRUE,  7)
ON CONFLICT (tipo_servicio) DO NOTHING;

-- CMS config defaults
INSERT INTO public.cms_config (clave, valor) VALUES
  ('hero_titulo',         'Tu delivery de confianza en Ocotal'),
  ('hero_subtitulo',      'Motorizados verificados, entregas rapidas, precios justos.'),
  ('hero_badge',          '📍 Ocotal, Nicaragua'),
  ('whatsapp_numero',     '50587654321'),
  ('stats_entregas',      '500+'),
  ('stats_tiempo',        '< 60min'),
  ('stats_calificacion',  '4.9 ⭐'),
  ('cta_texto',           'Prefieres pedir por WhatsApp?'),
  ('testimonio_1_nombre', 'Maria G.'),
  ('testimonio_1_texto',  'Me trajeron mis compras en 40 minutos. Excelente servicio.'),
  ('testimonio_2_nombre', 'Carlos R.'),
  ('testimonio_2_texto',  'Rapidísimo y el motorizado siempre puntual.'),
  ('testimonio_3_nombre', 'Ana M.'),
  ('testimonio_3_texto',  'Pedí comida de mi restaurant favorito y llego caliente.')
ON CONFLICT (clave) DO NOTHING;

-- ============================================================
-- SUPABASE REALTIME
-- ============================================================
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE solicitudes_servicio;
EXCEPTION WHEN undefined_table THEN RAISE NOTICE 'Publication supabase_realtime no existe, omitiendo';
END $$;

DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE asignaciones;
EXCEPTION WHEN undefined_table THEN RAISE NOTICE 'Publication supabase_realtime no existe, omitiendo';
END $$;

DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE motorizados;
EXCEPTION WHEN undefined_table THEN RAISE NOTICE 'Publication supabase_realtime no existe, omitiendo';
END $$;

DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE notificaciones;
EXCEPTION WHEN undefined_table THEN RAISE NOTICE 'Publication supabase_realtime no existe, omitiendo';
END $$;

DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE sesiones_chat_ia;
EXCEPTION WHEN undefined_table THEN RAISE NOTICE 'Publication supabase_realtime no existe, omitiendo';
END $$;

-- ============================================================
-- FIX 005: CORRECCION "Thompson" -> "Thimpson"
-- ============================================================
UPDATE notificaciones
SET    titulo  = REPLACE(titulo,  'Thompson', 'Thimpson'),
       cuerpo  = REPLACE(cuerpo, 'Thompson', 'Thimpson'),
       actualizado_en = now()
WHERE  titulo  ILIKE '%Thompson%'
   OR  cuerpo ILIKE '%Thompson%';

UPDATE contenido_cms
SET    contenido = REPLACE(contenido::text, 'Thompson', 'Thimpson')::jsonb,
       actualizado_en = now()
WHERE  contenido::text ILIKE '%Thompson%';

UPDATE negocios
SET    nombre = REPLACE(nombre, 'Thompson', 'Thimpson'),
       descripcion = REPLACE(descripcion, 'Thompson', 'Thimpson'),
       actualizado_en = now()
WHERE  nombre ILIKE '%Thompson%'
   OR  descripcion ILIKE '%Thompson%';

UPDATE sucursales
SET    nombre = REPLACE(nombre, 'Thompson', 'Thimpson'),
       actualizado_en = now()
WHERE  nombre ILIKE '%Thompson%';

UPDATE testimonios
SET    nombre_cliente = REPLACE(nombre_cliente, 'Thompson', 'Thimpson'),
       contenido = REPLACE(contenido, 'Thompson', 'Thimpson')
WHERE  nombre_cliente ILIKE '%Thompson%'
   OR  contenido ILIKE '%Thompson%';

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
       actualizado_en = now()
WHERE  mensajes::text ILIKE '%Thompson%';

-- ============================================================
-- VERIFICACION FINAL
-- ============================================================
SELECT '✅ ESQUEMA MAESTRO v3.0 COMPLETADO EXITOSAMENTE' AS resultado;

COMMIT;
