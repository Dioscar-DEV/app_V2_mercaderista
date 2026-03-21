# Backlog de Mejoras - Disbattery Trade App

**Fecha de creacion:** 2026-03-20
**Ultima actualizacion:** 2026-03-20

---

## Prioridad ALTA

### 1. Permisos de Supervisor para Gestionar Rutas
**Solicitado por:** Operaciones
**Estado:** Pendiente
**Archivos involucrados:**
- `lib/core/enums/user_role.dart` (permisos actuales)
- `lib/presentation/screens/admin/routes/route_calendar_screen.dart`
- `lib/data/repositories/route_repository.dart`

**Descripcion:**
Los supervisores actualmente no pueden modificar rutas despues de crearlas. Se necesita que puedan:
- Cambiar la fecha programada de una ruta
- Cancelar rutas con motivo obligatorio (error de fecha, error de tipeo, duplicada, etc.)
- Editar clientes asignados a una ruta (agregar/quitar)
- Ver historial de cambios realizados

**Criterios de aceptacion:**
- [ ] Supervisor puede editar fecha de ruta en estado `planned`
- [ ] Supervisor puede cancelar ruta con campo de razon obligatorio
- [ ] Supervisor solo puede modificar rutas de su propia sede
- [ ] Owner puede modificar cualquier ruta
- [ ] Se registra quien hizo el cambio y cuando

---

### 2. Creacion de Sucursales y Arreglo de Vista de Visitas por Cliente
**Solicitado por:** Operaciones
**Estado:** Pendiente
**Archivos involucrados:**
- `lib/presentation/screens/clients/client_detail_screen.dart` (lineas 333-375)
- `lib/data/repositories/client_repository.dart`
- `lib/config/app_constants.dart` (lineas 71-100)

**Descripcion:**
Dos problemas relacionados:

**A) Sucursales desde clientes existentes:**
- Permitir agrupar/filtrar clientes por sucursal dentro de una sede
- Crear sucursales basandose en los clientes ya cargados en el sistema

**B) Vista de visitas en clientes especificos:**
- La pestaña "Visitas" en el detalle de cliente no muestra las visitas correctamente
- Actualmente muestra "Las visitas se registran desde el modulo de rutas" aunque existan visitas
- No hay filtros por fecha, tipo o mercaderista
- No se muestran fotos, notas ni detalles de cada visita
- Falta calculo de "dias desde ultima visita" (el modelo `diasDesdeUltimaVisita` existe pero no se usa en la UI)

**Criterios de aceptacion:**
- [ ] Visitas de un cliente se muestran con fecha, mercaderista y estado
- [ ] Se pueden expandir para ver fotos y respuestas del formulario
- [ ] Filtro por rango de fechas
- [ ] Estadisticas resumidas (total visitas, frecuencia promedio)

---

### 3. Mejora de Vista Web - Iconos de Modulos
**Solicitado por:** Operaciones
**Estado:** Pendiente
**Archivos involucrados:**
- `lib/presentation/screens/admin/admin_home_screen.dart`
- `lib/presentation/screens/mercaderista/home_screen.dart`

**Descripcion:**
En la version web (PWA), los bloques/cards de los modulos del dashboard se ven enormes y desproporcionados. No hay layout responsivo que adapte la grilla segun el ancho de pantalla.

**Solucion propuesta:**
- Implementar `LayoutBuilder` con breakpoints (600px, 900px, 1200px)
- En pantallas anchas (desktop/tablet): usar grid de 3-4 columnas
- En pantallas medianas: grid de 2 columnas
- En movil: mantener layout actual

**Criterios de aceptacion:**
- [ ] Dashboard se adapta a pantallas >1200px con 4 columnas
- [ ] Dashboard se adapta a pantallas >900px con 3 columnas
- [ ] Dashboard se adapta a pantallas >600px con 2 columnas
- [ ] Iconos y textos se escalan proporcionalmente
- [ ] Probado en Chrome, Safari y Edge

---

### 4. Pantalla de Perfil de Usuario
**Solicitado por:** Operaciones
**Estado:** Pendiente
**Archivos involucrados:**
- `lib/presentation/screens/admin/admin_home_screen.dart` (linea 109: `// TODO: Navegar a perfil`)
- `lib/presentation/screens/mercaderista/home_screen.dart` (linea 157: `// TODO: Navegar a perfil`)
- Crear: `lib/presentation/screens/profile/profile_screen.dart`

