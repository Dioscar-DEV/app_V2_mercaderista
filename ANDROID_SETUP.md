# Guía para Configurar Android y Generar APK

## 📱 Configuración de Android Studio

### Paso 1: Instalar Android SDK y Herramientas

1. **Abre Android Studio**
2. Ve a **File** > **Settings** (o **Android Studio** > **Preferences** en Mac)
3. Navega a **Appearance & Behavior** > **System Settings** > **Android SDK**
4. En la pestaña **SDK Platforms**, instala:
   - ✅ Android 13.0 (Tiramisu) - API Level 33
   - ✅ Android 12.0 (S) - API Level 31

5. En la pestaña **SDK Tools**, instala:
   - ✅ Android SDK Build-Tools
   - ✅ Android SDK Command-line Tools
   - ✅ Android Emulator
   - ✅ Android SDK Platform-Tools
   - ✅ Google Play Services

6. Click en **Apply** y espera a que se descarguen

### Paso 2: Aceptar Licencias de Android

Abre la terminal (PowerShell o CMD) y ejecuta:

```bash
flutter doctor --android-licenses
```

Presiona `y` (yes) para aceptar todas las licencias.

### Paso 3: Verificar Configuración

```bash
flutter doctor -v
```

Deberías ver algo como:
```
[✓] Flutter (Channel stable, 3.x.x)
[✓] Android toolchain - develop for Android devices (Android SDK version 33.0.0)
[✓] Chrome - develop for the web
[✓] Android Studio (version 2023.x)
```

---

## 📲 Crear y Configurar Emulador Android

### Opción A: Crear Emulador desde Android Studio (Recomendado)

1. Abre **Android Studio**
2. Ve a **Tools** > **Device Manager** (o haz click en el ícono de dispositivos)
3. Click en **Create Device**
4. Selecciona un dispositivo (recomendado: **Pixel 7** o **Pixel 5**)
5. Click **Next**
6. Selecciona una imagen del sistema:
   - **API Level 33** (Android 13) - Recomendado
   - Descarga la imagen si es necesario
7. Click **Next**
8. Configura el nombre (ejemplo: `Pixel_7_API_33`)
9. Click **Finish**

### Opción B: Crear Emulador desde Terminal

```bash
# Ver emuladores disponibles
flutter emulators

# Crear un emulador nuevo
flutter emulators --create

# Iniciar el emulador
flutter emulators --launch <emulator_id>
```

---

## 🚀 Ejecutar la App en Android

### Iniciar el Emulador

Opción 1 - Desde Android Studio:
1. Abre **Device Manager**
2. Click en el botón **Play ▶️** del emulador que creaste

Opción 2 - Desde Terminal:
```bash
flutter emulators --launch Pixel_7_API_33
```

### Ejecutar la App

```bash
cd disbattery_trade

# Ver dispositivos disponibles
flutter devices

# Ejecutar en el emulador
flutter run

# O especificar el dispositivo
flutter run -d emulator-5554
```

---

## 📦 Generar APK para Distribución

### APK de Debug (para pruebas rápidas)

```bash
cd disbattery_trade
flutter build apk --debug
```

El APK estará en: `build/app/outputs/flutter-apk/app-debug.apk`

### APK de Release (para distribución)

```bash
flutter build apk --release
```

El APK estará en: `build/app/outputs/flutter-apk/app-release.apk`

### APK Optimizado por ABI (más pequeño)

```bash
# Genera 3 APKs separados (arm64-v8a, armeabi-v7a, x86_64)
flutter build apk --split-per-abi --release
```

Los APKs estarán en: `build/app/outputs/flutter-apk/`
- `app-arm64-v8a-release.apk` (para la mayoría de dispositivos modernos)
- `app-armeabi-v7a-release.apk` (para dispositivos más antiguos)
- `app-x86_64-release.apk` (para emuladores y tablets x86)

---

## 📤 Instalar APK en Dispositivo

### En Emulador

Método 1 - Arrastra y suelta:
1. Arrastra el archivo APK al emulador
2. Se instalará automáticamente

Método 2 - ADB:
```bash
adb install build/app/outputs/flutter-apk/app-debug.apk
```

### En Dispositivo Físico

1. **Habilita USB Debugging** en tu Android:
   - Ve a **Configuración** > **Acerca del teléfono**
   - Toca **Número de compilación** 7 veces
   - Vuelve a **Configuración** > **Opciones de desarrollador**
   - Activa **Depuración USB**

