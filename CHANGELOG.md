# Changelog - Disbattery Trade

Formato: [Semantic Versioning](https://semver.org/) `MAJOR.MINOR.PATCH+BUILD`
- **MAJOR**: Cambios que rompen compatibilidad
- **MINOR**: Nueva funcionalidad (backwards compatible)
- **PATCH**: Correcciones de bugs
- **BUILD** (+N): Numero incremental por cada APK/deploy

---

## [1.1.0+2] - 2026-02-18

### Nuevas funcionalidades
- **Visibilidad global de rutas para Owner/Admin Master**: Los usuarios con rol `owner` ahora pueden ver rutas de todas las sedes sin restriccion
- **Filtros avanzados en Gestion de Rutas**: Bottom sheet con filtros por sede, estado, mercaderista y tipo de ruta. Chips removibles para filtros activos
- **Seleccion de marca en rutas Impulso (Supervisor)**: Al crear una ruta de tipo Impulso, el supervisor/owner puede configurar las marcas disponibles: Ambas, Solo Shell, o Solo Qualid
- **Multi-marca en formulario Impulso (Mercaderista)**: El mercaderista puede seleccionar multiples marcas (Shell y/o Qualid) con checkboxes, viendo las preguntas condicionales de todas las marcas seleccionadas

### Correcciones
- **RLS policies para rol Owner**: Se agrego el rol `owner` a todas las politicas RLS de `routes`, `route_clients` y `route_visits` que solo incluian `admin`, `super_admin` y `supervisor`

### Cambios tecnicos
- Columna `brands` (jsonb) agregada a tabla `routes` en Supabase
- SQLite local migrado de v5 a v6 (columna `brands_json`)
- Modelo `AppRoute` actualizado con campo `brands` y getter `availableBrands`

---

## [1.0.0+1] - 2026-02-xx (Produccion inicial)

### Funcionalidades base
- Autenticacion con Supabase Auth (login/registro)
- Gestion de usuarios por roles (Owner, Supervisor, Mercaderista)
- Sistema de sedes (Grupo Disbattery, Oceano Pacifico, Blitz 2000, Grupo Victoria)
- Calendario semanal de rutas
- Creacion de rutas manual y desde plantillas
- Ejecucion de rutas con GPS tracking
- Formularios por tipo de ruta: Merchandising, Impulso, Evento
- Preguntas condicionales con dependencias
- Captura de fotos (galeria y camara)
- Modo offline con SQLite y sincronizacion
- Reportes y exportacion CSV
- Notificaciones push
- Gestion de eventos con check-in
- PWA web + APK Android
