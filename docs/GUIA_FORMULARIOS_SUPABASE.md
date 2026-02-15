# Guia de Administracion de Formularios - Disbattery Trade

## Tabla de Contenidos
1. [Estructura de la Base de Datos](#estructura-de-la-base-de-datos)
2. [Tipos de Ruta (Formularios)](#tipos-de-ruta)
3. [Tipos de Pregunta Disponibles](#tipos-de-pregunta)
4. [Columnas de la Tabla](#columnas-de-la-tabla)
5. [Secciones por Formulario](#secciones-por-formulario)
6. [Como Modificar Preguntas](#como-modificar-preguntas)
7. [Como Agregar Nuevas Preguntas](#como-agregar-nuevas-preguntas)
8. [Como Eliminar Preguntas](#como-eliminar-preguntas)
9. [Preguntas Condicionales](#preguntas-condicionales)
10. [Listas Dinamicas (Productos)](#listas-dinamicas)
11. [Configuracion de Fotos](#configuracion-de-fotos)
12. [Ejemplos Practicos](#ejemplos-practicos)

---

## Estructura de la Base de Datos

Todo se maneja desde **una sola tabla**: `route_form_questions`

Cada fila de esta tabla es UNA pregunta del formulario. La app descarga todas las preguntas activas cuando el mercaderista inicia su ruta/evento, y las muestra en el orden configurado.

### Tabla: `route_types`
Define los tipos de visita disponibles:

| ID | Nombre | Color |
|----|--------|-------|
| `13631818-25ca-4803-bc79-f26dee3e643b` | Merchandising | `#4CAF50` (verde) |
| `ca89371f-8948-45e6-91d3-d259650c5a9e` | Impulso | `#FF9800` (naranja) |
| `c0aaac59-dd53-4917-99bd-9194c55ff528` | Evento | `#9C27B0` (morado) |

### Tabla: `route_form_questions`
Contiene TODAS las preguntas de TODOS los formularios.

---

## Tipos de Ruta

### Merchandising
- **Formulario tipo Stepper** (4 pasos)
- Fotos solo desde **camara** (no galeria)
- Secciones: senalizacion -> shell -> qualid -> reportes

### Impulso
- **Formulario tipo Stepper** (4 pasos)
- Fotos desde **galeria y camara**
- Secciones: senalizacion -> actividad -> ventas -> reportes

### Evento
- **Formulario en pagina unica** (scroll)
- Fotos desde **galeria y camara**
- NO tiene seccion de senalizacion
- Secciones: actividad -> ventas -> reportes

---

## Tipos de Pregunta

| Tipo (`question_type`) | Descripcion | Que ve el mercaderista |
|------------------------|-------------|------------------------|
| `text` | Texto corto | Campo de texto de una linea |
| `number` | Numero entero | Campo numerico (inicia en 0) |
| `boolean` | Si/No | Botones segmentados Si / No |
| `select` | Seleccion unica | Dropdown con opciones |
| `multiselect` | Seleccion multiple | Checkboxes con opciones |
| `photo` | Foto(s) | Boton para tomar/seleccionar foto |
| `textarea` | Texto largo | Campo de texto de varias lineas |
| `boolean_photo` | Si/No + foto si es Si | Botones Si/No, si marca Si aparece captura de foto |
| `number_photo` | Numero + foto | Campo numerico + captura de foto |
| `dynamic_list` | Lista de items tipo+cantidad | Selector de tipo + campo cantidad + boton Agregar |
| `rating` | Calificacion | Estrellas 1-5 |

---

## Columnas de la Tabla

### Columnas principales

| Columna | Tipo | Obligatorio | Descripcion |
|---------|------|-------------|-------------|
| `id` | UUID | Auto | ID unico (se genera solo) |
| `route_type_id` | UUID | Si | ID del tipo de ruta al que pertenece |
| `question_text` | TEXT | Si | Texto de la pregunta que ve el mercaderista |
| `question_type` | TEXT | Si | Tipo de pregunta (ver tabla arriba) |
| `display_order` | INTEGER | Si | **Orden de aparicion** (menor = primero) |
| `is_required` | BOOLEAN | No | Si es obligatoria (default: false) |
| `is_active` | BOOLEAN | No | Si esta activa (default: true) |
| `section` | TEXT | Si* | Seccion del formulario |
| `options` | JSONB | No | Opciones para select/multiselect/dynamic_list |
| `depends_on` | UUID | No | ID de la pregunta padre (condicional) |
| `depends_value` | TEXT | No | Valor que debe tener la pregunta padre para mostrar esta |
| `metadata` | JSONB | No | Configuraciones extra (fotos, limites, etc.) |

### Columna `display_order` - EL ORDEN IMPORTA

El `display_order` determina en que posicion aparece la pregunta. Se recomienda usar rangos con espacio para futuras inserciones:

| Seccion | Rango sugerido |
|---------|---------------|
| senalizacion | 1 - 9 |
| actividad / shell | 10 - 99 |
| qualid | 30 - 39 (Merch) |
| ventas | 100 - 199 |
| reportes | 200 - 299 |

**Ejemplo:** Si quieres agregar una pregunta entre `display_order` 20 y 30, puedes usar 25.

### Columna `section` - Secciones validas

| Formulario | Secciones validas |
|------------|-------------------|
| Merchandising | `senalizacion`, `shell`, `qualid`, `reportes` |
| Impulso | `senalizacion`, `actividad`, `ventas`, `reportes` |
| Evento | `actividad`, `ventas`, `reportes` |

### Columna `options` - Para selects y listas dinamicas

Formato JSON array de strings:
```json
["Opcion 1", "Opcion 2", "Opcion 3"]
```

Ejemplo real (Entregables Shell):
```json
["Ambientadores Shell para vehiculos", "Bolsas Shell para carros", "Llaveros de Tela Shell", "Gorras Shell"]
```

### Columna `metadata` - Configuraciones extra

Formato JSON object:
```json
{
  "camera_only": true,
  "max_photos": 5,
  "max_items": 10,
  "has_photo": true,
  "placeholder": "Texto de ayuda..."
}
```

| Campo metadata | Tipo | Descripcion |
|----------------|------|-------------|
| `camera_only` | boolean | `true` = solo camara, `false` = camara + galeria |
| `max_photos` | number | Maximo de fotos permitidas (default: 1) |
| `max_items` | number | Maximo de items en lista dinamica (default: 10) |
| `has_photo` | boolean | Si la lista dinamica incluye foto por item |
| `placeholder` | string | Texto de ayuda en campos textarea |

---

## Secciones por Formulario

### Merchandising (Stepper 4 pasos)

**Paso 1: Senalizacion** (`section = 'senalizacion'`)
| # | Pregunta | Tipo |
|---|----------|------|
| 1 | El cliente tiene senalizacion? | boolean_photo |

**Paso 2: Shell** (`section = 'shell'`)
| # | Pregunta | Tipo |
|---|----------|------|
| 2 | Foto actual del planograma | photo |
| 3 | Trabajaste en el planograma? | boolean_photo |
| 4 | Cuantos stickers autorizados tiene el cliente? | number |
| 5 | Cantidad de Sticker Nuevos Colocados | number_photo |
| 6 | Total de Cenefas Shell colocadas | number |
| 7 | Total de Papel Bobina Shell colocado (metros) | number |
| 8 | Stickers Shell Cambio de Lubricante entregados | number |
| 9 | Ambientadores Shell para vehiculo | number |
| 10 | Bolsas Shell para carro | number |
| 11 | Cliente con exhibidor Shell? | boolean |
| 12 | Cuantos exhibidores Shell? (solo si Q11=Si) | number_photo |
| 13 | Afiches Shell colocados | dynamic_list |
| 14 | Colocaste banderines de Shell? | boolean_photo |
| 15 | Colocaste aviso acrilico para exteriores Shell? | boolean_photo |

**Paso 3: Qualid** (`section = 'qualid'`)
| # | Pregunta | Tipo |
|---|----------|------|
| 16 | Hiciste el planograma de Qualid? | boolean |
| 17 | Total de Cenefas Qualid colocadas | number |
| 18 | Bolsas Qualid para carros entregadas | number |
| 19 | Sticker de garantia Qualid | number |
| 20 | Afiches Qualid Colocados | dynamic_list |
| 21 | Exhibidores de Cauchos Qualid | dynamic_list |

**Paso 4: Reportes** (`section = 'reportes'`)
| # | Pregunta | Tipo |
|---|----------|------|
| 22 | Reporte de producto faltante familias SHELL | textarea |
| 23 | Reporte de producto faltante familias QUALID | textarea |
| 24 | Reporte de comentarios adicionales | textarea |

---

### Impulso (Stepper 4 pasos)

**Paso 1: Senalizacion** (`section = 'senalizacion'`)
| # | Pregunta | Tipo |
|---|----------|------|
| 1 | El cliente tiene senalizacion? | boolean_photo |

**Paso 2: Actividad** (`section = 'actividad'`)
| # | Pregunta | Tipo | Condicional |
|---|----------|------|-------------|
| 2 | Marca Trabajada | select [Shell, Qualid] | - |
| 3 | Recursos Utilizados (Shell) | dynamic_list | Solo si Marca = Shell |
| 4 | Recursos Utilizados (Qualid) | dynamic_list | Solo si Marca = Qualid |
| 5 | Entregables Shell | dynamic_list | Solo si Marca = Shell |
| 6 | Entregables Qualid | dynamic_list | Solo si Marca = Qualid |
| 7 | Fotos de la actividad | photo (max 5) | - |

**Paso 3: Ventas** (`section = 'ventas'`)
| # | Pregunta | Tipo |
|---|----------|------|
| 8 | Reporte de Ventas Shell | dynamic_list |
| 9 | Reporte de Ventas Qualid | dynamic_list |

**Paso 4: Reportes** (`section = 'reportes'`)
| # | Pregunta | Tipo |
|---|----------|------|
| 10 | Reporte de producto faltante familias SHELL | textarea |
| 11 | Reporte de producto faltante familias QUALID | textarea |
| 12 | Comentarios adicionales | textarea |

---

### Evento (Pagina unica)

**Actividad** (`section = 'actividad'`)
| # | Pregunta | Tipo | Condicional |
|---|----------|------|-------------|
| 1 | Marca Trabajada | select [Shell, Qualid] | - |
| 2 | Recursos Utilizados (Shell) | dynamic_list | Solo si Marca = Shell |
| 3 | Recursos Utilizados (Qualid) | dynamic_list | Solo si Marca = Qualid |
| 4 | Entregables Shell | dynamic_list | Solo si Marca = Shell |
| 5 | Entregables Qualid | dynamic_list | Solo si Marca = Qualid |
| 6 | Fotos del evento | photo (max 10) | - |

**Ventas** (`section = 'ventas'`)
| # | Pregunta | Tipo | Condicional |
|---|----------|------|-------------|
| 7 | Hubo ventas? | boolean | - |
| 8 | Reporte de Ventas Shell | dynamic_list | Solo si Hubo ventas = Si |
| 9 | Reporte de Ventas Qualid | dynamic_list | Solo si Hubo ventas = Si |

**Reportes** (`section = 'reportes'`)
| # | Pregunta | Tipo |
|---|----------|------|
| 10 | Reporte de producto faltante familias SHELL | textarea |
| 11 | Reporte de producto faltante familias QUALID | textarea |
| 12 | Comentarios adicionales | textarea |

---

## Como Modificar Preguntas

### Cambiar el texto de una pregunta

```sql
UPDATE route_form_questions
SET question_text = 'Nuevo texto de la pregunta'
WHERE id = 'UUID_DE_LA_PREGUNTA';
```

### Cambiar el orden de una pregunta

```sql
UPDATE route_form_questions
SET display_order = 25
WHERE id = 'UUID_DE_LA_PREGUNTA';
```

**Tip:** Para intercambiar dos preguntas de posicion, cambia los `display_order` de ambas.

### Cambiar si es obligatoria o no

```sql
UPDATE route_form_questions
SET is_required = true  -- o false
WHERE id = 'UUID_DE_LA_PREGUNTA';
```

### Modificar las opciones de un select o lista dinamica

```sql
-- Agregar una opcion nueva a Entregables Shell
UPDATE route_form_questions
SET options = '["Ambientadores Shell para vehiculos", "Bolsas Shell para carros", "Llaveros de Tela Shell", "Gorras Shell", "Bolsas Tipo Boutique Negro", "Bolsas Tipo Boutique Blanco", "Tapasol Shell/Qualid", "Globos Shell", "Vasos Shell", "Agendas", "NUEVO PRODUCTO"]'::jsonb
WHERE id = 'UUID_DE_LA_PREGUNTA';
```

**IMPORTANTE:** Al modificar `options`, hay que poner TODAS las opciones (las existentes + las nuevas). No se puede agregar solo una; se reemplaza el array completo.

### Cambiar el maximo de items de una lista dinamica

```sql
UPDATE route_form_questions
SET metadata = jsonb_set(metadata, '{max_items}', '15')
WHERE id = 'UUID_DE_LA_PREGUNTA';
```

### Cambiar el maximo de fotos

```sql
UPDATE route_form_questions
SET metadata = jsonb_set(metadata, '{max_photos}', '10')
WHERE id = 'UUID_DE_LA_PREGUNTA';
```

---

## Como Agregar Nuevas Preguntas

### Ejemplo: Agregar pregunta de numero al formulario de Merchandising (seccion Shell)

```sql
INSERT INTO route_form_questions (
  route_type_id,
  question_text,
  question_type,
  section,
  display_order,
  is_required,
  is_active,
  metadata
) VALUES (
  '13631818-25ca-4803-bc79-f26dee3e643b',  -- Merchandising
  'Cantidad de Pendones Shell colocados',
  'number',
  'shell',
  24,  -- Despues de aviso acrilico (23) y antes de qualid (30)
  true,
  true,
  '{}'::jsonb
);
```

### Ejemplo: Agregar nueva opcion de producto a Entregables Qualid en Impulso

```sql
-- Primero ver las opciones actuales
SELECT options FROM route_form_questions
WHERE id = 'cfd618b4-5bc2-4e49-a169-dbd9fbbf4cd1';

-- Luego actualizar agregando el nuevo producto
UPDATE route_form_questions
SET options = options || '["Franelas Qualid"]'::jsonb
WHERE id = 'cfd618b4-5bc2-4e49-a169-dbd9fbbf4cd1';
```

### Ejemplo: Agregar pregunta con foto a Evento

```sql
INSERT INTO route_form_questions (
  route_type_id,
  question_text,
  question_type,
  section,
  display_order,
  is_required,
  is_active,
  metadata
) VALUES (
  'c0aaac59-dd53-4917-99bd-9194c55ff528',  -- Evento
  'Foto del stand del evento',
  'photo',
  'actividad',
  35,  -- Entre entregables (31) y fotos generales (40)
  true,
  true,
  '{"max_photos": 3, "camera_only": false}'::jsonb
);
```

---

## Como Eliminar Preguntas

**NUNCA borrar filas directamente.** En su lugar, desactivar la pregunta:

```sql
UPDATE route_form_questions
SET is_active = false
WHERE id = 'UUID_DE_LA_PREGUNTA';
```

La app solo descarga preguntas con `is_active = true`, asi que la pregunta desaparecera del formulario pero los datos historicos se mantienen.

Para reactivar una pregunta desactivada:

```sql
UPDATE route_form_questions
SET is_active = true
WHERE id = 'UUID_DE_LA_PREGUNTA';
```

---

## Preguntas Condicionales

Las preguntas condicionales solo aparecen cuando la pregunta "padre" tiene un valor especifico.

### Como funciona

1. La pregunta hija tiene `depends_on` = UUID de la pregunta padre
2. La pregunta hija tiene `depends_value` = valor que debe tener la padre

### Ejemplo: Mostrar campo solo si "Hubo ventas?" = Si

```sql
-- Pregunta padre (ya existe)
-- ID: f4f873dd-aebb-4907-9848-624091d1b389
-- question_text: 'Hubo ventas?'
-- question_type: 'boolean'

-- Pregunta hija (condicional)
INSERT INTO route_form_questions (
  route_type_id,
  question_text,
  question_type,
  section,
  display_order,
  is_required,
  depends_on,
  depends_value,
  options,
  metadata
) VALUES (
  'c0aaac59-dd53-4917-99bd-9194c55ff528',  -- Evento
  'Monto total de ventas',
  'number',
  'ventas',
  115,
  false,
  'f4f873dd-aebb-4907-9848-624091d1b389',  -- ID de "Hubo ventas?"
  'true',  -- Solo aparece si "Hubo ventas?" = Si (true)
  null,
  '{}'::jsonb
);
```

### Valores de `depends_value` segun tipo de padre

| Tipo del padre | depends_value |
|----------------|---------------|
| `boolean` / `boolean_photo` | `'true'` o `'false'` |
| `select` | El texto exacto de la opcion: `'Shell'`, `'Qualid'` |

---

## Listas Dinamicas

Las preguntas tipo `dynamic_list` permiten al mercaderista agregar multiples items de tipo + cantidad.

### Estructura

- `options`: Array con los tipos disponibles (lo que el mercaderista selecciona del dropdown)
- `metadata.max_items`: Maximo de items que puede agregar
- `metadata.has_photo`: Si puede agregar foto por cada item de la lista

### Ejemplo: Lista de Afiches Shell (Merchandising)

```json
{
  "question_type": "dynamic_list",
  "options": ["Afiche Helix", "Afiche Rimula", "Afiche Advance", "Afiche Spirax"],
  "metadata": {
    "max_items": 3,
    "has_photo": true,
    "camera_only": true
  }
}
```

El mercaderista ve:
1. Dropdown con los 4 tipos de afiche
2. Campo de cantidad
3. Boton "Agregar"
4. Boton de foto (porque has_photo = true)
5. Lista de items agregados (maximo 3)

### Modificar opciones de una lista dinamica

Para agregar un nuevo tipo de afiche:

```sql
UPDATE route_form_questions
SET options = options || '["Afiche Nuevo Producto"]'::jsonb
WHERE id = 'a1000001-0013-4000-8000-000000000013';
```

Para reemplazar todas las opciones:

```sql
UPDATE route_form_questions
SET options = '["Opcion A", "Opcion B", "Opcion C"]'::jsonb
WHERE id = 'UUID_DE_LA_PREGUNTA';
```

Para cambiar el limite maximo de items:

```sql
UPDATE route_form_questions
SET metadata = jsonb_set(metadata, '{max_items}', '5')
WHERE id = 'UUID_DE_LA_PREGUNTA';
```

---

## Configuracion de Fotos

### Foto solo camara (Merchandising)

```sql
UPDATE route_form_questions
SET metadata = jsonb_set(metadata, '{camera_only}', 'true')
WHERE id = 'UUID_DE_LA_PREGUNTA';
```

### Foto desde galeria y camara (Impulso/Evento)

```sql
UPDATE route_form_questions
SET metadata = jsonb_set(metadata, '{camera_only}', 'false')
WHERE id = 'UUID_DE_LA_PREGUNTA';
```

### Cambiar cantidad maxima de fotos

```sql
UPDATE route_form_questions
SET metadata = jsonb_set(metadata, '{max_photos}', '10')
WHERE id = 'UUID_DE_LA_PREGUNTA';
```

---

## Ejemplos Practicos

### 1. Agregar un nuevo producto a Recursos Shell en Impulso

```sql
-- Ver opciones actuales
SELECT id, options FROM route_form_questions
WHERE question_text = 'Recursos Utilizados (Shell)'
AND route_type_id = 'ca89371f-8948-45e6-91d3-d259650c5a9e';

-- Agregar "Pendones Shell" a la lista
UPDATE route_form_questions
SET options = options || '["Pendones Shell"]'::jsonb
WHERE id = '7a6992e0-96f7-47df-836c-fffa5c01aad2';
```

### 2. Cambiar el orden: mover "Fotos de la actividad" antes de "Entregables"

```sql
-- Actualmente: Recursos(20) -> Entregables(30) -> Fotos(40)
-- Queremos: Recursos(20) -> Fotos(25) -> Entregables(30)
UPDATE route_form_questions
SET display_order = 25
WHERE id = 'bd565381-d88d-48a4-b3c9-89c71fe177d2';
```

### 3. Agregar nueva seccion de preguntas a Evento

```sql
-- Agregar pregunta "Tipo de evento" al inicio
INSERT INTO route_form_questions (
  route_type_id, question_text, question_type, section,
  display_order, is_required, options, metadata
) VALUES (
  'c0aaac59-dd53-4917-99bd-9194c55ff528',
  'Tipo de evento',
  'select',
  'actividad',
  5,  -- Antes de Marca Trabajada (10)
  true,
  '["Feria", "Activacion en punto", "Evento corporativo", "Otro"]'::jsonb,
  '{}'::jsonb
);
```

### 4. Desactivar toda la seccion de Qualid en Merchandising

```sql
UPDATE route_form_questions
SET is_active = false
WHERE route_type_id = '13631818-25ca-4803-bc79-f26dee3e643b'
AND section = 'qualid';
```

### 5. Ver todas las preguntas activas de un formulario

```sql
SELECT
  display_order,
  question_text,
  question_type,
  section,
  is_required,
  CASE WHEN depends_on IS NOT NULL THEN 'Condicional' ELSE '-' END as condicional
FROM route_form_questions
WHERE route_type_id = 'ID_DEL_TIPO_DE_RUTA'
AND is_active = true
ORDER BY display_order;
```

Reemplazar `ID_DEL_TIPO_DE_RUTA` con:
- Merchandising: `13631818-25ca-4803-bc79-f26dee3e643b`
- Impulso: `ca89371f-8948-45e6-91d3-d259650c5a9e`
- Evento: `c0aaac59-dd53-4917-99bd-9194c55ff528`

---

## Notas Importantes

1. **Los cambios son inmediatos**: Una vez modificada la tabla en Supabase, la proxima vez que un mercaderista inicie una ruta o evento, descargara las preguntas actualizadas.

2. **Offline**: Si el mercaderista ya descargo las preguntas (tiene la ruta abierta), vera la version anterior. Debe cerrar y volver a abrir la ruta para obtener los cambios.

3. **No borrar, desactivar**: Siempre usa `is_active = false` en lugar de `DELETE`. Esto preserva los datos historicos de respuestas.

4. **UUIDs son auto-generados**: Al insertar nuevas preguntas, no necesitas especificar el `id`, se genera automaticamente.

5. **Validar opciones JSON**: Asegurate de que el JSON de `options` y `metadata` este bien formado. Un error de sintaxis causara problemas en la app.

6. **display_order no necesita ser consecutivo**: Puedes usar 10, 20, 30... para dejar espacio. Solo importa el orden relativo.

7. **Fotos en Merchandising siempre desde camara**: El formulario de Merchandising esta configurado para usar solo la camara. Aunque pongas `camera_only: false`, el widget de Merchandising ignora eso y siempre usa camara.

8. **Preguntas condicionales ocultas**: Si una pregunta tiene `depends_on` y la condicion no se cumple, la pregunta no aparece. Las respuestas de preguntas ocultas no se envian.
