# Columnas exactas del Google Sheet — Trade (Impulso/Evento)

Orden exacto de la fila 1 (headers) del Sheet de respuestas.
61 columnas. Valores vacíos = `0`.

| # | Header exacto del Sheet |
|---|------------------------|
| 1 | Marca temporal |
| 2 | Dirección de correo electrónico |
| 3 | Registro de material para Impulso o Evento: |
| 4 | Rif del cliente: |
| 5 | Nombre del establecimiento: |
| 6 | Indica el nombre del evento: |
| 7 | Indica la ciudad en la que se realizó el evento: |
| 8 | ¿Qué marca fue promocionada en el impulso o evento? |
| 9 | ¿Qué material de apoyo Shell se utilizó? [UNIFORMES DE PROMOTORAS SHELL] |
| 10 | ¿Qué material de apoyo Shell se utilizó? [BANDEROLAS SHELL] |
| 11 | ¿Qué material de apoyo Shell se utilizó? [IGLOO SHELL] |
| 12 | ¿Qué material de apoyo Shell se utilizó? [TOLDO SHELL] |
| 13 | ¿Qué material de apoyo Shell se utilizó? [EXHIBIDORES SHELL] |
| 14 | Fotos del impulso o evento SHELL: |
| 15 | Fotos de las promotoras con los clientes en el impulso o evento SHELL: |
| 16 | ¿Qué material de apoyo Qualid se utilizó? [UNIFORMES DE PROMOTORAS QUALID] |
| 17 | ¿Qué material de apoyo Qualid se utilizó? [BANDEROLAS QUALID] |
| 18 | ¿Qué material de apoyo Qualid se utilizó? [IGLOO QUALID] |
| 19 | ¿Qué material de apoyo Qualid se utilizó? [TOLDO QUALID] |
| 20 | Fotos del impulso o evento QUALID: |
| 21 | Fotos de las promotoras con los clientes en el impulso o evento QUALID: |
| 22 | Total de AMBIENTADORES SHELL PARA VEHÍCULO entregados: |
| 23 | Total de BOLSAS SHELL PARA CARRO entregadas: |
| 24 | Total de LLAVEROS DE TELA SHELL entregados: |
| 25 | Total de GORRA SHELL entregadas: |
| 26 | Total de BOLSAS TIPO BOUTIQUE NEGRO entregadas: |
| 27 | Total de BOLSAS TIPO BOUTIQUE BLANCO entregados: |
| 28 | Total de TAPASOL SHELL/QUALID entregados: |
| 29 | Total de GLOBOS SHELL entregados: |
| 30 | Total de VASOS SHELL entregados: |
| 31 | Total de AGENDAS entregadas: |
| 32 | Total de BOLSAS QUALID PARA CARRO entregadas: |
| 33 | Total de ESPONJAS QUALID entregadas: |
| 34 | Total de GLOBOS QUALID entregadas: |
| 35 | Total de GORRA QUALID entregadas: |
| 36 | Total de LLAVERO CAUCHO QUALID entregadas: |
| 37 | Total de LLAVEROS DE TELA QUALID entregadas: |
| 38 | Total de PAÑOS QUALID entregadas: |
| 39 | Total de VASOS QUALID (total ambos colores) entregadas: |
| 40 | ¿Se reportó venta de productos SHELL? |
| 41 | Total en litros de SHELL ADVANCE vendidos: |
| 42 | Total en litros de SHELL HELIX HX5 vendidos: |
| 43 | Total en litros de SHELL HELIX HX7 vendidos: |
| 44 | Total en litros de SHELL HELIX HX8 vendidos: |
| 45 | Total en litros de SHELL HELIX ULTRA vendidos: |
| 46 | Total en litros de SHELL RIMULA vendidos: |
| 47 | Total en litros de SHELL SPIRAX vendidos: |
| 48 | Total en cartuchos de SHELL GADUS vendidos: |
| 49 | Total en litros de OTROS vendidos: |
| 50 | ¿Se reportó venta de productos QUALID? |
| 51 | Total en litros de QUALID FLUIDOS vendidos: |
| 52 | Total en unidades de QUALID SPRAY vendido: |
| 53 | Total en unidades de QUALID FILTRO AUTOMOTRIZ vendidos: |
| 54 | Total en unidades de productos QUALID SERVICIO PESADO vendidos: |
| 55 | Total en unidades de CAUCHOS QUALID vendidos: |
| 56 | Añade aquí todos los detalles de producto faltante por familia de productos SHELL |
| 57 | Añade aquí todos los detalles de producto faltante por familia de productos QUALID |
| 58 | Añade aquí todos tus comentarios y observaciones adicionales |
| 59 | Desde que sucursal se realiza el registro: |
| 60 | Total de REVISTAS entregadas: |
| 61 | Total de BOLSAS TIPO BOUTIQUE VERTICAL  entregadas: |

## Ejemplo de fila (valores)

```
7/2/2026 17:20:32	luingi1924@gmail.com	Impulso	J506274108	ELECTRIC CARS SAN DIEGO C.A	0	0	Qualid	0	0	0	0	0	0	0	1	2	1	0	https://drive.google.com/open?id=1sSHTCE9v_RZS3jcVfr4Ytse6JCiQUzJF	https://drive.google.com/open?id=1oz8DhHRHjJ3VrgnshRB1gVKXFnmcZ3rO	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	No	0	0	0	0	0	0	0	0	0	No	0	0	0	0	0	0	0	0	Valencia	0	0
```

## Reglas de formato
- Fecha: `D/M/YYYY H:MM:SS` (sin cero a la izquierda)
- Valores vacíos: `0` (no null, no vacío)
- Booleanos: `Si` / `No`
- Fotos: URL de Google Drive o `0` si no hay foto
- Números: enteros sin formato
