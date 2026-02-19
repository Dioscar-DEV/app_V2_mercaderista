# Changelog - Disbattery Trade

Formato: [Semantic Versioning](https://semver.org/) `MAJOR.MINOR.PATCH+BUILD`
- **MAJOR**: Cambios que rompen compatibilidad
- **MINOR**: Nueva funcionalidad (backwards compatible)
- **PATCH**: Correcciones de bugs
- **BUILD** (+N): Numero incremental por cada APK/deploy

---

## [1.2.2+5] - 2026-02-19

### Correcciones criticas (bugs offline)
- **Fotos sobreviven bloqueo del telefono**: Las fotos comprimidas ahora se guardan en el directorio permanente de documentos en vez de la carpeta temporal. Android ya no puede borrarlas cuando la app pasa a segundo plano
- **Visitas completadas no vuelven a "pendiente"**: Se corrigio una race condition donde al recuperar conexion, Supabase sobreescribia el estado local con datos obsoletos antes de que el sync local terminara de subir los completados
- **Visitas persisten si la app es matada**: Las visitas con formulario completo ahora se guardan en SQLite inmediatamente, no solo en memoria. Si Android mata la app, se restauran al reabrir la ruta

---

## [1.2.1+4] - 2026-02-19

### Nuevas funcionalidades
- **Identificador visual de Sucursales**: Los clientes con sufijo (ej: B04352-1) ahora muestran un chip azul "Sucursal" en el selector de clientes y en la tarjeta de ejecucion de ruta
- **Agrupamiento de sucursales en selector**: La lista de clientes ahora ordena las sucursales adyacentes a su sede principal (por codigo base)
- **Detalle de sucursal en ejecucion**: Al expandir un cliente sucursal, se muestra "Sucursal #N · Base: CXXXXX" con icono de arbol

### Correcciones
- **Direcciones de sucursales correctas**: En el proximo sync (importacion desde API), las sucursales usaran dir_ent2 como direccion principal en vez de copiar la de la sede principal
- Las 166 sucursales ya corregidas en Supabase con el UPDATE previo mantienen sus direcciones correctas

---

## [1.2.0+3] - 2026-02-19

### Nuevas funcionalidades
- **Nombre completo y RIF en tarjeta de cliente**: Al expandir un cliente en la ejecucion de ruta, ahora se muestra el nombre completo (sin truncar) y el RIF
- **Nombre visible en 2 lineas**: El nombre del cliente en la lista ahora muestra hasta 2 lineas en vez de 1
- **Fotos de planograma y afiche Qualid en Merchandising**: Se agregaron 2 nuevas preguntas obligatorias al inicio de la seccion Qualid: "Foto actual planograma Qualid" y "Foto afiche principal Qualid"

### Cambios
- **Oceano Pacifico renombrado a Dislub Oriente**: Se actualizo el nombre de la sede en toda la aplicacion
- **Version dinamica en login**: La version en la pantalla de login ahora se lee automaticamente del pubspec.yaml (package_info_plus)

### Correcciones de datos
- Clientes CLI01465 y CLI01471 reasignados de grupo_disbattery a grupo_victoria
- Cliente CLI01493 insertado en grupo_victoria (no existia en Supabase)

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
- Sistema de sedes (Grupo Disbattery, Dislub Oriente, Blitz 2000, Grupo Victoria)
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
