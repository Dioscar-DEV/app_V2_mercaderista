# Plan de Rediseño — Módulo de Reportes (Owner Dashboard)

## Contexto
Reemplazar los dashboards de Looker Studio por dashboards nativos en Flutter.
Solo visible para usuarios con rol **Owner**.
Los supervisores mantienen su módulo de reportes actual (más simple).

---

## Data disponible en Supabase

| Tabla | Registros | Contenido |
|---|---|---|
| blitz_merchandising | 11,108 | Visitas mercha Centro-Llanos (2024-2026) |
| blitz_trade | 604 | Impulsos/eventos Centro-Llanos |
| grupo_victoria_merchandising | 8,803 | Visitas mercha Occidente |
| grupo_victoria_trade | 322 | Impulsos/eventos Occidente |
| oriente_merchandising | 6,659 | Visitas mercha Oriente |
| oriente_trade | 351 | Impulsos/eventos Oriente |
| grupo_disbattery_merchandising | 0 | Centro-Capital (estructura lista, sin data aún) |
| grupo_disbattery_trade | 0 | Centro-Capital (estructura lista, sin data aún) |
| pop_materials | 3+ | Catálogo de materiales con costo y unidad |
| pop_stock | 3+ | Stock actual por sede |
| pop_movements | 4+ | Historial de ingresos/egresos |
| route_visits | 2,631 | Visitas desde la app (2026) |
| route_visit_answers | 61,384 | Respuestas de formularios |
| clients | 12,194 | Todos los clientes |
| users | 44 | Todos los usuarios |
| routes | 609 | Todas las rutas |

---

## Dashboards a construir

### 1. CONSULTAS SHELL (Dashboard Principal)

**Filtros globales:**
- Período (selector de rango de fechas)
- Región (Centro-Capital, Oriente, Centro-Llanos, Occidente)
- Sucursal/Ciudad (Valencia, Puerto Ordaz, Barinas, etc.)
- Tipo (Merchandising / Trade)
- Mercaderista (dropdown de usuarios)
- Cliente (dropdown/buscador de clientes)

**Componentes:**

| Componente | Tipo visual | Data source | Cálculo |
|---|---|---|---|
| Visitas Totales | KPI card grande | Tablas *_merchandising + *_trade | COUNT(*) |
| Clientes Visitados | KPI card grande | Tablas *_merchandising + *_trade | COUNT(DISTINCT rif_cliente) |
| Inversión Total | KPI card grande (rojo) | Materiales usados × costo_unitario (pop_materials) | SUM(cantidad × costo) |
| Costos por mes y categoría | Gráfico barras vertical (por mes) | Tablas reporting agrupadas por mes | SUM por mes |
| Costo por región | Gráfico barras vertical | Tablas reporting agrupadas por sede | SUM por sede |
| Top 10 clientes mayor inversión | Gráfico barras horizontal | Tablas reporting agrupadas por cliente | SUM por cliente, ORDER DESC, LIMIT 10 |
| Registros por ciudad | Gráfico pie/donut | Tablas reporting agrupadas por sucursal | COUNT por sucursal |
| Lista de clientes | Tabla con columnas: RIF, Cliente, Sucursal, Visitas | Tablas reporting | Agrupado por cliente |

**Nota sobre inversión:** La inversión se calcula multiplicando la cantidad de cada material usado por su costo_unitario en pop_materials. Para esto se necesita que todos los materiales tengan costo cargado.

---

### 2. INVENTARIO POP (Unificado — antes eran 3 dashboards)

Unifica: "Inventario por Sucursal" + "Inventario por Región" + "Inventario Disbattery"

**Filtros:**
- Descripción del material (buscador)
- Sucursal/Ciudad
- Tipo (Merchandising / Trade)
- Stock (positivo, negativo, cero)
- Código (si se agrega código MKT)

**Componentes:**

| Componente | Tipo visual | Data source |
|---|---|---|
| Tabla de inventario por sucursal | Tabla: Sucursal, Tipo, Descripción, Stock | pop_stock + pop_materials filtrado por sucursal/ciudad |
| Materiales por región | Gráfico pie/donut | pop_stock agrupado por sede |
| Tipo de materiales | Gráfico pie/donut | pop_stock agrupado por tipo_material (Merchandising vs Trade) |

