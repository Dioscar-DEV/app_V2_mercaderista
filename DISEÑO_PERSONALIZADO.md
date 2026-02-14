# Diseño Personalizado - Disbattery Trade

## 🎨 Personalización de la App según Referencia

Esta guía te ayudará a personalizar completamente el diseño de la app según tus preferencias.

## 📋 Antes de Comenzar

Para personalizar el diseño de la app, necesitaré:

### 1. App de Referencia
- 📱 Nombre de la app de referencia
- 🔗 Link de descarga (Google Play / App Store)
- 📸 Screenshots de las pantallas principales

### 2. Pantallas a Diseñar

#### Para Mercaderistas:
- [ ] Splash Screen / Login
- [ ] Home / Dashboard
- [ ] Lista de rutas asignadas
- [ ] Detalle de ruta (mapa + clientes)
- [ ] Formulario de visita
- [ ] Captura de fotos
- [ ] Historial de visitas

#### Para Administradores:
- [ ] Dashboard principal
- [ ] Gestión de clientes
- [ ] Gestión de rutas
- [ ] Asignación de rutas a mercaderistas
- [ ] Reportes y estadísticas
- [ ] Gestión de usuarios

### 3. Elementos de Diseño

Por favor proporciona:

#### Colores
- Color primario
- Color secundario
- Color de acento
- Colores de marca (Shell, Qualid)
- Colores de fondo

#### Tipografía
- Fuente principal
- Tamaños de texto
- Estilos (títulos, subtítulos, cuerpo)

#### Iconos
- Estilo de iconos (Material, Cupertino, Custom)
- Iconos personalizados (si los hay)

#### Logo
- Logo de la empresa
- Variantes (claro/oscuro)
- Formato (SVG, PNG)

---

## 🎯 Cómo Compartir la App de Referencia

### Opción 1: App Pública
Comparte el link de Google Play o App Store:
```
Ejemplo: https://play.google.com/store/apps/details?id=com.ejemplo.app
```

### Opción 2: Screenshots
Toma capturas de pantalla de:
1. Pantalla de login
2. Dashboard principal
3. Lista de elementos
4. Detalle de elemento
5. Formularios
6. Cualquier pantalla que consideres importante

### Opción 3: Descripción Detallada
Describe cómo quieres que se vea cada pantalla:
- Layout (distribución de elementos)
- Colores y estilos
- Navegación (tabs, drawer, bottom nav)
- Cards, listas, formularios
- Botones y acciones

---

## 🔄 Proceso de Personalización

1. **Análisis de Referencia**
   - Revisar app de referencia
   - Identificar patrones de diseño
   - Extraer paleta de colores
   - Mapear flujos de navegación

2. **Adaptación de Componentes**
   - Actualizar `theme_config.dart` con colores
   - Crear widgets personalizados
   - Ajustar layouts de pantallas
   - Personalizar navegación

3. **Implementación**
   - Modificar pantallas existentes
   - Crear nuevos componentes
   - Aplicar animaciones
   - Optimizar UX

4. **Revisión y Ajustes**
   - Probar en diferentes dispositivos
   - Ajustar espaciados y tamaños
   - Verificar accesibilidad
   - Pulir detalles

---

## 📐 Estructura Actual del Diseño

### Tema Base (`lib/config/theme_config.dart`)

```dart
// Colores actuales
primaryColor: Color(0xFF1976D2)      // Azul
secondaryColor: Color(0xFFFF9800)    // Naranja
accentColor: Color(0xFF4CAF50)       // Verde

// Colores de marca
shellYellow: Color(0xFFFFDD00)
shellRed: Color(0xFFED1C24)
qualidBlue: Color(0xFF0066CC)
qualidGreen: Color(0xFF00AA00)
```

### Componentes Personalizables

- ✅ Botones (elevados, outlined, text)
- ✅ Cards
- ✅ Formularios (inputs, dropdowns)
- ✅ AppBar
- ✅ Bottom Navigation
- ✅ Diálogos
- ✅ Snackbars
- ✅ Progress indicators

---

## 🎨 Ejemplos de Personalización

### Cambiar Colores

Edita `lib/config/theme_config.dart`:

```dart
static const Color primaryColor = Color(0xFFTU_COLOR);
static const Color secondaryColor = Color(0xFFTU_COLOR);
```

### Cambiar Fuente

1. Descarga la fuente (Google Fonts o custom)
2. Agrégala a `pubspec.yaml`:
```yaml
fonts:
  - family: TuFuente
    fonts:
      - asset: assets/fonts/TuFuente-Regular.ttf
      - asset: assets/fonts/TuFuente-Bold.ttf
        weight: 700
```
3. Aplícala en `theme_config.dart`:
```dart
fontFamily: 'TuFuente',
```

### Personalizar Cards

Crea un widget custom en `lib/presentation/widgets/common/`:

```dart
class CustomCard extends StatelessWidget {
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        // Tu diseño personalizado
      ),
      child: child,
    );
  }
}
```

---

## 🚀 Implementación Rápida

Una vez que me compartas la app de referencia, podré:

1. ✅ Actualizar paleta de colores
2. ✅ Recrear componentes visuales
3. ✅ Adaptar layouts de pantallas
4. ✅ Implementar navegación similar
5. ✅ Ajustar animaciones y transiciones
6. ✅ Optimizar para diferentes tamaños de pantalla

---

## 📝 Checklist de Información Necesaria

Antes de empezar la personalización, marca lo que puedes proporcionar:

### Diseño Visual
- [ ] App de referencia (link o screenshots)
- [ ] Logo de Disbattery
- [ ] Paleta de colores específica
- [ ] Fuentes personalizadas
- [ ] Iconos custom

### Funcionalidad
- [ ] Flujo de navegación deseado
- [ ] Campos específicos en formularios
- [ ] Tipos de reportes necesarios
- [ ] Permisos por rol (qué puede hacer cada tipo de usuario)

### Branding
- [ ] Guía de marca (brand guidelines)
- [ ] Imágenes corporativas
- [ ] Slogan o mensajes específicos

---

## 🎯 Próximos Pasos

1. **Comparte la app de referencia**
   - Link o screenshots

2. **Define prioridades**
   - ¿Qué pantallas son más importantes?
   - ¿Qué funcionalidades necesitas primero?

3. **Revisión iterativa**
   - Te mostraré avances
   - Ajustaremos según tu feedback
   - Puliremos detalles

---

## 💡 Notas Importantes

- La app ya tiene **funcionamiento offline** configurado (Fase 9 del plan)
- Soporta **2 tipos de usuario**: Admin y Mercaderista
- Los admins pueden **asignar rutas** a mercaderistas específicos
- Todo está preparado para **personalización rápida**

---

## 📞 ¿Listo para Personalizar?

Cuando tengas la app de referencia:

1. Compártela (link, screenshots o descripción)
2. Especifica qué te gusta de ella
3. Indica qué quieres adaptar o cambiar
4. ¡Empezamos la personalización!

La estructura base ya está lista, solo necesitamos los detalles visuales para hacer la app **exactamente como la quieres**.
