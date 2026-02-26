# Mapeo: Supabase route_visit_answers → BigQuery BLITZ_MERCHANDISING

## Cómo funciona el mapeo

Supabase guarda UNA FILA por pregunta respondida.
BigQuery necesita UNA FILA por visita completa con todas las columnas.

La Edge Function agrupa por `visit_id`, pivotea todas las respuestas
y construye un objeto JSON con todos los campos para insertar en BQ.

## Campos base (de tablas de Supabase, no de answers)

| BigQuery Column | Fuente Supabase |
|---|---|
| FECHA | routes.scheduled_date |
| CORREO | users.email |
| RIF | clients.rif |
| NOMBRE_ESTABLECIMIENTO | clients.cli_des |
| SUCURSAL | routes.sede_app (humanizado: blitz_2000 → "Valencia") |

## Mapeo por question_text → BigQuery Column

### Sección Señalización
| question_text (Supabase) | BigQuery Column | Tipo answer |
|---|---|---|
| ¿El cliente tiene señalización? | TIENE_SENALIZACION | answer_boolean → "Si"/"No" |
| El cliente tiene señalización? (foto) | FOTO_SENALIZACION | answer_json.photo_urls[0] |

### Sección Shell - Planograma
| question_text | BigQuery Column | Tipo |
|---|---|---|
| ¿Trabajaste en el planograma? | HICISTE_PLANOGRAMA_SHELL | answer_boolean → "Si"/"No" |
| Foto actual del planograma | FOTO_ANTES_DEL_PLANOGRAMA_SHELL | answer_json.photo_urls[0] |
| (foto después - si existe) | FOTO_DESPUES_DEL_PLANOGRAMA_SHELL | answer_json.photo_urls[0] |

### Sección Shell - Números
| question_text | BigQuery Column | Tipo |
|---|---|---|
| ¿Cuántos stickers autorizados tiene el cliente? | CLIENTE_TIENE_STICKER_PUNTO_DE_VENTA_AUTORIZADO_SHELL | answer_number |
| Cantidad de Sticker Nuevos Colocados | COLOCASTE_STICKER_PUNTO_DE_VENTA_AUTORIZADO_SHELL | answer_number |
| Total de Cenefas Shell colocadas | TOTAL_DE_CENEFAS_SHELL_COLOCADAS | answer_number |
| Total de Papel Bobina Shell colocado (metros) | TOTAL_DE_PAPEL_BOBINA_SHELL_COLOCADO_EN_METROS | answer_number |
| Stickers Shell Cambio de Lubricante entregados | TOTAL_DE_STICKERS_SHELL_CAMBIO_DE_LUBRICANTE_ENTREGADOS | answer_number |
| Ambientadores Shell para vehículo | TOTAL_DE_AMBIENTADORES_SHELL_PARA_VEHICULO_ENTREGADOS | answer_number |
| Bolsas Shell para carro | TOTAL_DE_BOLSAS_SHELL_PARA_CARRO_ENTREGADAS | answer_number |
| ¿Cliente con exhibidor Shell? | EL_CLIENTE_TIENE_EXHIBIDORES_SHELL | answer_boolean → "Si"/"No" |
| ¿Cuántos exhibidores Shell? | DE_TENER_EXHIBIDORES_SHELL_FOTO | answer_number / foto |

### Sección Shell - Afiches (dynamic_list)
La pregunta "Afiches Shell colocados" genera answer_json del tipo:
`[{"type": "Afiches Campaña Ferrari 2023", "quantity": 3}, ...]`

Cada item se mapea a una columna BQ específica:

| Opción en app (type) | BigQuery Column |
|---|---|
| Afiches Campaña Ferrari 2023 | CUALES_Y_CUANTOS_AFICHES_SHELL_AFICHES_CAMPANA_FERRARI_2023 |
| Afiches Campaña HX8 2023 | CUALES_Y_CUANTOS_AFICHES_SHELL_AFICHES_CAMPANA_HX8 |
| Afiches Campaña Productos Premium 2024 | CUALES_Y_CUANTOS_AFICHES_SHELL_AFICHES_CAMPANA_PRODUCTOS_PREMIUM_2024 |
| Afiches Campaña Shell Familia | CUALES_Y_CUANTOS_AFICHES_SHELL_AFICHES_CAMPANA_SHELL_FAMILIA_2023 |
| Afiches Campaña Shell HX7 10W-40 | CUALES_Y_CUANTOS_AFICHES_SHELL_AFICHES_CAMPANA_SHELL_HX7_10W40 |
| Afiche Campaña Tabla de Aplicación Shell | CUALES_Y_CUANTOS_AFICHES_SHELL_AFICHES_CAMPANA_TABLA_DE_APLICACION_SHELL |
| Afiche Campaña Helix 2024 | AFICHE_SHELL_HELIX |
| Afiche Campaña Rimula 2024 | AFICHE_SHELL_RIMULA |
| Afiche Campaña Advance Shell 2024 | AFICHE_SHELL_ADVANCE |
| Afiche Campaña 5W30 Shell 2024 | AFICHE_SHELL_5W30 |
| Afiche Carrito Ferrari Amarillo | → NUEVA COLUMNA REQUERIDA en BQ |
| Afiche Carrito Ferrari Rojo | → NUEVA COLUMNA REQUERIDA en BQ |
| Afiche Advance Moto | → NUEVA COLUMNA REQUERIDA en BQ |
| Porta Afiche Metálico | → NUEVA COLUMNA REQUERIDA en BQ |