**Vista "Por Sucursal":** Tabla agrupada por ciudad con materiales y stock
**Vista "Por Región":** Misma tabla agrupada por sede (Centro-Llanos, Occidente, etc.)
**Vista "Global (Disbattery)":** Todo el stock sin filtro, con código MKT

**Nota:** Considerar agregar campo `codigo` (ej: MKT001, MKT002) a pop_materials para replicar la vista de "Inventario Disbattery" que muestra códigos.

---

### 3. ARTÍCULOS ENTREGADOS

**Filtros:**
- Período
- Artículos (dropdown de materiales)
- Región
- Sucursal
- Cliente

**Componentes:**

| Componente | Tipo visual | Data source |
|---|---|---|
| Artículos (distribución) | Gráfico pie/donut | Tablas *_merchandising + *_trade, columnas numéricas de materiales |
| Regiones (distribución) | Gráfico pie/donut | Agrupado por sede |
| Ciudades (distribución) | Gráfico pie/donut | Agrupado por sucursal |
| Cantidad entregada | Tabla: Artículo, Cantidad | Agrupado por material, SUM |
| Cantidad de entregas por cliente | Tabla: Cliente, Artículo, Cantidad | Agrupado por cliente + material |

**Cómo calcular artículos entregados:**
De las tablas de merchandising: sumar columnas como total_cenefas_shell, total_stickers_cambio_lubricante, total_ambientadores_shell, total_bolsas_shell, afiches_*, total_banderines_shell, etc.
De las tablas de trade: sumar total_ambientadores_shell, total_bolsas_shell, total_gorras_shell, total_vasos_shell, etc.

---

### 4. DETALLES MERCHANDISING

**Filtros:**
- Período
- Región
- Sucursal
- Cliente

**Componentes:**

| Componente | Tipo visual | Data source |
|---|---|---|
| Clientes Totales | KPI card | COUNT(DISTINCT rif_cliente) de tablas *_merchandising |
| Clientes con Sticker | KPI card | COUNT donde coloco_sticker_shell > 0 |
| Clientes con Exhibidor | KPI card | COUNT donde cliente_tiene_exhibidores_shell = 'Si' |
| Tabla detallada | Tabla scrollable | Tablas *_merchandising |

**Columnas de la tabla:**
- Región (sede geográfica)
- Sucursal (ciudad)
- Cliente (nombre_establecimiento)
- Mercaderista (email)
- Fecha
- Sticker Venta Autorizado Shell
- Sticker Cambio de Lubricante
- Afiches (suma de todos los afiches)
- Avisos (aviso acrílico)
- Banderines
- Cenefas
- Exhibidores
- Papel Bobina

---

### 5. DETALLES TRADE

**Filtros:**
- Período
- Región
- Sucursal
- Mercaderista
- Cliente

**Componentes:**

| Componente | Tipo visual | Data source |
|---|---|---|
| Tabla detallada | Tabla scrollable | Tablas *_trade |

**Columnas de la tabla:**
- Región
- Sucursal
- Tipo (Impulso/Evento)
- Cliente
- Mercaderista (email)
- Fecha
- Marca promocionada
- Material de apoyo Shell (uniformes, banderolas, igloo, toldo, exhibidores)
- Material de apoyo Qualid
- Entregables Shell (ambientadores, bolsas, gorras, vasos, llaveros, etc.)
- Entregables Qualid
- Ventas Shell (litros por producto)
- Ventas Qualid

---

### 6. RESUMEN MATERIAL (Merchandising + Trade)

**Filtros:**
- Período (mes/año)
- Región
- Sucursal

**Componentes:**

| Componente | Tipo visual | Data source |
|---|---|---|
| Resumen mensual Merchandising | Tabla: Mes, Material, Cantidad | Tablas *_merchandising agrupadas por mes |
| Resumen mensual Trade | Tabla: Mes, Material, Cantidad | Tablas *_trade agrupadas por mes |

---

