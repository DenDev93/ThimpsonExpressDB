-- Fix enum values (run BEFORE main script, own transaction)
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'rol_usuario') THEN
    IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumtypid = (SELECT oid FROM pg_type WHERE typname='rol_usuario') AND enumlabel = 'super_administrador') THEN
      ALTER TYPE rol_usuario ADD VALUE 'super_administrador';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumtypid = (SELECT oid FROM pg_type WHERE typname='rol_usuario') AND enumlabel = 'administrador') THEN
      ALTER TYPE rol_usuario ADD VALUE 'administrador';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumtypid = (SELECT oid FROM pg_type WHERE typname='rol_usuario') AND enumlabel = 'propietario_negocio') THEN
      ALTER TYPE rol_usuario ADD VALUE 'propietario_negocio';
    END IF;
  END IF;
END $$;
SELECT 'Enum fixes applied' AS resultado;
