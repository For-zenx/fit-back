#include <Arduino.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <math.h>

// ======================================================
// BLE
// ======================================================

#define NOMBRE_BLE "GYM-MOTION"

#define SERVICE_UUID "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
#define CHARACTERISTIC_TX "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"
#define CHARACTERISTIC_RX "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"

BLEServer* servidorBLE = NULL;
BLECharacteristic* caracteristicaTX = NULL;
BLECharacteristic* caracteristicaRX = NULL;

bool dispositivoConectado = false;


// ======================================================
// HC-SR04
// ======================================================

const int TRIG_PIN = 5;
const int ECHO_PIN = 18;


// ======================================================
// LEDS
// ======================================================

const int LED_ROJO = 25;
const int LED_VERDE = 26;


// ======================================================
// BATERIA
// ======================================================

const int PIN_BATERIA = 34;


// ======================================================
// CONFIGURACION
// ======================================================

const unsigned long INTERVALO_NORMAL = 50;
const unsigned long INTERVALO_AHORRO = 5000;
const unsigned long TIEMPO_INACTIVIDAD = 60000;
const unsigned long TIMEOUT_ECHO = 30000;


// ======================================================
// SENSIBILIDAD
// ======================================================

const float TOLERANCIA_MOVIMIENTO = 1.0;


// ======================================================
// FILTRO
// ======================================================

const int NUM_LECTURAS_FILTRO = 5;


// ======================================================
// BATERIA
// ======================================================

const float FACTOR_DIVISOR_BATERIA = 2.0;
const float VOLTAJE_BATERIA_BAJO = 4.60;


// ======================================================
// VARIABLES
// ======================================================

unsigned long tiempoInicio = 0;
unsigned long ultimaMedicion = 0;
unsigned long ultimoMovimiento = 0;
unsigned long ultimaMedicionBateria = 0;

bool modoAhorro = false;

float distanciaAnterior = -1.0;


// ======================================================
// MEDIR DISTANCIA
// ======================================================

float medirDistanciaSimple()
{
    digitalWrite(TRIG_PIN, LOW);
    delayMicroseconds(2);

    digitalWrite(TRIG_PIN, HIGH);
    delayMicroseconds(10);

    digitalWrite(TRIG_PIN, LOW);

    unsigned long duracion = pulseIn(
        ECHO_PIN,
        HIGH,
        TIMEOUT_ECHO
    );

    if (duracion == 0)
    {
        return -1.0;
    }

    float distancia =
        (duracion * 0.0343) / 2.0;

    if (distancia < 2.0 || distancia > 400.0)
    {
        return -1.0;
    }

    return distancia;
}


// ======================================================
// ORDENAR LECTURAS
// ======================================================

void ordenarLecturas(float valores[], int cantidad)
{
    for (int i = 0; i < cantidad - 1; i++)
    {
        for (int j = i + 1; j < cantidad; j++)
        {
            if (valores[j] < valores[i])
            {
                float temporal = valores[i];

                valores[i] = valores[j];

                valores[j] = temporal;
            }
        }
    }
}


// ======================================================
// FILTRO DE MEDIANA
// ======================================================

float medirDistanciaFiltrada()
{
    float lecturas[NUM_LECTURAS_FILTRO];

    int lecturasValidas = 0;

    for (int i = 0; i < NUM_LECTURAS_FILTRO; i++)
    {
        float lectura = medirDistanciaSimple();

        if (lectura >= 2.0 && lectura <= 400.0)
        {
            lecturas[lecturasValidas] = lectura;
            lecturasValidas++;
        }

        delay(5);
    }

    if (lecturasValidas == 0)
    {
        return -1.0;
    }

    ordenarLecturas(
        lecturas,
        lecturasValidas
    );

    if (lecturasValidas % 2 == 1)
    {
        return lecturas[lecturasValidas / 2];
    }

    int mitad = lecturasValidas / 2;

    return (
        lecturas[mitad - 1] +
        lecturas[mitad]
    ) / 2.0;
}


// ======================================================
// BATERIA
// ======================================================

