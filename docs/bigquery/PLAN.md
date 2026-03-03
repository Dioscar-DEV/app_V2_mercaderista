# Plan: Integración Supabase → Google Sheets → Looker Studio

## Objetivo
Enviar automáticamente los datos de visitas de la app mercaderista desde Supabase a los Google Sheets de respuestas (los mismos que usaba Google Forms), para que Looker Studio siga funcionando sin cambios.

## Arquitectura

```
App Flutter → Supabase (route_visit_answers) → Edge Function → Google Sheets → BigQuery (External) → Looker Studio
```

**¿Por qué Sheets y no BigQuery directo?**
Las tablas en BigQuery son EXTERNAL (apuntan a los Google Sheets de respuestas del formulario). No se puede hacer `insertAll` en tablas externas. Los datos deben ir al Sheet origen, y BigQuery los lee automáticamente.

## Google Sheets por sede y tipo de ruta

| sede_app         | route_type    | Sheet (nombre)                      | Sheet ID         | Tab               |
|------------------|---------------|--------------------------------------|------------------|-------------------|
| blitz_2000       | Merchandising | Formulario de Merchandising Blitz 2000 (Respuestas) | **PENDIENTE** | Respuestas de formulario 1 |
| blitz_2000       | Impulso/Evento| Formulario de Trade Blitz 2000 (Respuestas)          | **PENDIENTE** | Respuestas de formulario 1 |
| grupo_victoria   | Merchandising | Formulario de Merchandising G.Victoria (Respuestas)  | **PENDIENTE** | Respuestas de formulario 1 |
| grupo_victoria   | Impulso/Evento| Formulario de Trade G.Victoria (Respuestas)           | **PENDIENTE** | Respuestas de formulario 1 |
| oceano_pacifico  | Merchandising | Formulario de Merchandising O.Pacífico (Respuestas)  | **PENDIENTE** | Respuestas de formulario 1 |
| oceano_pacifico  | Impulso/Evento| Formulario de Trade O.Pacífico (Respuestas)           | **PENDIENTE** | Respuestas de formulario 1 |
| grupo_disbattery | Merchandising | Formulario de Merchandising G.Disbattery (Respuestas)| **PENDIENTE** | Respuestas de formulario 1 |
| grupo_disbattery | Impulso/Evento| Formulario de Trade G.Disbattery (Respuestas)         | **PENDIENTE** | Respuestas de formulario 1 |

> Los nombres de los Sheets son aproximados — el usuario debe confirmar los URLs reales.

## Formato de datos

Cada fila = 1 visita, con las columnas en el **mismo orden exacto** que el Google Form original:
- **Merchandising**: 67 columnas (ver `schemas/BLITZ_MERCHA.md`)
- **Trade (Impulso/Evento)**: 71 columnas (ver `schemas/BLITZ_TRADE.md`)

La primera columna es "Marca temporal" (timestamp de la visita) y la segunda "Dirección de correo electrónico" (email del mercaderista).

## Pasos de implementación

### Paso 1 — Schemas ✅ (COMPLETADO)
- BLITZ_TRADE schema documentado → ver `schemas/BLITZ_TRADE.md`
- BLITZ_MERCHA schema documentado → ver `schemas/BLITZ_MERCHA.md`
- Mapeo Supabase → columnas documentado → ver `mapping/MERCHANDISING.md`

### Paso 2 — Service Account Google Cloud ✅ (COMPLETADO)
- Service Account: `sync-app-mercaderista@disbattery.iam.gserviceaccount.com`
- JSON key descargada y guardada en `docs/bigquery/disbattery-6c13fe7c9a14.json` (en .gitignore)
- Secret guardado en Supabase como `BIGQUERY_SERVICE_ACCOUNT_JSON`

### Paso 3 — Permisos en Google Sheets (PENDIENTE - USUARIO)
El usuario debe:
1. Abrir cada uno de los 8 Google Sheets
2. Compartir cada Sheet con `sync-app-mercaderista@disbattery.iam.gserviceaccount.com` como **Editor**
3. Copiar el URL de cada Sheet (el ID está en la URL: `docs.google.com/spreadsheets/d/{SHEET_ID}/...`)
4. Compartirme los 8 URLs/IDs

### Paso 4 — Actualizar Edge Function `sync-to-bigquery` → `sync-to-sheets` (PENDIENTE)
Cambios necesarios en la Edge Function existente (v3):
- Cambiar OAuth scope de `bigquery` a `spreadsheets`
- Reemplazar `bqInsertRows()` con función `appendToSheet()`
- Usar Google Sheets API: `POST https://sheets.googleapis.com/v4/spreadsheets/{ID}/values/{TAB}:append`
- Mapear cada tabla a su Sheet ID + tab
- Construir fila como array de valores (no objeto JSON) en el **orden exacto de columnas del Sheet**
- Primera columna: timestamp formateado como "DD/MM/YYYY HH:MM:SS"

Lo que se PRESERVA de v3 (ya verificado y funcional):
- ✅ `getAccessToken()` — JWT auth con RS256
- ✅ `fetchVisits()` — Query Supabase con nested joins
- ✅ `buildMerchandisingRow()` — Pivoteo de 67 columnas
- ✅ `buildTradeRow()` — Pivoteo de 71 columnas
- ✅ Todos los regex patterns (afiches, recursos, entregables, ventas)
- ✅ `parseDynOption()` — Parser de "ItemName:qty"

### Paso 5 — Configurar cron diario (PENDIENTE)
- Cron en Supabase: todos los días a las 23:00 VEN (03:00 UTC)
- Llama al Edge Function con la fecha del día

### Paso 6 — Carga histórica (PENDIENTE)
- Decidir si cargar datos desde Feb 17, 2026 (primer día que la app se usó)
- Mismo Edge Function con parámetro `?date=YYYY-MM-DD` para cada día

## Necesidades pendientes del usuario

- [ ] Compartir los 8 Google Sheets con la Service Account como Editor
- [ ] Enviarme los URLs/IDs de los 8 Sheets
- [ ] Confirmar que los nombres de las tabs son "Respuestas de formulario 1" en todos
- [ ] Confirmar el orden exacto de columnas del Sheet de TRADE (solo vi el de Merchandising en el screenshot)
- [ ] ¿Cargar histórico desde Feb 17 o solo datos nuevos?
