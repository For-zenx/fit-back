# FitBack

**Convierte cualquier maquina de gimnasio en una maquina inteligente.**

FitBack es un retrofit: un ESP32 con sensor ultrasonico se instala en la
maquina y una app Android guia al usuario en tiempo real — cuenta reps,
marca el rango de movimiento y da retroalimentacion visual. Las metricas
se guardan localmente y se sincronizan a un servidor minimo cuando hay
internet.

## Alcance del MVP

- App Android (Flutter) distribuible via APK y landing page con QR.
- Conexion BLE al ESP32 de la maquina (firmware en migracion desde
  Bluetooth clasico).
- Identificacion de la maquina y del gimnasio mediante QR (`gym_id` +
  `machine_id`).
- Lectura continua de distancia, deteccion de reps y guia visual.
- Auto-calibracion del rango de movimiento por maquina.
- Registro anonimo y licencia por token con expiracion (permite cortar
  servicio a gimnasios que no pagan, incluso sin internet).
- Resumen local de la sesion (SQLite, offline-first).
- **Sin peso automatico, sin cuentas multi-dispositivo, sin Google Play.**

Ver `docs/roadmap.md` para las fases 2 (VPS, panel, sync, Google auth) y
3 (entrenador, IA, Play Store).

## Flujo de uso (MVP)

1. El usuario llega a la maquina y escanea el QR.
2. El QR abre una landing page.
3. Si no tiene la app, descarga e instala el APK.
4. Si ya la tiene, el deep link abre la app con el ID de la maquina.
5. La app se conecta por BLE al ESP32.
6. El usuario hace el set; la app cuenta reps y guia el movimiento.
7. Al terminar, se muestra un resumen local y se libera la conexion BLE.
8. Con internet, la app sincroniza la sesion y renueva su licencia.

## Tecnologia

- **App mobile**: Flutter (Android) + `flutter_blue_plus` para BLE.
- **Firmware**: ESP32 + HC-SR04, migrando a NimBLE (`firmware/`).
- **Comunicacion**: Bluetooth Low Energy.
- **Backend**: VPS minimo en fase 2 (licencias + sync + panel).

## Estructura del repo

```
fitback/
├── README.md
├── CONTRIBUTING.md
├── docs/
│   ├── architecture.md      # Arquitectura y decisiones tecnicas
│   ├── ble-protocol.md      # Contrato BLE (UUIDs, formatos)
│   ├── firmware.md          # Flasheo USB/OTA y mantenimiento
│   ├── roadmap.md           # Fases del producto
│   ├── machine-profiles.md  # Catalogo de maquinas (por definir)
│   └── ui-wireframes.md     # Bosquejos de pantallas (por definir)
├── firmware/
│   ├── sensor/sensor.ino    # Sketch del ESP32
│   └── hardware/            # Cableado y diagrama Wokwi
├── src/                     # App Flutter (por crear)
└── assets/                  # Logos, iconos, plantillas QR
```

## Decisiones clave

- **Offline-first**: el ejercicio funciona sin internet; el servidor solo
  maneja licencias y sincronizacion.
- **Licencia por expiracion**: tokens firmados por `gym_id`; si el
  gimnasio no paga, los tokens dejan de renovarse y la app se bloquea sola.
- **Una conexion BLE activa por maquina**: nueva conexion gana.
- **Auto-calibracion**: el perfil de cada maquina se aprende con las
  primeras sesiones y se refina con percentiles agregados.
- **Cualquier maquina**: no solo peso apilado — cualquier parte movil que
  el ultrasonico pueda rastrear.

## Como correr la app

### Prerequisitos (una sola vez por maquina)

1. Instalar **Flutter SDK**: descargar el zip de
   https://docs.flutter.dev/get-started/install/windows y extraerlo
   (ej. `C:\flutter`). Agregar `C:\flutter\bin` al PATH del usuario.
2. Instalar **Android Studio** (trae el Android SDK y Java embebido).
3. Para correr en escritorio: **Visual Studio Build Tools** con
   "Desktop development with C++".
4. Verificar el entorno:

```powershell
flutter doctor   # todo debe salir en verde
```

### Correr en Windows (lo mas rapido para desarrollo)

```powershell
cd app
flutter run -d windows
```

Con el proceso corriendo: `r` = hot reload, `q` = salir.

### Correr en Chrome

```powershell
flutter run -d chrome
```

### Correr en emulador Android

```powershell
# una vez: instalar imagen del sistema y crear el AVD
sdkmanager "system-images;android-36;google_apis;x86_64"
flutter emulators --create --name pixel_test

# cada vez
flutter emulators --launch pixel_test
flutter run -d emulator-5554
```

### Correr en telefono fisico (necesario para BLE)

El emulador no tiene Bluetooth. Para probar contra el ESP32 real:

1. En el telefono: activar *Opciones de desarrollador* (7 toques en
   "Numero de compilacion") y *Depuracion USB*.
2. Conectar por USB, aceptar el prompt en el telefono.
3. `flutter devices` debe listarlo; luego `flutter run -d <id>`.

### Tests y analisis

```powershell
flutter test      # tests unitarios
flutter analyze   # lint/errores
```

## Estado

En fase de prototipado. El hardware funciona y envia datos; el siguiente
hito es la migracion a BLE y el inicio de la app Flutter.
Contribuciones: ver `CONTRIBUTING.md` (main protegida, cambios por PR).

## Autores

- Francisco — software / app / arquitectura
- Alejandro Dumo — hardware / firmware / sensor ultrasonico
