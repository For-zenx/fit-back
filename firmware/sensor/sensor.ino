// FitBack - Sensor de movimiento para maquinas de gimnasio
// Autor original: Alejandro Dumo
// Baseline: Bluetooth clasico (SPP) + HC-SR04 a 20 Hz
// NOTA: migrar a BLE (NimBLE) segun docs/ble-protocol.md

#include "BluetoothSerial.h"

BluetoothSerial SerialBT;

// -------------------------
// Pines HC-SR04
// -------------------------
#define TRIG_PIN 5
#define ECHO_PIN 18

// -------------------------
// Bluetooth
// -------------------------
const char* NOMBRE_BT = "GYM-MOTION";

// -------------------------
// Variables
// -------------------------
unsigned long tiempoInicio;
unsigned long ultimaMedicion = 0;

// Medicion cada 50 ms = 20 Hz
const unsigned long INTERVALO = 50;

// -------------------------
// Medir distancia (cm)
// -------------------------
float medirDistancia()
{
    digitalWrite(TRIG_PIN, LOW);
    delayMicroseconds(2);

    digitalWrite(TRIG_PIN, HIGH);
    delayMicroseconds(10);

    digitalWrite(TRIG_PIN, LOW);

    unsigned long duracion = pulseIn(ECHO_PIN, HIGH, 30000);

    if (duracion == 0)
    {
        return -1;
    }

    float distancia = duracion * 0.0343 / 2.0;

    return distancia;
}

// -------------------------
// SETUP
// -------------------------
void setup()
{
    Serial.begin(115200);

    pinMode(TRIG_PIN, OUTPUT);
    pinMode(ECHO_PIN, INPUT);

    digitalWrite(TRIG_PIN, LOW);

    // Iniciar Bluetooth
    SerialBT.begin(NOMBRE_BT);

    // Tiempo inicial
    tiempoInicio = millis();

    Serial.println();
    Serial.println("==============================");
    Serial.println("     GYM MOTION ESP32");
    Serial.println("==============================");
    Serial.println();

    Serial.print("Bluetooth: ");
    Serial.println(NOMBRE_BT);

    Serial.println("Esperando conexion...");
}

// -------------------------
// LOOP
// -------------------------
void loop()
{
    unsigned long ahora = millis();

    // Medir cada 50 ms
    if (ahora - ultimaMedicion >= INTERVALO)
    {
        ultimaMedicion = ahora;

        // Medir distancia
        float distancia = medirDistancia();

        // Tiempo desde que inicio el ESP32
        float tiempo = (ahora - tiempoInicio) / 1000.0;

        // Si la medicion es valida
        if (distancia > 0)
        {
            // -------------------------
            // Enviar por Bluetooth
            // -------------------------

            SerialBT.print(tiempo, 3);
            SerialBT.print(",");
            SerialBT.println(distancia, 2);

            // -------------------------
            // Tambien mostrar por USB
            // -------------------------

            Serial.print(tiempo, 3);
            Serial.print(",");
            Serial.println(distancia, 2);
        }
    }
}