**Descripcion:**
El icono de usuario en la barra superior no hace nada. Se necesita una pantalla de perfil que al tocar el icono abra un panel/pantalla donde el usuario pueda:
- Ver su foto de perfil (y cargar/cambiar una nueva)
- Ver nombre, email, telefono
- Ver su rol (mercaderista, supervisor, owner) con informacion adaptada al rol
- Ver su sede y sucursal asignada
- Ver estadisticas basicas (rutas completadas, visitas realizadas, etc.)
- Cerrar sesion

**Variaciones por rol:**
- **Mercaderista:** ver rutas asignadas, visitas del mes, clientes frecuentes
- **Supervisor:** ver mercaderistas a cargo, rutas creadas, KPIs de su sede
- **Owner:** ver resumen global, acceso a configuracion avanzada

**Criterios de aceptacion:**
- [ ] Al tocar icono de usuario se abre pantalla de perfil
- [ ] Se puede cargar/cambiar foto de perfil (usar bucket `user-avatars` de Supabase)
- [ ] Datos mostrados varian segun el rol del usuario
- [ ] Boton de cerrar sesion funciona correctamente
- [ ] Funciona tanto en web como en movil

---

### 5. Correccion de Nombre "oceano_pacifico" en Reportes
**Solicitado por:** Operaciones
**Estado:** Pendiente
**Archivos involucrados:**
- `lib/data/services/external_client_api_service.dart` (lineas 116-134)
- `lib/core/enums/sede.dart`
- `lib/config/app_constants.dart` (lineas 71-100)
- `lib/presentation/screens/admin/reports/reports_dashboard_screen.dart`

**Descripcion:**
En el modulo de reportes y en varias partes de la app, aparece "oceano_pacifico" como nombre de sede cuando deberia decir **"Oriente"**. El problema de raiz es que hay 3 fuentes distintas de nombres de sedes:
1. Enum `Sede` en `sede.dart`
2. Mapa hardcodeado en `external_client_api_service.dart`
3. Constantes en `app_constants.dart`

**Solucion propuesta:**
- Unificar en una sola fuente de verdad (el enum `Sede`)
- Agregar metodo `displayName` al enum que retorne "Oriente" en lugar de "oceano_pacifico"
- Reemplazar todas las referencias hardcodeadas

**Criterios de aceptacion:**
- [ ] En reportes se muestra "Oriente" en vez de "oceano_pacifico"
- [ ] Una sola fuente de verdad para nombres de sedes
- [ ] Verificar en todas las pantallas que los nombres se muestran correctamente

---

### 6. APIificacion - Endpoints y Servicios
**Solicitado por:** Desarrollo
**Estado:** Pendiente
**Archivos involucrados:**
- `lib/data/services/external_client_api_service.dart`
- API externa en Railway: `https://apimercaderista-production.up.railway.app`

**Descripcion:**
Mejorar la integracion con APIs externas y crear endpoints propios (Edge Functions de Supabase) para:
- Sincronizacion automatizada de clientes desde el sistema administrativo
- Webhooks para notificaciones en tiempo real
- Endpoints para reportes y dashboards externos (BigQuery)
- API para integracion con otros sistemas de Grupo Disbattery

**Criterios de aceptacion:**
- [ ] Definir listado de endpoints necesarios
- [ ] Documentar API con OpenAPI/Swagger
- [ ] Implementar Edge Functions en Supabase para operaciones criticas
- [ ] Retry con backoff exponencial en llamadas a API externa
- [ ] Circuit breaker para APIs caidas

---

## Prioridad MEDIA

### 7. Sistema de Logging Estructurado
**Detectado por:** Revision de codigo
**Estado:** Pendiente
**Archivos involucrados:**
- `lib/main.dart` (lineas 29, 31)
- `lib/data/repositories/route_repository.dart` (lineas 855, 879, 930, 974, 998)
- `lib/data/repositories/client_repository.dart` (linea 397)
- `lib/data/repositories/offline_first_route_repository.dart` (lineas 63, 81)

**Descripcion:**
Hay `print()` y `debugPrint()` esparcidos por todo el codigo sin estructura. En produccion estos logs no ayudan y ensucian la consola.

**Solucion propuesta:**
- Reemplazar todos los `print()` con un logger estructurado
- Niveles: debug, info, warning, error
- En release: solo warning y error
- Considerar integracion con Sentry/Crashlytics para errores en produccion

---

