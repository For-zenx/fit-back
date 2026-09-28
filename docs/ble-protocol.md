# Contrato BLE - FitBack

Spec del servicio BLE que expone el ESP32. Documento de referencia para
firmware y app. Estado: **propuesto** (pendiente de implementar en NimBLE).

## Identidad del dispositivo

- Nombre de advertising: `FITBACK-XXXX` donde `XXXX` = ultimos 4 hex del MAC.
- Max 1 conexion central simultanea ("nueva conexion gana": si llega un
  segundo central, el ESP32 desconecta al anterior).

## Servicio

| Campo | Valor |
|-------|-------|
| Service UUID | `6e400001-b5a3-f393-e0a9-e50e24dcca9e` *(propuesto, Nordic UART-like)* |

## Characteristics

| Nombre | UUID | Props | Formato |
|--------|------|-------|---------|
| `DISTANCE` | `6e400002-...ca9e` | notify | uint16 LE, distancia en mm |
| `MACHINE_ID` | `6e400003-...ca9e` | read | string UTF-8, ej. `"GYM01-LEGPRESS"` |
| `COMMAND` | `6e400004-...ca9e` | write | 1 byte opcode (ver abajo) |

*(Los UUIDs concretos se fijan al implementar; completar la tabla y
avisar al equipo antes de cambiarlos.)*

## Formato de datos

- `DISTANCE`: uint16 little-endian. Unidad: **mm** para resolucion fina
  (equivale a cm × 10; el firmware mide en cm y multiplica por 10).
  Frecuencia objetivo: notificacion cada ~50 ms (20 Hz).
  Valor `0xFFFF` = medicion invalida (timeout de `pulseIn`).
- `MACHINE_ID`: texto, max 20 bytes. Se define al instalar cada maquina
  y se flashea o se guarda en NVS (Preferences).
- `COMMAND` opcodes:
  - `0x01` = reset de estadisticas internas
  - `0x02` = entrar en modo calibracion (futuro)
  - `0x03` = reiniciar dispositivo

## Comportamiento

- El ESP32 notifica `DISTANCE` solo a centrales suscritos.
- Mientras no haya conexion, el nombre `FITBACK-XXXX` sigue en
  advertising para que la app lo descubra.
- Al desconectarse el central, el ESP32 vuelve a hacer advertising de
  inmediato.

## Debug por USB

El firmware mantiene la salida Serial a 115200 baud con el formato CSV
actual `tiempo,distancia_cm` para depurar con Monitor Serie.
