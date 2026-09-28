# Hardware del sensor

Microcontrolador: **ESP32 DevKit C v4** (chip USB-serie CP2102)
Sensor: **HC-SR04** ultrasonico

Simulacion original en Wokwi: https://wokwi.com/projects/475462253940379649

## Cableado

| HC-SR04 | ESP32 | Nota |
|---------|-------|------|
| VCC | 5V (VIN) | El sensor necesita 5V |
| GND | GND | |
| TRIG | GPIO 5 | Salida del ESP32 |
| ECHO | GPIO 18 | A traves de divisor de voltaje |

## Divisor de voltaje en ECHO

El pin ECHO del HC-SR04 entrega 5V, pero el ESP32 solo tolera 3.3V.
Se usa un divisor con dos resistencias:

```
ECHO ──[ R1 = 1kΩ ]──► GPIO 18
              │
           [ R2 = 2kΩ ]
              │
             GND
```

Resultado: 5V × (2k / 3k) ≈ 3.3V en GPIO 18.

Ver `diagram.json` para el esquematico completo (importable en Wokwi).

## Flasheo por USB

La placa usa chip CP2102. Requiere el driver "CP210x VCP" de Silicon Labs.
Una vez instalado, la placa aparece como puerto COM en Windows.
Ver `docs/firmware.md` para el procedimiento completo.
