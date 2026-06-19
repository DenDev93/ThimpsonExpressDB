# ThimpsonExpressDB

Base de datos PostgreSQL para el ecosistema **Servicio Express Thimpson**.
Plataforma: **Supabase** | Deploy: **Vercel** | Versión: `2.0.0`

---

## Orden de ejecución

```
1. 001_esquema_inicial.sql          ← Estructura completa (ejecutar primero)
2. 002_caracteres_latinoamerica.sql ← Soporte español / ñ / acentos (ejecutar segundo)
3. 003_datos_prueba.sql             ← Datos de prueba (pendiente)
```

---

## Tablas del sistema (nombres en español)

| Tabla | Descripción |
|---|---|
| `sucursales` | Sedes del negocio (multi-tenant / multi-sede) |
| `perfiles` | Todos los usuarios del sistema (extiende auth.users) |
| `motorizados` | Repartidores con GPS en tiempo real |
| `catalogo_servicios` | Los 7 servicios que ofrece Thimpson |
| `negocios` | Negocios afiliados al marketplace |
| `productos_negocio` | Catálogo de productos de negocios afiliados |
| `solicitudes_servicio` | Pedidos y solicitudes (el corazón del sistema) |
| `asignaciones` | Vincula solicitud ↔ motorizado asignado |
| `ganancias` | Ingresos por motorizado (para reportes) |
| `suscripciones` | Planes de clientes (gratis / premium) |
| `suscripciones_negocio` | Planes de negocios afiliados |
| `contenido_cms` | Contenidos web programables por fecha |
| `testimonios` | Testimonios de clientes para la web pública |
| `notificaciones` | Notificaciones push e in-app |
| `sesiones_chat_ia` | Historial de chatbot (web + WhatsApp) |
| `galeria` | Fotos del negocio para la web pública |

---

## Funciones principales

```sql
-- Encontrar motorizados disponibles en radio de 3.5 km
SELECT * FROM buscar_motorizados_disponibles(13.4742, -86.3538, 3.5);

-- Calcular precio de un servicio según paradas
SELECT calcular_precio_servicio('mandado', 3);  -- Resultado: C$120

-- Buscar negocios sin importar acentos ni mayúsculas
SELECT * FROM buscar_negocios('cafe');           -- Encuentra: "Café Nicaragüense"
SELECT * FROM buscar_negocios('farmacia', 'salud');

-- Normalizar texto para comparaciones
SELECT normalizar_texto('José Ñoño de Ocotal');  -- Resultado: 'jose nono de ocotal'
```

---

## Soporte latinoamericano (migración 002)

| Característica | Detalle |
|---|---|
| **Encoding** | UTF-8 (Supabase default) |
| **Collation** | ICU `es-419` — español latinoamericano (BCP 47) |
| **Ordenamiento** | ñ entre n y o · á/é/í/ó/ú ordenan junto a su vocal base |
| **Búsqueda** | `café` encuentra `cafe` y viceversa |
| **Mayúsculas** | `jose` encuentra `José` y `JOSE` |
| **Full-text** | Stopwords + stemming en español |

---

## Cómo instalar en Supabase

1. Ir a `app.supabase.com` → tu proyecto
2. **Database → Extensions** → activar: `uuid-ossp`, `postgis`, `pgcrypto`
3. **SQL Editor → New Query** → pegar `001_esquema_inicial.sql` → **Run**
4. Nueva query → pegar `002_caracteres_latinoamerica.sql` → **Run**

---

## Variables de entorno para los proyectos React

```env
VITE_SUPABASE_URL=https://xxxxxxxx.supabase.co
VITE_SUPABASE_ANON_KEY=tu_anon_key_aqui
```

---

## Reglas de negocio implementadas

- **Radio de asignación:** 3.5 km máximo desde el origen de la solicitud
- **Carga máxima:** 3 órdenes activas por motorizado como máximo
- **Precios base (Ocotal):** C$40 por parada (mandado, delivery, encomienda)
- **Precios manuales:** viaje expreso, transporte, acarreo y mudanza los cotiza el CEO
- **CMS automático:** contenidos se activan/expiran por rango de fechas
- **Multi-tenant:** todas las tablas soportan múltiples sucursales

---

**GitHub:** https://github.com/DenDev93/ThimpsonExpressDB