void actualizarLEDsBateria()
{
    uint32_t milivoltiosADC =
        analogReadMilliVolts(PIN_BATERIA);

    float voltajeADC =
        milivoltiosADC / 1000.0;

    float voltajeBateria =
        voltajeADC * FACTOR_DIVISOR_BATERIA;

    Serial.print("Bateria: ");
    Serial.print(voltajeBateria, 2);
    Serial.println(" V");

    if (voltajeBateria < VOLTAJE_BATERIA_BAJO)
    {
        digitalWrite(LED_ROJO, HIGH);
        digitalWrite(LED_VERDE, LOW);
    }
    else
    {
        digitalWrite(LED_ROJO, LOW);
        digitalWrite(LED_VERDE, HIGH);
    }
}


// ======================================================
// MODO AHORRO
// ======================================================

void entrarModoAhorro()
{
    if (!modoAhorro)
    {
        modoAhorro = true;

        Serial.println();
        Serial.println("================================");
        Serial.println("MODO AHORRO ACTIVADO");
        Serial.println("Sin movimiento durante 1 minuto");
        Serial.println("Medicion cada 5 segundos");
        Serial.println("================================");
        Serial.println();
    }
}


void salirModoAhorro()
{
    if (modoAhorro)
    {
        modoAhorro = false;

        Serial.println();
        Serial.println("================================");
        Serial.println("MOVIMIENTO DETECTADO");
        Serial.println("REGRESANDO A MODO NORMAL");
        Serial.println("Medicion cada 50 ms");
        Serial.println("================================");
        Serial.println();
    }
}


// ======================================================
// CALLBACK SERVIDOR BLE
// ======================================================

class ServidorCallbacks : public BLEServerCallbacks
{
    void onConnect(BLEServer* pServer)
    {
        dispositivoConectado = true;

        Serial.println();
        Serial.println("BLE CONECTADO");
        Serial.println();
    }

    void onDisconnect(BLEServer* pServer)
    {
        dispositivoConectado = false;

        Serial.println();
        Serial.println("BLE DESCONECTADO");
        Serial.println();

        pServer->getAdvertising()->start();
    }
};


// ======================================================
// CALLBACK RX
// ======================================================

class RXCallbacks : public BLECharacteristicCallbacks
{
    void onWrite(BLECharacteristic* pCharacteristic)
    {
        String valor = pCharacteristic->getValue();

        if (valor.length() > 0)
        {
            Serial.print("Android envio: ");
            Serial.println(valor);
        }
    }
};


// ======================================================
// INICIAR BLE
// ======================================================

void iniciarBLE()
{
    BLEDevice::init(NOMBRE_BLE);

    servidorBLE =
        BLEDevice::createServer();

    servidorBLE->setCallbacks(
        new ServidorCallbacks()
    );

    BLEService* servicio =
        servidorBLE->createService(
            SERVICE_UUID
        );

    caracteristicaTX =
        servicio->createCharacteristic(
            CHARACTERISTIC_TX,
            BLECharacteristic::PROPERTY_NOTIFY |
            BLECharacteristic::PROPERTY_READ
        );

    caracteristicaTX->addDescriptor(
        new BLE2902()
    );

    caracteristicaRX =
        servicio->createCharacteristic(
            CHARACTERISTIC_RX,
            BLECharacteristic::PROPERTY_WRITE |
            BLECharacteristic::PROPERTY_WRITE_NR
        );

    caracteristicaRX->setCallbacks(
        new RXCallbacks()
    );

    servicio->start();

    BLEAdvertising* advertising =
        BLEDevice::getAdvertising();

    advertising->addServiceUUID(
        SERVICE_UUID
    );

    advertising->setScanResponse(true);

    advertising->setMinPreferred(0x06);

    advertising->setMinPreferred(0x12);

    BLEDevice::startAdvertising();

    Serial.println("BLE iniciado");
    Serial.print("Nombre BLE: ");
    Serial.println(NOMBRE_BLE);
    Serial.println("Esperando conexion Android...");
}


// ======================================================
// ENVIAR BLE
// ======================================================

void enviarBLE(
    float tiempo,
    float distancia
)
{
    char datos[40];

    snprintf(
        datos,
        sizeof(datos),
        "%.3f,%.2f",
        tiempo,
        distancia
    );

    caracteristicaTX->setValue(datos);

    if (dispositivoConectado)
    {
        caracteristicaTX->notify();
    }
}


// ======================================================
// SETUP
// ======================================================

