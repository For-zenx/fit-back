# Firmware: flasheo y mantenimiento

Guia para flashear el ESP32 por USB y (en fase 2) por OTA.

## Hardware

- ESP32 DevKit C v4 + HC-SR04 (cableado en `firmware/hardware/README.md`).
- Chip USB-serie: **CP2102**. Requiere driver "CP210x VCP" de Silicon Labs
  (ya instalado — verificar que aparece un puerto `COMx` en el
  Administrador de dispositivos sin triangulo amarillo).

## Opcion A: Arduino IDE (recomendada)

1. Instalar Arduino IDE 2.x.
2. Agregar el core ESP32: en *File > Preferences > Additional board URLs*
   pegar `https://espressif.github.io/arduino-esp32/package_esp32_index.json`
   y luego instalar "esp32" desde el Boards Manager.
3. Board: **ESP32 Dev Module**. Puerto: el `COMx` del CP2102.
4. Abrir `firmware/sensor/sensor.ino` y pulsar Upload.
5. Verificar en Monitor Serie (115200 baud): debe imprimir
   `tiempo,distancia` cada 50 ms.

## Opcion B: arduino-cli (linea de comandos)

```powershell
arduino-cli core install esp32:esp32
arduino-cli compile -b esp32:esp32:esp32 firmware/sensor
arduino-cli upload -b esp32:esp32:esp32 -p COM5 firmware/sensor
```

## Opcion C: esptool (binario ya compilado)

```powershell
pip install esptool
esptool.py --port COM5 write_flash 0x1000 firmware.bin
```

## Notas de flasheo

- Si el upload falla con "Failed to connect": mantener presionado **BOOT**
  en la placa durante el intento de conexion.
- Cambios de pines o constantes van al inicio de `sensor.ino`
  (TRIG_PIN, ECHO_PIN, INTERVALO).
- Cada maquina instalada debe flashear su `MACHINE_ID` propio
  (o guardarlo en NVS via `COMMAND`, cuando se implemente).

## OTA (fase 2)

Objetivo: actualizar sin desmontar el aparato de la maquina.

- Opcion simple: `ArduinoOTA` por WiFi (requiere que el ESP32 tenga
  credenciales del WiFi del gimnasio — friccion de instalacion).
- Opcion alineada con BLE: NimBLE soporta OTA sobre BLE (el telefono
  envia el firmware). Mas complejo pero cero configuracion de red.
- Decidir cuando el MVP este estable; documentar la decision aqui.

## Versionado

El firmware vive en `firmware/` dentro de este repo y se versiona por
PR como el resto del codigo (ver CONTRIBUTING.md). No editar el sketch
flasheado "a mano" sin commitear el cambio — si el aparato se pierde o
se rompe, el repo es la fuente de verdad.
