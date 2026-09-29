# Contrato BLE - FitBack

Spec del servicio BLE que expone el ESP32. Estado: **implementado en
`firmware/sensor/sensor.ino`** (stack BLEDevice/Bluedroid de Arduino),
con pendientes listados abajo.

## Implementado (vigente)

- Stack: `BLEDevice` (Bluedroid) de arduino-esp32.
- Nombre de advertising: `GYM-MOTION`.
- Service UUID: `6E400001-B5A3-F393-E0A9-E50E24DCCA9E`
  (servicio UART estilo Nordic).
- TX `6E400003-...CA9E` — notify + read.
- RX `6E400002-...CA9E` — write + write_no_response.
- Formato `DISTANCE` (TX): texto CSV `"tiempo_s,distancia_cm"`
  (ej. `"12.345,23.45"`), notificado cada ~50 ms en modo normal.
- Al desconectarse un central, el advertising se reanuda
  automaticamente.
- Extras del firmware: filtro de mediana (5 lecturas), rango valido
  2-400 cm, modo ahorro (5 s) tras 1 min sin movimiento, monitoreo de
  bateria por ADC (GPIO 34) con LEDs rojo/verde (GPIO 25/26).

## Pendientes para la siguiente iteracion

| Cambio | Motivo |
|--------|--------|
| Nombre `FITBACK-XXXX` (ultimos 4 del MAC) | Dos maquinas vecinas no se confunden al escanear |
| `MACHINE_ID` (read, string <= 20 bytes) | Mapear QR -> perfil de maquina |
| Limitar a 1 conexion central | Regla "nueva conexion gana" |
| `COMMAND` (write, 1 byte opcode) | Reset/calibracion remota (opcional MVP) |

## Opcodes de COMMAND (propuesto)

- `0x01` reset de estadisticas internas
- `0x02` modo calibracion
- `0x03` reiniciar dispositivo

## Debug por USB

Salida Serial a 115200 baud en CSV `tiempo,distancia_cm` mas mensajes
de estado (bateria, modo ahorro, eventos BLE).