void setup()
{
    Serial.begin(115200);


    // ==================================================
    // HC-SR04
    // ==================================================

    pinMode(TRIG_PIN, OUTPUT);
    pinMode(ECHO_PIN, INPUT);

    digitalWrite(TRIG_PIN, LOW);


    // ==================================================
    // LEDS
    // ==================================================

    pinMode(LED_ROJO, OUTPUT);
    pinMode(LED_VERDE, OUTPUT);

    digitalWrite(LED_ROJO, LOW);
    digitalWrite(LED_VERDE, LOW);


    // ==================================================
    // ADC
    // ==================================================

    analogReadResolution(12);

    analogSetPinAttenuation(
        PIN_BATERIA,
        ADC_11db
    );


    // ==================================================
    // TIEMPO
    // ==================================================

    tiempoInicio = millis();

    ultimoMovimiento = millis();


    // ==================================================
    // BLE
    // ==================================================

    iniciarBLE();


    // ==================================================
    // BATERIA
    // ==================================================

    actualizarLEDsBateria();


    // ==================================================
    // INFORMACION
    // ==================================================

    Serial.println();

    Serial.println("================================");
    Serial.println("       GYM MOTION ESP32");
    Serial.println("================================");
    Serial.println();

    Serial.println("HC-SR04: OK");
    Serial.println("BLE: OK");
    Serial.println("Filtro: Mediana de 5 lecturas");

    Serial.print("Sensibilidad: ");
    Serial.print(
        TOLERANCIA_MOVIMIENTO,
        1
    );

    Serial.println(" cm");

    Serial.println("Modo normal: 50 ms");
    Serial.println("Modo ahorro: 5 segundos");

    Serial.println();
}


// ======================================================
// LOOP
// ======================================================

void loop()
{
    unsigned long ahora = millis();


    // ==================================================
    // BATERIA
    // ==================================================

    if (
        ahora - ultimaMedicionBateria >= 5000
    )
    {
        ultimaMedicionBateria = ahora;

        actualizarLEDsBateria();
    }


    // ==================================================
    // INTERVALO
    // ==================================================

    unsigned long intervaloActual;

    if (modoAhorro)
    {
        intervaloActual =
            INTERVALO_AHORRO;
    }
    else
    {
        intervaloActual =
            INTERVALO_NORMAL;
    }


    // ==================================================
    // MEDICION
    // ==================================================

    if (
        ahora - ultimaMedicion >=
        intervaloActual
    )
    {
        ultimaMedicion = ahora;


        // ----------------------------------------------
        // Medir
        // ----------------------------------------------

        float distancia =
            medirDistanciaFiltrada();


        if (distancia < 0)
        {
            return;
        }


        // ----------------------------------------------
        // Tiempo
        // ----------------------------------------------

        float tiempo =
            (
                millis() -
                tiempoInicio
            ) / 1000.0;


        // ----------------------------------------------
        // Primera medicion
        // ----------------------------------------------

        if (distanciaAnterior < 0)
        {
            distanciaAnterior =
                distancia;

            ultimoMovimiento =
                millis();
        }


        // ----------------------------------------------
        // Diferencia
        // ----------------------------------------------

        float diferencia =
            fabs(
                distancia -
                distanciaAnterior
            );


        // ----------------------------------------------
        // Movimiento
        // ----------------------------------------------

        if (
            diferencia >
            TOLERANCIA_MOVIMIENTO
        )
        {
            ultimoMovimiento =
                millis();

            if (modoAhorro)
            {
                salirModoAhorro();
            }
        }


        // ----------------------------------------------
        // Guardar distancia
        // ----------------------------------------------

        distanciaAnterior =
            distancia;


        // ----------------------------------------------
        // BLE
        // ----------------------------------------------

        enviarBLE(
            tiempo,
            distancia
        );


        // ----------------------------------------------
        // USB
        // ----------------------------------------------

        Serial.print(
            tiempo,
            3
        );

        Serial.print(",");

        Serial.println(
            distancia,
            2
        );


        // ----------------------------------------------
        // Inactividad
        // ----------------------------------------------

        if (
            !modoAhorro &&
            millis() -
            ultimoMovimiento >=
            TIEMPO_INACTIVIDAD
        )
        {
            entrarModoAhorro();
        }
    }
}
