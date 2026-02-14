# Disbattery Trade - App Mercaderista V2

Aplicacion movil para la gestion de rutas y visitas de mercaderistas de **Grupo Disbattery**. Permite a los mercaderistas ejecutar sus rutas diarias, visitar clientes, llenar formularios dinamicos, capturar fotos y trabajar completamente **offline** con sincronizacion automatica cuando vuelve la conexion.

---

## Tabla de Contenido

1. [Que es esta app](#que-es-esta-app)
2. [Tecnologias utilizadas](#tecnologias-utilizadas)
3. [Como funciona Flutter](#como-funciona-flutter)
4. [Arquitectura del proyecto](#arquitectura-del-proyecto)
5. [Estructura de carpetas](#estructura-de-carpetas)
6. [Base de datos - Supabase](#base-de-datos---supabase)
7. [Base de datos local - SQLite](#base-de-datos-local---sqlite)
8. [Como funciona el modo offline](#como-funciona-el-modo-offline)
9. [Flujo de la aplicacion](#flujo-de-la-aplicacion)
10. [Pantallas principales](#pantallas-principales)
11. [Modelos de datos](#modelos-de-datos)
12. [Gestion de estado con Riverpod](#gestion-de-estado-con-riverpod)
13. [GPS y permisos](#gps-y-permisos)
14. [Captura de fotos](#captura-de-fotos)
15. [Configuracion y despliegue](#configuracion-y-despliegue)
16. [Dependencias principales](#dependencias-principales)

---

## Que es esta app

Disbattery Trade es una herramienta de campo para **mercaderistas** (vendedores/promotores que visitan tiendas y clientes). La app les permite:

- **Ver sus rutas del dia**: que clientes tienen asignados para visitar
- **Ejecutar visitas**: iniciar visita, llenar un formulario con preguntas configurables, tomar fotos, y completar
- **Trabajar sin internet**: toda la informacion se guarda localmente y se sincroniza despues
- **Marcar estados**: completar visita, omitir cliente, marcar como cerrado (temporal o permanente)
- **Capturar ubicacion GPS**: registra donde inicio y termino cada visita
- **Panel administrativo**: los supervisores pueden crear rutas, asignar mercaderistas y ver reportes

### Ejemplo de uso tipico

```
1. El mercaderista abre la app en la manana
2. Ve su ruta del dia con 8 clientes asignados
3. Llega al primer cliente, presiona "Iniciar Visita" (se captura GPS)
4. Llena el formulario (preguntas sobre exhibicion, stock, etc.)
5. Toma fotos de la exhibicion
6. Presiona "Completar Visita" (se captura GPS de salida)
7. Si un cliente esta cerrado, lo marca como "Cerrado Temporal"
8. Al terminar todos los clientes, completa la ruta
9. Si perdio internet durante el recorrido, al volver la conexion
   la app sincroniza todo automaticamente
```

---

## Tecnologias utilizadas

| Tecnologia | Que es | Para que se usa aqui |
|---|---|---|
| **Flutter** | Framework de Google para apps moviles | Construir toda la interfaz y logica de la app |
| **Dart** | Lenguaje de programacion de Flutter | Codigo de toda la app |
| **Supabase** | Backend como servicio (base de datos + auth + storage) | Guardar datos en la nube, autenticacion, almacenar fotos |
| **SQLite** | Base de datos local del telefono | Guardar datos offline en el dispositivo |
| **Riverpod** | Gestor de estado para Flutter | Manejar el estado de la app (datos, carga, errores) |
| **GoRouter** | Navegacion declarativa para Flutter | Manejar las pantallas y rutas de navegacion |

---

## Como funciona Flutter

Flutter es un framework de **Google** que permite crear aplicaciones moviles (Android e iOS) con un solo codigo. En lugar de escribir Java/Kotlin para Android y Swift para iOS por separado, escribes todo una sola vez en **Dart** y Flutter lo compila para ambas plataformas.

### Conceptos clave de Flutter

**Widgets**: Todo en Flutter es un "widget" (componente visual). Un boton es un widget, un texto es un widget, una pantalla completa es un widget. Los widgets se anidan como un arbol:

```
Scaffold (estructura de la pantalla)
  +-- Column (columna vertical)
       +-- AppBar (barra superior)
       +-- Text("Hola") (texto)
       +-- ElevatedButton (boton)
```

**StatelessWidget vs StatefulWidget**:
- `StatelessWidget`: No cambia. Ejemplo: un texto fijo, un icono
- `StatefulWidget`: Puede cambiar. Ejemplo: un contador, un formulario con campos editables

**ConsumerWidget / ConsumerStatefulWidget**: Son widgets especiales de **Riverpod** que pueden "escuchar" datos de los providers. Los usamos en toda la app para acceder al estado global.

### Ejemplo real de la app

```dart
// Un widget simple que muestra el nombre de un cliente
class ClientCard extends StatelessWidget {
  final String name;
  final String address;

  const ClientCard({required this.name, required this.address});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(name),       // Nombre del cliente
        subtitle: Text(address), // Direccion
        leading: Icon(Icons.store), // Icono de tienda
      ),
    );
  }
}
```

**Hot Reload**: Mientras desarrollas, puedes cambiar el codigo y ver los cambios al instante sin reiniciar la app. Esto hace el desarrollo muy rapido.

---

## Arquitectura del proyecto

La app sigue una arquitectura por **capas** (Clean Architecture simplificada). Cada capa tiene una responsabilidad clara:

```
+------------------------------------------+
|          PRESENTACION (UI)               |  <-- Lo que ve el usuario
|   Screens + Widgets + Providers          |
+------------------------------------------+
|          DATOS (Data Layer)              |  <-- Obtener y guardar datos
|   Repositories + Services + Local DB     |
+------------------------------------------+
|          NUCLEO (Core)                   |  <-- Modelos y reglas
|   Models + Enums + Constants             |
+------------------------------------------+
```

### Por que esta separacion?

- **Presentacion**: Si cambias el diseno de una pantalla, no tocas la logica de datos
- **Datos**: Si cambias de Supabase a Firebase, solo tocas los repositorios
- **Nucleo**: Los modelos son independientes, no saben de donde vienen los datos

### Flujo de datos (ejemplo: cargar rutas del dia)

```
1. Pantalla (home_screen.dart)
   -> Pide datos al Provider

2. Provider (route_provider.dart)
   -> Pide datos al Repositorio

3. Repositorio (offline_first_route_repository.dart)
   -> Primero busca en SQLite local
   -> Si no hay, busca en Supabase (internet)
   -> Guarda copia local de lo que recibe

4. Los datos fluyen de vuelta:
   Repositorio -> Provider -> Pantalla -> Se muestra al usuario
```

---

## Estructura de carpetas

```
lib/
+-- main.dart                    # Punto de entrada de la app
+-- app.dart                     # Widget raiz de la app
|
+-- config/                      # Configuracion global
|   +-- app_constants.dart       # Constantes (timeouts, URLs)
|   +-- supabase_config.dart     # Conexion a Supabase + Storage
|   +-- theme_config.dart        # Colores, tipografia, estilos
|
+-- core/                        # Nucleo de la app
|   +-- enums/                   # Valores fijos
|   |   +-- route_status.dart    # planned, in_progress, completed...
|   |   +-- sede.dart            # grupo_disbattery, qualid...
|   |   +-- user_role.dart       # admin, supervisor, mercaderista
|   |   +-- user_status.dart     # active, inactive, suspended
|   |   +-- visit_type.dart      # regular, emergency, audit...
|   |
|   +-- models/                  # Modelos de datos
|       +-- client.dart          # Cliente (tienda/negocio)
|       +-- route.dart           # Ruta + RouteClient
|       +-- route_form_question.dart  # Preguntas del formulario
|       +-- route_template.dart  # Plantillas de rutas
|       +-- route_type.dart      # Tipos de ruta
|       +-- route_visit.dart     # Visita + Respuestas
|       +-- user.dart            # Usuario de la app
|
+-- data/                        # Capa de datos
|   +-- local/                   # Almacenamiento local
|   |   +-- database_service.dart          # SQLite (base de datos del telefono)
|   |   +-- route_local_storage.dart       # SharedPreferences (datos simples)
|   |   +-- route_offline_sync_service.dart # Servicio de sincronizacion
|   |
|   +-- repositories/            # Repositorios (acceso a datos)
|   |   +-- auth_repository.dart           # Login/logout con Supabase Auth
|   |   +-- client_repository.dart         # CRUD de clientes
|   |   +-- offline_first_route_repository.dart  # Rutas con soporte offline
|   |   +-- route_repository.dart          # Rutas directo a Supabase
|   |   +-- user_repository.dart           # CRUD de usuarios
|   |
|   +-- services/                # Servicios externos
|       +-- external_client_api_service.dart  # API externa de clientes
|       +-- location_service.dart            # GPS y permisos de ubicacion
|
+-- presentation/                # Capa visual
|   +-- providers/               # Estado de la app (Riverpod)
|   |   +-- auth_provider.dart   # Estado de autenticacion
|   |   +-- client_provider.dart # Estado de clientes
|   |   +-- route_provider.dart  # Estado de rutas (el mas complejo)
|   |   +-- user_provider.dart   # Estado de usuarios
|   |
|   +-- screens/                 # Pantallas
|   |   +-- auth/                # Login, registro
|   |   +-- admin/               # Panel admin/supervisor
|   |   +-- clients/             # Lista y detalle de clientes
|   |   +-- mercaderista/        # Home del mercaderista
|   |   +-- routes/              # Ejecucion de rutas
|   |   +-- splash/              # Pantalla de carga inicial
|   |
|   +-- widgets/                 # Componentes reutilizables
|       +-- route_visit_form.dart  # Formulario de visita con fotos
|       +-- common/              # Widgets genericos
|
+-- routes/                      # Navegacion
|   +-- app_router.dart          # Definicion de todas las rutas
|
+-- utils/                       # Utilidades generales
```

### Que archivo hace que?

| Archivo | Responsabilidad |
|---|---|
| `main.dart` | Inicia Supabase, configura orientacion, lanza la app |
| `supabase_config.dart` | URL y claves de Supabase, subida de fotos a Storage |
| `theme_config.dart` | Color rojo Disbattery (#DC143C), estilos Material 3 |
| `database_service.dart` | Crea y maneja la base SQLite local (tablas, queries) |
| `offline_first_route_repository.dart` | Decide si leer de local o servidor |
| `route_provider.dart` | Maneja todo el estado de ejecucion de rutas |
| `route_execution_screen.dart` | Pantalla principal donde el mercaderista trabaja |
| `route_visit_form.dart` | Formulario dinamico con preguntas y captura de fotos |
| `location_service.dart` | Pide permisos GPS, obtiene coordenadas |

---

## Base de datos - Supabase

**Supabase** es como un "Firebase de codigo abierto". Nos da:

1. **Base de datos PostgreSQL**: Donde se guardan todos los datos en la nube
2. **Autenticacion**: Login con email/password
3. **Storage**: Almacen de archivos (fotos de visitas)
4. **Row Level Security (RLS)**: Cada mercaderista solo ve sus propios datos

### Tablas principales en Supabase

```
+--------------------------------------------------------------+
|                    TABLAS DE SUPABASE                         |
+--------------------------------------------------------------+
|                                                               |
|  users                    Usuarios de la app                  |
|  +-- id (uuid)            ID unico                            |
|  +-- email                Correo electronico                  |
|  +-- role                 admin/supervisor/mercaderista        |
|  +-- sede_app             Sede asignada                       |
|                                                               |
|  clients                  Clientes/tiendas                    |
|  +-- co_cli (PK)          Codigo unico del cliente            |
|  +-- cli_des              Nombre del cliente                  |
|  +-- direc1               Direccion                           |
|  +-- telefonos            Telefonos                           |
|                                                               |
|  routes                   Rutas planificadas                  |
|  +-- id (uuid)            ID unico                            |
|  +-- mercaderista_id      Quien ejecuta la ruta               |
|  +-- scheduled_date       Fecha programada                    |
|  +-- status               planned/in_progress/completed       |
|  +-- total_clients        Cuantos clientes tiene              |
|                                                               |
|  route_clients            Clientes dentro de una ruta         |
|  +-- id (uuid)            ID unico                            |
|  +-- route_id             A que ruta pertenece                |
|  +-- client_co_cli        Que cliente es                      |
|  +-- status               pending/completed/skipped/closed    |
|  +-- closure_reason       Motivo de cierre (si aplica)        |
|  +-- order_number         Orden de visita                     |
|                                                               |
|  route_visits             Registro de cada visita realizada   |
|  +-- id (uuid)            ID unico                            |
|  +-- route_client_id      A que cliente de ruta pertenece     |
|  +-- mercaderista_id      Quien hizo la visita                |
|  +-- visited_at           Fecha/hora de la visita             |
|  +-- latitude/longitude   Coordenadas GPS                     |
|  +-- photos (jsonb)       Lista de URLs de fotos              |
|  +-- notes                Observaciones                       |
|                                                               |
|  route_visit_answers      Respuestas al formulario            |
|  +-- visit_id             A que visita pertenece              |
|  +-- question_id          Que pregunta responde               |
|  +-- answer_text          Respuesta de texto                  |
|  +-- answer_number        Respuesta numerica                  |
|  +-- answer_boolean       Respuesta si/no                     |
|  +-- answer_json          Opciones multiples, fotos           |
|                                                               |
|  route_form_questions     Preguntas del formulario            |
|  +-- route_type_id        Para que tipo de ruta               |
|  +-- question_text        Texto de la pregunta                |
|  +-- question_type        text/number/boolean/select/photo    |
|  +-- options              Opciones (para seleccion)           |
|                                                               |
|  route_types              Tipos de ruta                       |
|  +-- name                 Nombre (Merchandising, Cobranza)    |
|  +-- color                Color para la UI                    |
|                                                               |
|  route_templates          Plantillas reutilizables            |
|  +-- name                 Nombre de la plantilla              |
|  +-- client_ids           Clientes incluidos                  |
|                                                               |
+--------------------------------------------------------------+
```

### Supabase Storage (Almacenamiento de fotos)

Las fotos que toma el mercaderista se suben a **Supabase Storage** en el bucket `visit-photos`. La estructura de archivos es:

```
visit-photos/
  +-- {user_id}/                    # Carpeta por mercaderista
       +-- visit_20260214_1.jpg     # Foto 1 de una visita
       +-- visit_20260214_2.jpg     # Foto 2
       +-- ...
```

Las fotos se comprimen antes de subirlas (calidad 70%, maximo 800px de ancho) para ahorrar datos moviles.

### Row Level Security (RLS)

Supabase tiene reglas de seguridad que aseguran que:
- Un mercaderista solo puede **insertar** visitas con su propio `mercaderista_id`
- Un mercaderista solo puede **subir** fotos a su propia carpeta (`auth.uid()`)
- Un mercaderista solo puede **ver** sus propias rutas

---

## Base de datos local - SQLite

**SQLite** es una base de datos que vive dentro del telefono. No necesita internet ni un servidor. Es como un archivo `.db` que guarda tablas igual que PostgreSQL pero localmente.

### Por que usamos SQLite?

Porque el mercaderista puede estar en zonas sin senal (sotanos, zonas rurales, etc.) y necesita seguir trabajando. SQLite guarda todo localmente y cuando vuelve la conexion, se sincroniza con Supabase.

### Tablas locales en SQLite

```sql
-- Rutas descargadas para uso offline
CREATE TABLE routes (
    id TEXT PRIMARY KEY,
    mercaderista_id TEXT,
    name TEXT,
    scheduled_date TEXT,
    status TEXT,            -- planned, in_progress, completed
    total_clients INTEGER,
    completed_clients INTEGER,
    is_synced INTEGER       -- 0 = pendiente, 1 = sincronizado
);

-- Clientes de cada ruta (con nombre guardado localmente)
CREATE TABLE route_clients (
    id TEXT PRIMARY KEY,
    route_id TEXT,
    client_co_cli TEXT,
    status TEXT,            -- pending, completed, skipped, closed_temp
    client_name TEXT,       -- Nombre guardado para mostrar offline
    client_address TEXT,    -- Direccion guardada para mostrar offline
    closure_reason TEXT,    -- Motivo de cierre temporal
    is_synced INTEGER       -- 0 = pendiente, 1 = sincronizado
);

-- Operaciones pendientes de sincronizar
CREATE TABLE pending_sync (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    table_name TEXT,        -- Que tabla afecta
    record_id TEXT,         -- Que registro
    operation TEXT,         -- Que operacion (start_route, complete_route, etc.)
    data_json TEXT          -- Datos en JSON
);

-- Preguntas del formulario (descargadas para offline)
CREATE TABLE route_form_questions (
    id TEXT PRIMARY KEY,
    route_type_id TEXT,
    question_text TEXT,
    question_type TEXT,
    options_json TEXT,
    is_required INTEGER
);
```

### Versiones de la base de datos (Migraciones)

La base de datos ha tenido 3 versiones (migraciones). Cada vez que se agrega algo nuevo, se sube la version y SQLite ejecuta la migracion automaticamente sin perder datos:

| Version | Que se agrego |
|---|---|
| v1 | Tablas base: routes, route_clients, pending_visits, pending_sync |
| v2 | Tabla route_form_questions (preguntas del formulario offline) |
| v3 | Columna `closure_reason` en route_clients (motivo de cierre) |

Ejemplo de como funciona una migracion:

```dart
// En database_service.dart
Future<void> _upgradeDb(Database db, int oldVersion, int newVersion) async {
    // Si el telefono tiene la version 2, solo ejecuta lo nuevo (v3)
    if (oldVersion < 3) {
      await db.execute(
        'ALTER TABLE route_clients ADD COLUMN closure_reason TEXT'
      );
    }
}
```

---

## Como funciona el modo offline

El modo offline es una de las caracteristicas mas importantes de la app. Funciona con un patron llamado **Offline-First** que significa: "primero local, despues internet".

### Diagrama del flujo offline

```
  USUARIO HACE UNA ACCION
         |
         v
  +-------------------+
  |  Guardar en        |  <-- SIEMPRE se guarda localmente
  |  SQLite local      |     primero (es instantaneo)
  +--------+----------+
           |
           v
  +-------------------+     +----------------+
  |  Hay internet?    |--SI-|  Enviar a      |
  |                   |     |  Supabase      |
  +--------+----------+     +--------+-------+
           |                         |
          NO                      EXITO?
           |                    /       \
           v                  SI         NO
  +-------------------+       |          |
  |  Marcar como       |       v          v
  |  "pendiente de     |  +---------+ +---------+
  |  sincronizar"      |  | Marcar  | | Dejar   |
  |  (is_synced = 0)   |  | synced  | | pending |
  +-------------------+  +---------+ +---------+

  CUANDO VUELVE LA CONEXION:
  +-------------------+
  |  Buscar todos      |
  |  los registros     |-->  Enviar uno por uno a Supabase
  |  con is_synced=0   |
  +-------------------+
```

### Ejemplo concreto: completar visita sin internet

```
1. Mercaderista presiona "Completar Visita"

2. La app hace esto internamente:
   a) Guarda en SQLite: route_client.status = 'completed', is_synced = 0
   b) Guarda la visita con respuestas en pendingVisits (SharedPreferences)
   c) Intenta enviar a Supabase -> FALLA (no hay internet)
   d) La visita queda pendiente

3. Mas tarde el mercaderista activa WiFi

4. La app detecta conexion automaticamente:
   a) Busca route_clients con is_synced = 0
   b) Busca visitas pendientes en SharedPreferences
   c) Envia todo a Supabase uno por uno
   d) Marca como sincronizado (is_synced = 1)
   e) Muestra notificacion "Visitas sincronizadas"
```

### Que se sincroniza offline?

| Accion | Se guarda offline? | Se sincroniza despues? |
|---|---|---|
| Iniciar ruta | Si (SQLite) | Si |
| Completar ruta | Si (SQLite) | Si |
| Iniciar visita | Si (SQLite) | Si |
| Completar visita + formulario | Si (SQLite + SharedPreferences) | Si |
| Omitir cliente (skip) | Si (SQLite) | Si |
| Marcar cerrado temporal | Si (SQLite con motivo) | Si |
| Tomar fotos | Se guardan localmente como archivo | Se suben cuando hay internet |

### Dos sistemas de almacenamiento local

La app usa **dos** sistemas complementarios:

1. **SQLite** (`database_service.dart`): Para datos estructurados que necesitan queries (rutas, clientes, estados). Es la base de datos "seria".

2. **SharedPreferences** (`route_local_storage.dart`): Para datos temporales mas simples (visitas pendientes de sincronizar, preguntas de formulario cacheadas). Es como un diccionario clave-valor.

---

## Flujo de la aplicacion

### Flujo completo desde abrir la app

```
+----------+     +----------+     +--------------+
|  Splash  |---->|  Login   |---->|  Home Screen  |
|  Screen  |     |  Screen  |     |  (segun rol)  |
+----------+     +----------+     +------+-------+
                                         |
                        +----------------+----------------+
                        |                |                |
                        v                v                v
                  +-----------+   +-----------+   +-----------+
                  |   Admin   |   | Supervisor|   |Mercaderist|
                  |   Home    |   |   Home    |   |   Home    |
                  +-----+-----+   +-----------+   +-----+-----+
                        |                               |
              +---------+---------+                     |
              |         |         |                     v
         +--------+ +------+ +------+         +--------------+
         |Usuarios| |Rutas | |Client|         | Rutas del dia|
         |        | |Calend| |es    |         | (cards)      |
         +--------+ +---+--+ +------+         +------+-------+
                        |                            |
                        v                            v
                  +-----------+            +------------------+
                  |  Crear/   |            |  Route Execution  |
                  |  Editar   |            |  Screen           |
                  |  Ruta     |            |  (lista clientes) |
                  +-----------+            +--------+---------+
                                                    |
                                           +--------+--------+
                                           |        |        |
                                           v        v        v
                                      +--------++-------++-------+
                                      |Iniciar ||Omitir ||Cerrado|
                                      |Visita  ||Cliente||Temp   |
                                      +---+----++-------++-------+
                                          |
                                          v
                                    +-----------+
                                    |Formulario |
                                    |+ Fotos    |
                                    |+ GPS      |
                                    +---+-------+
                                        |
                                        v
                                   +----------+
                                   |Completar |
                                   |Visita    |
                                   +----------+
```

### Roles de usuario

| Rol | Que puede hacer |
|---|---|
| **Admin** | Todo: crear usuarios, rutas, ver todos los datos de todas las sedes |
| **Supervisor** | Crear rutas, asignar mercaderistas, ver datos de su sede |
| **Mercaderista** | Solo ejecutar sus rutas asignadas, ver sus propios datos |

---

## Pantallas principales

### 1. Login Screen (`login_screen.dart`)
Inicio de sesion con email y password usando Supabase Auth. Detecta el rol del usuario y lo redirige a su home correspondiente.

### 2. Mercaderista Home Screen (`mercaderista/home_screen.dart`)
Muestra las rutas del dia como tarjetas (cards). Cada tarjeta muestra:
- Nombre de la ruta
- Tipo de ruta (con color)
- Desglose de clientes: completados, pendientes, cerrados, omitidos
- Estado general (planificada, en progreso, completada)
- Indicador de modo offline si no hay conexion

Al abrir esta pantalla, la app automaticamente descarga las rutas del servidor y las guarda en SQLite para tenerlas disponibles offline.

### 3. Route Execution Screen (`routes/route_execution_screen.dart`)
Es la pantalla principal de trabajo del mercaderista. Muestra:
- **Lista de clientes** de la ruta con su estado (badges de colores)
- **Cliente seleccionado** con detalle expandido
- **Botones de accion**: Iniciar Visita, Omitir, Cerrado Temporal, Cerrado Permanente
- **Formulario de visita** (inline, se expande al iniciar visita)
- **Indicador GPS** (activo/inactivo)
- **Boton de sincronizacion** cuando hay datos pendientes
- **Menu**: Completar ruta, Cancelar ruta, Convertir a plantilla

### 4. Route Visit Form (`widgets/route_visit_form.dart`)
Formulario dinamico que se construye automaticamente segun las preguntas configuradas para el tipo de ruta. Soporta:
- Texto libre
- Numeros
- Si/No (booleano)
- Seleccion unica (radio buttons)
- Seleccion multiple (checkboxes)
- Captura de fotos (camara o galeria)
- Campo de observaciones

### 5. Admin Home Screen (`admin/admin_home_screen.dart`)
Panel de control para administradores con acceso a:
- Gestion de usuarios
- Calendario de rutas
- Lista de clientes
- Reportes y estadisticas

### 6. Route Calendar Screen (`routes/route_calendar_screen.dart`)
Calendario semanal donde se ven las rutas planificadas. Permite crear nuevas rutas y ver el estado de las existentes.

---

## Modelos de datos

Los modelos son clases Dart que representan los datos de la app. Cada modelo tiene metodos para convertir entre JSON (lo que envia/recibe Supabase) y objetos Dart.

### AppRoute (`route.dart`)
```dart
class AppRoute {
  final String id;
  final String mercaderistaId;
  final String name;               // "Ruta Centro Caracas"
  final DateTime scheduledDate;     // 2026-02-14
  final RouteStatus status;         // planned, in_progress, completed
  final int totalClients;           // 8
  final int completedClients;       // 5
  final List<RouteClient>? clients; // Lista de clientes en la ruta
}
```

### RouteClient (`route.dart`)
```dart
class RouteClient {
  final String id;
  final String routeId;
  final String clientId;           // Codigo del cliente (co_cli)
  final int orderNumber;           // Orden de visita (1, 2, 3...)
  final RouteClientStatus status;  // pending, in_progress, completed, skipped, closed_temp
  final String? closureReason;     // "Cerrado por remodelacion"
  final Client? client;            // Datos del cliente (nombre, direccion)
}
```

### RouteVisit (`route_visit.dart`)
```dart
class RouteVisit {
  final String routeClientId;
  final String? routeId;
  final String? mercaderistaId;
  final DateTime visitedAt;
  final double? latitude;
  final double? longitude;
  final List<String>? photos;       // URLs de fotos en Storage
  final String? notes;              // Observaciones del mercaderista
  final List<RouteVisitAnswer>? answers;  // Respuestas al formulario
}
```

### RouteVisitAnswer (`route_visit.dart`)
```dart
class RouteVisitAnswer {
  final String routeVisitId;       // A que visita pertenece
  final String questionId;         // Que pregunta responde
  final String? answerText;        // "Todo en orden"
  final double? answerNumber;      // 42.5
  final bool? answerBoolean;       // true
  final List<String>? answerOptions;    // ["Opcion A", "Opcion C"]
  final List<String>? answerPhotoUrls;  // URLs de fotos
}
```

### RouteFormQuestion (`route_form_question.dart`)
```dart
class RouteFormQuestion {
  final String id;
  final String routeTypeId;
  final String questionText;       // "Como esta la exhibicion?"
  final QuestionType questionType; // text, number, boolean, select, photo...
  final List<String>? options;     // ["Excelente", "Buena", "Regular", "Mala"]
  final bool isRequired;           // Es obligatoria?
  final int displayOrder;          // Orden en que aparece
}
```

### Client (`client.dart`)
```dart
class Client {
  final String coCli;              // "CLI001" - Codigo unico
  final String cliDes;             // "Ferreteria El Constructor"
  final String? direc1;            // "Av. Bolivar, Centro Comercial X"
  final String? telefonos;         // "0412-1234567"
  final String? ciudad;            // "Caracas"
  final bool permanentlyClosed;    // Si esta cerrado definitivamente
}
```

---

## Gestion de estado con Riverpod

**Riverpod** es el sistema que maneja el "estado" de la app: que datos hay, si estan cargando, si hubo un error, etc. Es como un almacen central de datos que todas las pantallas pueden consultar.

### Tipos de providers usados

```dart
// 1. Provider simple - Retorna un objeto que no cambia
final routeRepositoryProvider = Provider<RouteRepository>((ref) {
  return RouteRepository();
});

// 2. FutureProvider - Carga datos asincronos (de internet o BD)
final todayRoutesProvider = FutureProvider<List<AppRoute>>((ref) async {
  final repository = ref.watch(offlineFirstRouteRepositoryProvider);
  final user = await ref.watch(currentUserProvider.future);
  return repository.getRoutesForToday(user: user!);
});

// 3. StateNotifierProvider - Estado complejo que cambia con acciones
final routeExecutionProvider = StateNotifierProvider<
    RouteExecutionNotifier, RouteExecutionState>((ref) {
  return RouteExecutionNotifier(offlineRepo, onlineRepo);
});
```

### RouteExecutionNotifier (el mas importante)

Es el "cerebro" de la ejecucion de rutas. Maneja:

```dart
class RouteExecutionState {
  final AppRoute? route;              // La ruta activa
  final List<RouteFormQuestion> questions;  // Preguntas del formulario
  final int currentClientIndex;       // Cliente seleccionado
  final bool isLoading;               // Cargando?
  final String? error;                // Error?
  final bool isOfflineMode;           // Sin internet?
  final List<RouteVisit> pendingVisits; // Visitas por sincronizar
}
```

Sus acciones principales:

```dart
notifier.loadRoute(routeId);          // Cargar ruta (offline-first)
notifier.startRoute();                // Iniciar la ruta
notifier.startCurrentClientVisit();   // Iniciar visita al cliente actual
notifier.completeCurrentClientVisit();// Completar visita con formulario
notifier.skipCurrentClient();         // Omitir cliente
notifier.markCurrentClientClosedTemp(); // Marcar cerrado temporal
notifier.completeRoute();             // Completar toda la ruta
notifier.syncPendingVisits();         // Sincronizar datos pendientes
```

### Como se usa en una pantalla

```dart
class MyScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // "Escuchar" el estado - se reconstruye automaticamente cuando cambia
    final state = ref.watch(routeExecutionProvider);

    if (state.isLoading) {
      return CircularProgressIndicator(); // Mostrar carga
    }

    if (state.error != null) {
      return Text('Error: ${state.error}'); // Mostrar error
    }

    // Mostrar los datos
    return Text('Ruta: ${state.route?.name}');
  }

  void _startVisit(WidgetRef ref) {
    // "Ejecutar" una accion
    ref.read(routeExecutionProvider.notifier).startCurrentClientVisit(
      latitude: 10.0,
      longitude: -66.0,
    );
  }
}
```

---

## GPS y permisos

La app captura coordenadas GPS en dos momentos:
1. **Al iniciar** una visita (donde llego el mercaderista)
2. **Al completar** una visita (donde estaba al terminar)

### Servicio de ubicacion (`location_service.dart`)

```dart
class LocationService {
  // Pedir permisos al usuario
  Future<bool> requestPermissions();

  // Obtener coordenadas actuales
  Future<Map<String, double>?> getCoordinates();
  // Retorna: {'latitude': 10.2093, 'longitude': -68.0269}
}
```

### Permisos en Android (`AndroidManifest.xml`)

```xml
<!-- GPS -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>

<!-- Camara -->
<uses-permission android:name="android.permission.CAMERA"/>

<!-- Almacenamiento (para fotos) -->
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
```

La app usa el paquete `geolocator` v11.x con precision alta y un timeout de 10 segundos. Si no puede obtener GPS, muestra "Sin GPS" pero permite continuar.

---

## Captura de fotos

El formulario de visita permite tomar fotos de exhibiciones, productos, etc.

### Flujo de captura

```
1. Mercaderista presiona "Agregar Foto"
2. Elige: Camara o Galeria
3. Toma/selecciona la foto
4. La app comprime la imagen:
   - Calidad: 70%
   - Ancho maximo: 800px
   - Formato: JPEG
5. Si hay internet:
   - Sube a Supabase Storage (bucket: visit-photos)
   - Guarda la URL publica
6. Si NO hay internet:
   - Guarda la foto como archivo local
   - La sube cuando vuelva la conexion
```

### Donde se guardan las fotos

```
Supabase Storage
  +-- visit-photos/
       +-- {mercaderista_id}/
            +-- visit_20260214_143022_0.jpg  (87KB comprimido)
            +-- visit_20260214_143022_1.jpg  (92KB comprimido)
            +-- ...
```

---

## Configuracion y despliegue

### Requisitos previos

- **Flutter SDK** >= 3.9.2
- **Dart SDK** >= 3.9.2
- **Android Studio** con SDK de Android
- Cuenta de **Supabase** con proyecto configurado

### Clonar e instalar

```bash
git clone https://github.com/Dioscar-DEV/app_V2_mercaderista.git
cd app_V2_mercaderista
flutter pub get
```

### Variables de entorno

La configuracion de Supabase esta en `lib/config/supabase_config.dart`:

```dart
static const String supabaseUrl = 'https://tu-proyecto.supabase.co';
static const String supabaseAnonKey = 'tu-anon-key';
```

### Compilar la app

```bash
# Debug (para desarrollo, mas pesado pero con hot reload)
flutter build apk --debug

# Release (para produccion, optimizado)
flutter build apk --release

# El APK se genera en:
# build/app/outputs/flutter-apk/app-release.apk
```

### Instalar en el telefono

```bash
# Via USB con ADB
flutter install

# O copiar el APK al telefono manualmente
```

### Troubleshooting comun

```bash
# Si hay errores de dependencias
flutter clean && flutter pub get

# Si hay errores de Gradle
cd android && ./gradlew clean && cd ..

# Si hay errores de cache
flutter pub cache repair
```

---

## Dependencias principales

### Nucleo

| Paquete | Version | Para que |
|---|---|---|
| `flutter` | SDK | Framework base |
| `flutter_riverpod` | ^2.4.0 | Gestion de estado |
| `go_router` | ^13.0.0 | Navegacion entre pantallas |
| `supabase_flutter` | ^2.0.0 | Backend (DB + Auth + Storage) |

### Base de datos local

| Paquete | Version | Para que |
|---|---|---|
| `sqflite` | ^2.3.0 | Base de datos SQLite local |
| `shared_preferences` | ^2.2.2 | Almacenamiento clave-valor simple |
| `path_provider` | ^2.1.0 | Obtener directorio de la app |

### GPS y mapas

| Paquete | Version | Para que |
|---|---|---|
| `geolocator` | ^11.0.0 | Obtener coordenadas GPS |
| `permission_handler` | ^11.0.0 | Pedir permisos al usuario |
| `google_maps_flutter` | ^2.5.0 | Mostrar mapas |

### Camara y fotos

| Paquete | Version | Para que |
|---|---|---|
| `image_picker` | ^1.0.7 | Seleccionar foto de camara/galeria |
| `flutter_image_compress` | ^2.1.0 | Comprimir fotos antes de subir |
| `cached_network_image` | ^3.3.0 | Cache de imagenes de red |

### Red y conectividad

| Paquete | Version | Para que |
|---|---|---|
| `connectivity_plus` | ^5.0.2 | Detectar si hay internet |
| `dio` | ^5.4.0 | Cliente HTTP para APIs |

### UI y formularios

| Paquete | Version | Para que |
|---|---|---|
| `flutter_form_builder` | ^10.2.0 | Formularios avanzados |
| `fl_chart` | ^0.66.0 | Graficos y estadisticas |
| `table_calendar` | ^3.1.0 | Calendario de rutas |
| `shimmer` | ^3.0.0 | Efecto de carga animado |
| `intl` | - | Formato de fechas y numeros |
| `uuid` | ^4.2.0 | Generar IDs unicos |

### Colores de la app

| Color | Hex | Uso |
|---|---|---|
| Rojo Disbattery | `#DC143C` | Color principal, AppBar, botones |
| Rojo Oscuro | `#8B0000` | Degradados, sombras |
| Dorado | `#FFD700` | Acentos, destacados |
| Verde Exito | `#4CAF50` | Completado, sincronizado |
| Naranja Advertencia | `#FF9800` | En progreso, pendiente |
| Rojo Error | `#D32F2F` | Errores, cerrado |
| Azul Info | `#2196F3` | Informacion, GPS activo |
| Gris Fondo | `#F5F5F5` | Fondo de pantallas |

---

## Licencia

Proyecto privado de **Grupo Disbattery**. Todos los derechos reservados.

## Repositorio

https://github.com/Dioscar-DEV/app_V2_mercaderista.git
