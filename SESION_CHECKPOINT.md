# CHECKPOINT DE SESIÓN — Servicio Express Thimpson
> Guardar este archivo. Al retomar, compártelo o dile a Claude: "retomemos el proyecto Thimpson desde el checkpoint"

---

## Estado actual: Fase 1 — Base de datos ✅ COMPLETADA

**Fecha de sesión:** 2026-06-18

---

## Lo que se construyó hoy

### ThimpsonExpressDB — v2.0.0 ✅

| Archivo | Líneas | Estado |
|---|---|---|
| `001_esquema_inicial.sql` | 1,084 | ✅ Listo para ejecutar en Supabase |
| `002_caracteres_latinoamerica.sql` | 474 | ✅ Listo (ejecutar después del 001) |
| `README.md` | — | ✅ Actualizado |

**16 tablas creadas (todas en español con comentarios completos):**
`sucursales` · `perfiles` · `motorizados` · `catalogo_servicios` · `negocios` · `productos_negocio` · `solicitudes_servicio` · `asignaciones` · `ganancias` · `suscripciones` · `suscripciones_negocio` · `contenido_cms` · `testimonios` · `notificaciones` · `sesiones_chat_ia` · `galeria`

**Vistas:** `contenido_cms_activo` · `motorizados_disponibles` · `resumen_ganancias_motorizados`

**Funciones:** `buscar_motorizados_disponibles(latitud, longitud, radio_km)` · `calcular_precio_servicio(tipo, paradas)` · `buscar_negocios(texto, categoria)` · `buscar_productos(texto, negocio_id)` · `normalizar_texto(texto)`

**Extras:** Triggers automáticos · RLS por rol · Supabase Realtime en 5 tablas · Collation ICU es-419 · Full-text search en español sin acentos

---

## Repos y su estado

| Repo | Ruta local | Estado |
|---|---|---|
| `ThimpsonExpressDB` | `C:\Users\DMLM\Desktop\ThimpsonExpressDB\` | ✅ Archivos SQL listos, subir a GitHub |
| `AdminThimpson` | `C:\Users\DMLM\Desktop\AdminThimpson\` | ⏳ Pendiente — Fase 2 |
| `appwebThimpson` | `C:\Users\DMLM\Desktop\appwebThimpson\` | ⏳ Pendiente — Fase 3 |
| `ThimpsonExpressMovilPublic` | `C:\Users\DMLM\Desktop\ThimpsonExpressMovilPublic\` | ⏳ Pendiente — Fase 4 |
| `ThimpsonExpressDrivers` | `C:\Users\DMLM\Desktop\ThimpsonExpressDrivers\` | ⏳ Pendiente — Fase 4 |

---

## Decisiones técnicas tomadas

| Decisión | Elección | Razón |
|---|---|---|
| Arquitectura backend | Monolito Modular Serverless | Menos complejidad operacional al inicio |
| Backend framework | Next.js API Routes en Vercel | Compatible con deploy actual |
| Base de datos | Supabase PostgreSQL + PostGIS | Ya elegido, ideal para geolocalización |
| Tiempo real | Supabase Realtime | Integrado, sin Redis adicional |
| Webs | React + Vite + TailwindCSS | Stack elegido por el usuario |
| Mobile | React Native + Expo | Stack elegido por el usuario |
| IA chatbot | Claude API `claude-haiku-4-5` | Velocidad + costo para chatbot |
| IA agente admin | Claude API `claude-sonnet-4-6` | Razonamiento complejo |
| WhatsApp | WhatsApp Business API Cloud (Meta) | Gratuito, sin hosting extra |
| Maps/GPS | Google Maps API o Mapbox | Para tracking de motorizados |

---

## Reglas de negocio implementadas en DB

- Radio máximo de asignación: **3.5 km** desde origen de la solicitud
- Máximo de órdenes simultáneas por motorizado: **3**
- Precios fijos (Ocotal): **C$40 por parada** (mandado, delivery, encomienda)
- Precios manuales: viaje expreso, transporte, acarreo, mudanza (define CEO)
- CMS: contenidos se activan/expiran automáticamente por `fecha_inicio` y `fecha_fin`
- Multi-tenant: todas las tablas tienen `sucursal_id`

---

## Identidad visual

### Web (Admin + App Web Pública)
```
#FBB03B  Amarillo Thimpson (logo, CTAs, resaltados)
#000000  Negro (fondos principales)
#FFFFFF  Blanco (texto de lectura)
#0B1F22  Dark teal (fondos secundarios, cajas)
#BC8A5F  Marrón (acento kraft)
```

### Mobile (App Cliente + App Motorizados)
```
#FFD500  Amarillo vibrante (botones, cabeceras, menú activo)
#FFFFFF  Blanco (fondo general)
#1A1A1A  Oscuro casi negro (tarjetas)
#000000  Negro (textos principales)
```

---

## Servicios de Thimpson (Ocotal, Nicaragua)

| Servicio | Precio | Tipo |
|---|---|---|
| Mandado | C$40/parada | Fijo |
| Delivery | C$40/parada | Fijo |
| Encomienda | C$40/parada | Fijo |
| Viaje Expreso | Manual | CEO cotiza (norte/centro/pacífico NI) |
| Transporte | Manual | CEO cotiza |
| Acarreo | Manual | CEO cotiza |
| Mudanza | Manual | CEO cotiza |

---

## Fases de construcción

| Fase | Qué se construye | Estado |
|---|---|---|
| **1 — DB** | Esquema Supabase completo | ✅ Completada |
| **1 — API** | Next.js serverless API Routes | ⏳ **SIGUIENTE** |
| **2 — Admin** | Panel AdminThimpson (React) | ⏳ Pendiente |
| **2 — IA** | Agente admin + chatbot web + WhatsApp bot | ⏳ Pendiente |
| **3 — Web** | appwebThimpson pública | ⏳ Pendiente |
| **4 — Mobile** | App cliente + App motorizados | ⏳ Pendiente |

---

## Próxima sesión — Continuar con:

> **"Construyamos la API serverless de Thimpson con Next.js"**

La API necesita estos módulos (en orden de prioridad):
1. `auth` — registro, login, roles
2. `solicitudes` — crear, listar, cambiar estado
3. `motorizados` — ubicación GPS, disponibilidad, asignación automática
4. `ganancias` — registrar y consultar por período
5. `negocios` — CRUD del marketplace
6. `cms` — gestión de contenidos programables
7. `notificaciones` — enviar push con Supabase
8. `chat-ia` — endpoint para agente IA (Claude API)
9. `whatsapp` — webhook para WhatsApp Business Cloud

---

## Contacto del negocio
- **Claro:** +50584159112
- **Tigo:** +50585932295
- **Ciudad:** Ocotal, Nueva Segovia, Nicaragua
- **GitHub:** https://github.com/DenDev93
