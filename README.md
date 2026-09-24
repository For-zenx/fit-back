# FitBack

**Guía inteligente para máquinas de peso apilado.**

FitBack es una app Android MVP que se conecta por BLE a un microcontrolador ESP32 equipado con un sensor ultrasónico. El sensor mide el movimiento de la primera placa apilada de una máquina de gimnasio y la app guía al usuario en tiempo real durante el ejercicio: cuenta reps, marca el rango de movimiento y da retroalimentación visual.

## Alcance del MVP

- App Android distribuible vía APK (sideload) y landing page con QR.
- Conexión BLE directa al ESP32 de la máquina.
- Identificación de la máquina mediante QR.
- Lectura continua de distancia desde el sensor ultrasónico.
- Detección de reps y guía visual básica.
- Resumen local de la sesión.
- **Sin servidor, sin autenticación, sin detección de peso.**

## Flujo de uso (MVP)

1. El usuario llega a la máquina y escanea el QR.
2. El QR abre una landing page.
3. Si no tiene la app, descarga e instala el APK.
4. Si ya la tiene, el deep link abre la app con el ID de la máquina.
5. La app se conecta por BLE al ESP32.
6. El usuario hace el set; la app cuenta reps y guía el movimiento.
7. Al terminar, se muestra un resumen local y se libera la conexión BLE.

## Tecnología

- **Frontend mobile**: por definir (React Native / Flutter / nativo Android).
- **Firmware del dispositivo**: ESP32 + NimBLE (gestionado por el socio).
- **Comunicación**: Bluetooth Low Energy (BLE).
- **Backend**: ninguno en el MVP; todo es local-first.

## Estructura del repo

```
fitback/
├── README.md
├── docs/
│   ├── architecture.md     # Arquitectura y decisiones técnicas
│   ├── ble-protocol.md     # Contrato BLE (cuando se defina)
│   └── ui-wireframes.md    # Bosquejos de pantallas
├── src/                    # Código fuente de la app (cuando se elija stack)
└── assets/                 # Logos, iconos, QR templates
```

## Decisiones clave

- **Offline-first**: funciona sin internet del gimnasio.
- **Una conexión BLE activa por máquina**: el ESP32 debe liberar la conexión anterior cuando se conecta un nuevo usuario.
- **Perfil de máquina embebido**: el ID del QR se mapea a un perfil local de la app (ejercicio, recorrido mín/máx).
- **Datos de peso fuera del MVP**: el usuario puede anotarlo manualmente; no se detecta automáticamente.

## Estado

En fase de diseño y prototipado. El objetivo inicial es validar el flujo completo en un gimnasio local.

## Autores

- Francisco — software / app / arquitectura
- [Socio] — hardware / firmware / sensor ultrasónico
