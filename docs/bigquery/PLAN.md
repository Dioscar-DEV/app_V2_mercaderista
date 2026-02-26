# Plan: Integración Supabase → BigQuery → Looker Studio

## Objetivo
Enviar automáticamente los datos de visitas de la app mercaderista desde Supabase a BigQuery para que Looker Studio siga funcionando como antes.

## Arquitectura

```
App Flutter → Supabase (route_visit_answers) → Edge Function → BigQuery → Looker Studio
```

La Edge Function corre diariamente a las 11pm Venezuela y:
1. Lee todas las visitas completadas del día
2. Pivotea las respuestas (muchas filas → una fila por visita)
3. Determina la tabla BigQuery según sede + tipo de ruta
4. Inserta vía BigQuery REST API

## Tabla BigQuery por sede y tipo de ruta

| sede_app         | route_type    | Tabla BigQuery              |
|------------------|---------------|-----------------------------|
| blitz_2000       | Merchandising | MERCADERISTA.BLITZ_MERCHANDISING      |
| blitz_2000       | Impulso/Evento| MERCADERISTA.BLITZ_TRADE              |
| grupo_victoria   | Merchandising | MERCADERISTA.GVICTORIA_MERCHANDISING  |
| grupo_victoria   | Impulso/Evento| MERCADERISTA.GVICTORIA_TRADE          |
| oceano_pacifico  | Merchandising | MERCADERISTA.OP_MERCHANDISING         |
| oceano_pacifico  | Impulso/Evento| MERCADERISTA.OP_TRADE                 |
| grupo_disbattery | Merchandising | MERCADERISTA.GDISBATERRY_MERHANDISING |
| grupo_disbattery | Impulso/Evento| MERCADERISTA.GDISBATERRY_TRADE        |

## Campos comunes (todas las tablas)

- `FECHA` — scheduled_date de la ruta
- `CORREO` — email del mercaderista
- `RIF` — rif del cliente
- `NOMBRE_ESTABLECIMIENTO` — cli_des del cliente
- `SUCURSAL` — sede_app de la ruta (ej. "Valencia")

## Pasos de implementación

### Paso 1 — Schemas ✅ (COMPLETADO)
- BLITZ_TRADE schema documentado → ver `schemas/BLITZ_TRADE.md`
- BLITZ_MERCHA schema documentado → ver `schemas/BLITZ_MERCHA.md`
- Mapeo Supabase → BigQuery documentado → ver `mapping/MERCHANDISING.md`

### Paso 2 — Service Account Google Cloud (PENDIENTE)
- Ir a: console.cloud.google.com → IAM → Service Accounts → Crear
- Proyecto: `disbattery`
- Roles necesarios: **BigQuery Data Editor** + **BigQuery Job User**
- Descargar JSON key
- Guardar en Supabase como Secret: `BIGQUERY_SERVICE_ACCOUNT_JSON`

### Paso 3 — Edge Function `sync-to-bigquery` (PENDIENTE)
- Crear en Supabase Edge Functions
- Leer visitas del día desde Supabase
- Transformar a formato BigQuery
- Insertar via BigQuery REST API (insertAll / streaming)

### Paso 4 — Scheduler diario (PENDIENTE)
- Configurar cron en Supabase: todos los días a las 23:00 VEN (03:00 UTC)
- O llamada manual desde dashboard admin

### Paso 5 — Carga histórica (PENDIENTE)
- Decidir si cargar datos desde Feb 16, 2026 (cuando arrancó la app)
- Mismo Edge Function con parámetro de fecha de inicio

## Decisiones pendientes del usuario
- [ ] ¿Cargar histórico desde Feb 16 o solo datos de hoy en adelante?
- [ ] ¿Schemas de GVICTORIA_MERCHANDISING y GVICTORIA_TRADE son iguales a BLITZ equivalentes?
- [ ] Crear Service Account y compartir JSON key