### Sección Shell - Banderines y Avisos
| question_text | BigQuery Column | Tipo |
|---|---|---|
| ¿Colocaste banderines de Shell? | COLOCASTE_TIRA_DE_BANDERINES_SHELL | answer_boolean → "Si"/"No" |
| ¿Colocaste aviso acrílico para exteriores Shell? | EL_CLIENTE_TIENE_AVISO_ACRILICO_PARA_EXTERIORES_SHELL | answer_boolean → "Si"/"No" |

### Sección Qualid - Planograma y Números
| question_text | BigQuery Column | Tipo |
|---|---|---|
| ¿Hiciste el planograma de Qualid? | HICISTE_PLANOGRAMA_QUALID | answer_boolean → "Si"/"No" |
| Total de Cenefas Qualid colocadas | TOTAL_DE_CENEFAS_QUALID_COLOCADAS | answer_number |
| Bolsas Qualid para carros entregadas | TOTAL_DE_BOLSAS_QUALID_PARA_CARRO_ENTREGADAS | answer_number |
| Sticker de garantía Qualid | CLIENTE_TIENE_STICKER_DE_GARANTIA_QUALID | answer_number |

### Sección Qualid - Afiches (dynamic_list)
| Opción en app (type) | BigQuery Column |
|---|---|
| Afiche Campaña Filtros y Fluidos | CUALES_Y_CUANTOS_AFICHES_QUALID_AFICHES_CAMPANA_FILTROS_Y_FLUIDOS_2024 |
| Afiche Campaña Qualid Caucho | CUALES_Y_CUANTOS_AFICHES_QUALID_AFICHES_CAMPANA_QUALID_CAUCHO_2024 |
| Afiche Campaña Qualid Tabla de Filtro Automotriz | CUALES_Y_CUANTOS_AFICHES_QUALID_AFICHES_CAMPANA_QUALID_TABLA_DE_FILTRO_AUTOMOTRIZ_2024 |
| Afiches Campaña Qualid Tabla Cross Reference 2024 | CUALES_Y_CUANTOS_AFICHES_QUALID_AFICHES_CAMPANA_QUALID_TABLA_CROSS_REFERENCE_SERVICIO_PESADO_2024 |
| Afiches Campaña Qualid Cuidado Automotriz | CUALES_Y_CUANTOS_AFICHES_QUALID_AFICHES_CAMPANA_QUALID_CUIDADO_AUTOMOTRIZ_2022 |
| Afiches Campaña Qualid Filtro | CUALES_Y_CUANTOS_AFICHES_QUALID_AFICHES_CAMPANA_QUALID_FILTROS_2022 |

### Sección Qualid - Exhibidores (dynamic_list)
La pregunta "Exhibidores de Cauchos Qualid" genera answer_json:
`[{"type": "Exhibidor de Caucho Pequeño", "quantity": 1}, ...]`

| Opción en app | BigQuery Column |
|---|---|
| Exhibidor de Caucho Pequeño | TOTAL_DE_EXHIBIDOR_DE_CAUCHO_PEQUENO_COLOCADO |
| Exhibidor de Caucho Grande | TOTAL_DE_EXHIBIDORES_DE_CAUCHO_GRANDE_COLOCADO |

### Sección Reportes
| question_text | BigQuery Column | Tipo |
|---|---|---|
| Reporte de producto faltante familias SHELL | OBSERVACIONES_SHELL | answer_text |
| Reporte de producto faltante familias QUALID | OBSERVACIONES_QUALID | answer_text |
| Reporte de comentarios adicionales | OBSERVACIONES_GENERALES | answer_text |

## Columnas BQ sin equivalente en app actual (se envían null o 0)
- FOTO_SENALIZACION (la app guarda la foto en storage, no en answers)
- FOTO_ANTES_DEL_PLANOGRAMA_SHELL
- FOTO_DESPUES_DEL_PLANOGRAMA_SHELL
- FOTOS_DE_LOS_AFICHES_SHELL_COLOCADOS
- FOTOS_DE_LOS_BANDERINES_SHELL_COLOCADOS
- FOTO_DEL_AVISO_ACRILICO_PARA_EXTERIORES_SHELL_COLOCADO
- FOTO_DE_EXHIBIDORES_DE_CAUCHOS_QUALID_COLOCADOS
- AFICHE_SHELL_GADUS_2021 (no existe en app nueva)
