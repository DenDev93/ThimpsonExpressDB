-- ════════════════════════════════════════════════════════
-- 004 — CMS Config table
-- Almacena pares clave/valor para el contenido de la web
-- ════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.cms_config (
  clave          TEXT        PRIMARY KEY,
  valor          TEXT        NOT NULL DEFAULT '',
  actualizado_en TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- RLS
ALTER TABLE public.cms_config ENABLE ROW LEVEL SECURITY;

-- Solo admins pueden modificar; lectura pública para la web
CREATE POLICY "cms_config_public_read" ON public.cms_config
  FOR SELECT USING (true);

CREATE POLICY "cms_config_admin_write" ON public.cms_config
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.perfiles
      WHERE id = auth.uid()
        AND rol IN ('super_admin', 'admin')
        AND activo = true
    )
  );

-- Valores iniciales por defecto
INSERT INTO public.cms_config (clave, valor) VALUES
  ('hero_titulo',         'Tu delivery de confianza en Ocotal'),
  ('hero_subtitulo',      'Motorizados verificados, entregas rápidas, precios justos. Pide lo que necesites y lo llevamos a tu puerta.'),
  ('hero_badge',          '📍 Ocotal, Nicaragua'),
  ('whatsapp_numero',     '50587654321'),
  ('stats_entregas',      '500+'),
  ('stats_tiempo',        '< 60min'),
  ('stats_calificacion',  '4.9 ⭐'),
  ('cta_texto',           '¿Prefieres pedir por WhatsApp?'),
  ('testimonio_1_nombre', 'María G.'),
  ('testimonio_1_texto',  'Me trajeron mis compras del supermercado en 40 minutos. Excelente servicio y muy amables.'),
  ('testimonio_2_nombre', 'Carlos R.'),
  ('testimonio_2_texto',  'Lo uso para enviar documentos a mis clientes. Rapidísimo y el motorizado siempre puntual.'),
  ('testimonio_3_nombre', 'Ana M.'),
  ('testimonio_3_texto',  'Pedí comida de mi restaurant favorito y llegó caliente. 100% recomendado.')
ON CONFLICT (clave) DO NOTHING;
