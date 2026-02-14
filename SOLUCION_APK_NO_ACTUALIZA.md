# Solución: APK no refleja los cambios del código

## Problema
Los cambios realizados en el código Flutter se ven correctamente en Chrome (debug mode), pero al instalar la APK en el dispositivo Android, los cambios no aparecen.

## Causa
Flutter y Gradle mantienen caché de compilaciones anteriores para acelerar los builds. Cuando se hacen cambios significativos en el código, este caché puede causar que la APK se genere con código obsoleto.

## Solución

### Paso 1: Limpiar el caché de Flutter
```bash
flutter clean
```
Este comando elimina:
- Carpeta `build/`
- Carpeta `.dart_tool/`
- Archivos temporales de iOS/Android

### Paso 2: Reinstalar dependencias
```bash
flutter pub get
```

### Paso 3: Reconstruir la APK
```bash
flutter build apk --release
```

### Comando completo (una sola línea)
```bash
flutter clean; flutter pub get; flutter build apk --release
```

## En el dispositivo Android
Después de generar la nueva APK:
1. **Desinstalar** la versión anterior de la app manualmente
2. **Instalar** la nueva APK
3. Si aún no funciona, reiniciar el dispositivo

## Prevención
Cuando hagas cambios importantes en el código, siempre ejecuta `flutter clean` antes de generar la APK de release.

## Ubicación de la APK
```
build\app\outputs\flutter-apk\app-release.apk
```

---
*Documentado el 12 de febrero de 2026*
