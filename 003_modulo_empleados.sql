-- ============================================================
-- SERVICIO EXPRESS THIMPSON — Módulo de Empleados y Nómina
-- Migración: 003_modulo_empleados.sql
-- Versión: 1.0.0 | Fecha: 2026-06-20
-- ============================================================
-- INSTRUCCIONES:
--   1. Abre app.supabase.com → tu proyecto
--   2. SQL Editor → New Query → pega este archivo → RUN
-- ============================================================

-- ============================================================
-- TABLA: empleados
-- ============================================================
-- Registro maestro de recursos humanos.
-- Un empleado DEBE existir aquí antes de poder crear una cuenta
-- de motorizado. El campo perfil_id se llena cuando se le crea
-- acceso al sistema (cuenta en auth.users + perfiles).
-- ============================================================
CREATE TABLE IF NOT EXISTS empleados (
  id              UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  sucursal_id     UUID REFERENCES sucursales(id),

  -- Vínculo opcional con la cuenta del sistema (perfiles)
  -- Se llena cuando el empleado tiene cuenta creada en Supabase Auth
  perfil_id       UUID REFERENCES perfiles(id) ON DELETE SET NULL UNIQUE,

  -- Datos personales
  nombre_completo TEXT NOT NULL,
  cedula          TEXT UNIQUE,
  telefono        TEXT,
  email           TEXT,
  direccion       TEXT,
  foto_url        TEXT,
  fecha_nacimiento DATE,

  -- Datos laborales
  cargo           TEXT NOT NULL DEFAULT 'motorizado',
  -- Valores esperados: motorizado, administrativo, supervisor, gerente, otro
  tipo_contrato   TEXT NOT NULL DEFAULT 'indefinido',
  -- Valores: indefinido, temporal, por_hora, honorarios
  fecha_ingreso   DATE NOT NULL DEFAULT CURRENT_DATE,
  fecha_salida    DATE,            -- NULL = aún activo
  estado          TEXT NOT NULL DEFAULT 'activo',
  -- Valores: activo, inactivo, suspendido, retirado

  -- Nómina
  salario_base    DECIMAL(10,2) NOT NULL DEFAULT 0,
  frecuencia_pago TEXT NOT NULL DEFAULT 'mensual',
  -- Valores: semanal, quincenal, mensual

  -- Notas internas del administrador
  notas           TEXT,

  creado_en       TIMESTAMPTZ DEFAULT NOW(),
  actualizado_en  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_empleados_sucursal ON empleados(sucursal_id);
CREATE INDEX IF NOT EXISTS idx_empleados_estado   ON empleados(estado);
CREATE INDEX IF NOT EXISTS idx_empleados_cargo    ON empleados(cargo);
CREATE INDEX IF NOT EXISTS idx_empleados_cedula   ON empleados(cedula);


-- ============================================================
-- TABLA: periodos_nomina
-- ============================================================
-- Cada vez que el admin genera una nómina (semanal, quincenal o
-- mensual) se crea un registro aquí. Contiene el rango de fechas
-- y el total a pagar. El estado pasa de 'borrador' → 'aprobado'
-- → 'pagado' conforme se procesa.
-- ============================================================
CREATE TABLE IF NOT EXISTS periodos_nomina (
  id             UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  sucursal_id    UUID REFERENCES sucursales(id),
  nombre         TEXT NOT NULL,       -- Ej: "Nómina Mayo 2026 — Quincenal 1"
  fecha_inicio   DATE NOT NULL,
  fecha_fin      DATE NOT NULL,
  estado         TEXT NOT NULL DEFAULT 'borrador',
  -- Valores: borrador, aprobado, pagado, anulado
  total_pagado   DECIMAL(10,2) DEFAULT 0,
  empleados_count INT DEFAULT 0,
  creado_por     UUID REFERENCES perfiles(id),
  cerrado_en     TIMESTAMPTZ,
  creado_en      TIMESTAMPTZ DEFAULT NOW(),
  actualizado_en TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_periodos_sucursal ON periodos_nomina(sucursal_id);
CREATE INDEX IF NOT EXISTS idx_periodos_estado   ON periodos_nomina(estado);


-- ============================================================
-- TABLA: nomina_pagos
-- ============================================================
-- Línea de pago individual: un empleado en un período de nómina.
-- El total_neto es calculado: salario_base + bonificaciones - deducciones
-- ============================================================
CREATE TABLE IF NOT EXISTS nomina_pagos (
  id              UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  periodo_id      UUID REFERENCES periodos_nomina(id) ON DELETE CASCADE,
  empleado_id     UUID REFERENCES empleados(id),
  salario_base    DECIMAL(10,2) NOT NULL DEFAULT 0,
  bonificaciones  DECIMAL(10,2) NOT NULL DEFAULT 0,
  deducciones     DECIMAL(10,2) NOT NULL DEFAULT 0,
  total_neto      DECIMAL(10,2) NOT NULL DEFAULT 0,
  estado          TEXT NOT NULL DEFAULT 'pendiente',
  -- Valores: pendiente, pagado, retenido
  metodo_pago     TEXT DEFAULT 'efectivo',
  -- Valores: efectivo, transferencia, cheque
  notas           TEXT,
  pagado_en       TIMESTAMPTZ,
  creado_en       TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_nomina_pagos_periodo  ON nomina_pagos(periodo_id);
CREATE INDEX IF NOT EXISTS idx_nomina_pagos_empleado ON nomina_pagos(empleado_id);


-- ============================================================
-- RLS (Row Level Security)
-- ============================================================
-- Permitir que admins y super_admin lean y escriban empleados
-- ============================================================
ALTER TABLE empleados      ENABLE ROW LEVEL SECURITY;
ALTER TABLE periodos_nomina ENABLE ROW LEVEL SECURITY;
ALTER TABLE nomina_pagos   ENABLE ROW LEVEL SECURITY;

-- Política: solo admins y super_admin acceden
CREATE POLICY "empleados_admin" ON empleados
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM perfiles p
      WHERE p.id = auth.uid()
      AND p.rol IN ('super_admin', 'admin')
    )
  );

CREATE POLICY "periodos_nomina_admin" ON periodos_nomina
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM perfiles p
      WHERE p.id = auth.uid()
      AND p.rol IN ('super_admin', 'admin')
    )
  );

CREATE POLICY "nomina_pagos_admin" ON nomina_pagos
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM perfiles p
      WHERE p.id = auth.uid()
      AND p.rol IN ('super_admin', 'admin')
    )
  );

-- ============================================================
-- FIN DEL SCRIPT
-- ============================================================