### 8. Mejora de Sincronizacion Offline
**Detectado por:** Revision de codigo
**Estado:** Pendiente
**Archivos involucrados:**
- `lib/data/repositories/offline_first_route_repository.dart`
- `lib/data/local/route_offline_sync_service.dart`
- `lib/data/repositories/route_repository.dart` (lineas 841-879)

**Descripcion:**
Problemas detectados:
- **Fotos en web:** Los blob URLs expiran al cerrar la pestana, pudiendo perder fotos
- **Sin limpieza automatica:** Los registros pendientes de sync nunca se purgan, la DB local crece indefinidamente
- **Sin reintentos inteligentes:** Si falla un sync, no hay backoff exponencial
- **Sin resolucion de conflictos:** Si dos personas editan lo mismo offline, no hay estrategia definida

**Criterios de aceptacion:**
- [ ] Fotos en web se suben inmediatamente (no depender de blob URLs)
- [ ] Limpieza automatica de pendientes >30 dias
- [ ] Reintentos con backoff exponencial (1s, 2s, 4s, 8s...)
- [ ] Indicador visual del estado de sync en la app

---

### 9. Manejo de Errores y UX de Carga
**Detectado por:** Revision de codigo
**Estado:** Pendiente
**Archivos involucrados:**
- `lib/data/services/external_client_api_service.dart` (lineas 84-104)
- `lib/presentation/screens/clients/client_detail_screen.dart`
- `lib/presentation/screens/admin/reports/`

**Descripcion:**
- Errores de API se tragan silenciosamente (`catch (e) { print(e); }`)
- No hay reintentos en llamadas a API externa
- Timeouts fijos de 30 segundos sin adaptacion
- Loading states genericos (solo `CircularProgressIndicator`), sin skeleton loaders
- Mensajes de error poco informativos para el usuario

**Criterios de aceptacion:**
- [ ] Errores de red muestran mensaje amigable al usuario con opcion de reintentar
- [ ] Skeleton loaders en listas y cards mientras cargan datos
- [ ] Timeouts progresivos en reintentos
- [ ] Mensajes de estado vacio mas claros y con accion sugerida

---

### 10. Integracion con Google Maps
**Detectado por:** Revision de codigo
**Estado:** Pendiente
**Archivos involucrados:**
- `lib/config/app_constants.dart` (linea 8: `// TODO: Configurar cuando se necesite usar Google Maps`)

**Descripcion:**
La app captura coordenadas GPS de visitas pero no muestra mapa. Se podria:
- Mostrar ubicacion del cliente en un mapa
- Visualizar ruta del dia en mapa con puntos de visita
- Mostrar mapa de cobertura para supervisores

---

## Prioridad BAJA

### 11. Soporte de Localizacion / Idiomas
**Detectado por:** Revision de codigo (`lib/app.dart` linea 25: `// TODO: Agregar soporte de localizacion`)
**Estado:** Pendiente
**Descripcion:** Preparar la app para multiples idiomas si se expande a otros paises.

### 12. Auditoria de Acciones de Supervisor
**Estado:** Pendiente
**Descripcion:** Registrar todas las acciones administrativas (crear rutas, cancelar, cambiar fechas, asignar mercaderistas) en un log de auditoria para trazabilidad.

### 13. Analytics y Metricas de Uso
**Estado:** Pendiente
**Descripcion:** Integrar Firebase Analytics o similar para medir uso real de la app, pantallas mas visitadas, tiempos de sesion, etc.

---

## Resumen

| # | Mejora | Prioridad | Origen |
|---|--------|-----------|--------|
| 1 | Permisos supervisor para gestionar rutas | ALTA | Operaciones |
| 2 | Sucursales + arreglo vista visitas | ALTA | Operaciones |
| 3 | Layout responsivo web (iconos modulos) | ALTA | Operaciones |
| 4 | Pantalla de perfil de usuario | ALTA | Operaciones |
| 5 | Correccion nombre "oceano_pacifico" -> "Oriente" | ALTA | Operaciones |
| 6 | APIificacion | ALTA | Desarrollo |
| 7 | Logging estructurado | MEDIA | Revision de codigo |
| 8 | Mejora sync offline | MEDIA | Revision de codigo |
| 9 | Manejo de errores y UX de carga | MEDIA | Revision de codigo |
| 10 | Google Maps | MEDIA | Revision de codigo |
| 11 | Localizacion | BAJA | Revision de codigo |
| 12 | Auditoria de acciones | BAJA | Revision de codigo |
| 13 | Analytics de uso | BAJA | Revision de codigo |