2. **Conecta el dispositivo por USB**

3. **Verifica la conexión**:
```bash
adb devices
```

4. **Instala el APK**:
```bash
adb install build/app/outputs/flutter-apk/app-debug.apk
```

O simplemente:
```bash
flutter run
# Flutter detectará automáticamente tu dispositivo
```

---

## 🎨 Configurar Icono y Nombre de la App

### Cambiar Nombre de la App

Edita `android/app/src/main/AndroidManifest.xml`:
```xml
<application
    android:label="Disbattery Trade"
    ...>
```

### Cambiar Icono de la App

1. Instala el paquete `flutter_launcher_icons`:

```bash
flutter pub add dev:flutter_launcher_icons
```

2. Crea `flutter_launcher_icons.yaml` en la raíz:

```yaml
flutter_launcher_icons:
  android: true
  ios: false
  image_path: "assets/images/logo.png"
  adaptive_icon_background: "#1976D2"
  adaptive_icon_foreground: "assets/images/logo.png"
```

3. Ejecuta:
```bash
flutter pub run flutter_launcher_icons
```

---

## 🔐 Firmar APK para Google Play Store (Opcional)

Si quieres subir la app a Play Store:

### 1. Generar Keystore

```bash
keytool -genkey -v -keystore C:\Users\dsalc\disbattery-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias disbattery
```

### 2. Configurar el Keystore

Crea `android/key.properties`:
```properties
storePassword=TU_PASSWORD
keyPassword=TU_PASSWORD
keyAlias=disbattery
storeFile=C:\\Users\\dsalc\\disbattery-key.jks
```

### 3. Configurar build.gradle

Edita `android/app/build.gradle` y agrega antes de `android {`:

```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}
```

Y dentro de `android { ... }` en `buildTypes`:

```gradle
signingConfigs {
    release {
        keyAlias keystoreProperties['keyAlias']
        keyPassword keystoreProperties['keyPassword']
        storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
        storePassword keystoreProperties['storePassword']
    }
}
buildTypes {
    release {
        signingConfig signingConfigs.release
    }
}
```

### 4. Generar APK Firmado

```bash
flutter build apk --release
```

---

## 🎯 Comandos Rápidos de Referencia

```bash
# Ver dispositivos
flutter devices

# Ejecutar en dispositivo específico
flutter run -d <device-id>

# Ejecutar en modo release
flutter run --release

# Ver logs
flutter logs

# Limpiar build
flutter clean

# Generar APK debug
flutter build apk --debug

# Generar APK release
flutter build apk --release

# Generar APK optimizado
flutter build apk --split-per-abi --release

# Instalar APK
adb install ruta/al/archivo.apk

# Desinstalar app
adb uninstall com.disbattery.disbattery_trade

# Ver logs de Android en tiempo real
adb logcat | findstr flutter
```

---

## 🐛 Solución de Problemas

### Error: "SDK location not found"

Crea `android/local.properties`:
```properties
sdk.dir=C:\\Users\\TU_USUARIO\\AppData\\Local\\Android\\Sdk
```

### Error: "Android license status unknown"

```bash
flutter doctor --android-licenses
```

### Emulador muy lento

1. Habilita aceleración por hardware (HAXM o Hyper-V)
2. Aumenta RAM del emulador (4GB recomendado)
3. Usa una imagen del sistema sin Google Play

### App no se instala en dispositivo

```bash
# Desinstala versión anterior
adb uninstall com.disbattery.disbattery_trade

# Reinstala
flutter run
```

---

## 📱 Permisos Necesarios

La app ya tiene configurados en `AndroidManifest.xml`:

- ✅ Internet
- ✅ Ubicación (GPS)
- ✅ Cámara
- ✅ Almacenamiento

Estos se solicitarán en tiempo de ejecución cuando sean necesarios.

---

## 🎉 ¡Listo!

Ahora puedes:
1. ✅ Ejecutar la app en emulador Android
2. ✅ Generar APK para instalar en cualquier dispositivo
3. ✅ Distribuir la app a los mercaderistas

Para compartir el APK:
1. Genera el APK release: `flutter build apk --release`
2. El archivo estará en: `build/app/outputs/flutter-apk/app-release.apk`
3. Compártelo por WhatsApp, email o Dropbox
4. Los usuarios solo necesitan habilitarlo en "Instalar apps de origen desconocido"