### 7. METAS Y ACTIVACIONES (Fase posterior)

**Requiere tabla nueva:** `activation_targets`

```sql
CREATE TABLE activation_targets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sede_app text NOT NULL,
  year integer NOT NULL,
  month integer NOT NULL,
  target_activations integer NOT NULL, -- Meta de activaciones del mes
  target_sales integer, -- Meta de ventas (litros/clientes)
  created_at timestamptz DEFAULT now()
);
```

**Dashboards:**

| Dashboard | Datos |
|---|---|
| Metas Activaciones Shell | Por Región: Año, Mes, Meta, Activaciones reales, % Cumplimiento, YTD |
| Metas de Venta por Activación | Por Región: Año, Mes, Meta, Compras clientes, % Cumplimiento, YTD |
| Detalles Activaciones | Tabla detallada de cada activación |

**Nota:** Las "activaciones" son las visitas de tipo Trade (Impulso + Evento). Se cuentan de las tablas *_trade.

---

## Cambios necesarios en DB

| Cambio | Tabla | Prioridad |
|---|---|---|
| Agregar campo `codigo` (MKT001, etc.) | pop_materials | Media |
| Cargar costos reales de todos los materiales | pop_materials | Alta |
| Crear tabla `activation_targets` | Nueva | Baja (Fase 7) |

---

## Arquitectura Flutter

### Estructura de archivos propuesta

```
lib/presentation/screens/admin/lo qreports/
├── owner_dashboard_screen.dart          -- Pantalla contenedora con sidebar/tabs
├── owner_filters.dart                   -- Widget de filtros globales reutilizable
├── sections/
│   ├── consultas_shell_section.dart     -- Dashboard principal con KPIs y gráficos
│   ├── inventario_pop_section.dart      -- Inventario unificado
│   ├── articulos_entregados_section.dart -- Distribución de artículos
│   ├── detalles_mercha_section.dart     -- Tabla detallada merchandising
│   ├── detalles_trade_section.dart      -- Tabla detallada trade
│   ├── resumen_material_section.dart    -- Resumen mensual
│   └── metas_section.dart              -- Metas (futuro)
└── widgets/
    ├── kpi_card.dart                    -- Card de KPI reutilizable
    ├── bar_chart_widget.dart            -- Gráfico de barras
    ├── pie_chart_widget.dart            -- Gráfico pie/donut
    └── data_table_widget.dart           -- Tabla de datos con scroll
```

### Provider

```
lib/presentation/providers/
└── owner_reports_provider.dart          -- Queries a todas las tablas de reporting
```

### Dependencias necesarias

```yaml
# Para gráficos (ya debería estar o agregar)
fl_chart: ^0.69.0
```

---

## Fases de ejecución

| Fase | Qué incluye | Horas | Prioridad |
|---|---|---|---|
| 1 | Dashboard Principal (KPIs + gráficos + filtros) | 6h | Alta |
| 2 | Inventario POP (unificado) | 3h | Alta |
| 3 | Artículos Entregados (pies + tablas) | 4h | Alta |
| 4 | Detalles Merchandising (KPIs + tabla) | 3h | Media |
| 5 | Detalles Trade (tabla) | 2h | Media |
| 6 | Resumen Material (mensual) | 3h | Media |
| 7 | Metas y Activaciones (requiere tabla nueva) | 4h | Baja |
| **Total** | | **25h** | |

---

## Notas importantes

- **Solo Owner:** Este dashboard completo solo es visible para usuarios con rol Owner
- **Supervisores:** Mantienen su módulo de reportes actual (KPIs de su sede)
- **Data histórica:** Viene de las tablas de reporting (*_merchandising, *_trade) que ya tienen data desde 2024
- **Data de la app:** Se sincroniza automáticamente vía triggers a las tablas de reporting
- **Inversión:** Se calcula como cantidad × costo_unitario. Requiere que pop_materials tenga costos cargados
- **Gráficos:** Usar fl_chart con el estilo visual de la app (colores del theme)
- **Responsivo:** Los dashboards deben adaptarse a web (desktop) y móvil

---

*Plan creado el 27 de marzo de 2026*
