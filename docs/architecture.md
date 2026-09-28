# Arquitectura de FitBack

## Vision del producto

FitBack convierte cualquier maquina de gimnasio en una **maquina inteligente**
(retrofit tipo Virtuagym Connect, pero abierto): un ESP32 + sensor ultrasonico
mide el movimiento y una app Android guia al usuario en tiempo real.

- **Producto principal (MVP)**: hardware + app que cuenta reps y guia el rango
  de movimiento. Funciona con cualquier maquina donde una parte se mueva de
  forma repetible (placas apiladas, brazos de polea, asientos, etc.).
- **Producto secundario (fases 2-3)**: metricas, historial, entrenador,
  panel de administracion y licenciamiento por gimnasio.

## Componentes

```
+-----------+   BLE   +--------+   Ultrasonido   +------------+
| Telefono  | <-----> | ESP32  | <------------> | Parte movil|
| (Flutter) |         | NimBLE |                | de maquina |
+-----------+         +--------+                +------------+
     |  |
     |  | HTTPS (cuando hay internet)
     |  v
     | +-----------+     +----------+
     | | VPS minimo| --> | Panel de |
     | | API + DB  |     | control  |
     | +-----------+     +----------+
     |
     | QR / deep link
     v
+-----------+
| Landing   |
| (descarga |
| APK)      |
+-----------+
```

### Telefono (App Flutter)

- Escanear QR o recibir deep link con `gym_id` + `machine_id`.
- Gestionar permisos de Bluetooth y conectar por BLE.
- Recibir distancia (cm), suavizarla y detectar picos/valles = reps.
- Comparar contra el rango del perfil de maquina (con auto-calibracion).
- Guardar sesiones en SQLite local (offline-first) y sincronizar al VPS.
- Validar token de licencia localmente (expiracion embebida, ver abajo).

### ESP32 (firmware)

- Leer HC-SR04 y calcular distancia en cm a 20 Hz.
- Servicio BLE con `DISTANCE` (notify), `MACHINE_ID` (read),
  `COMMAND` (write). Contrato completo en `docs/ble-protocol.md`.
- Nombre unico `FITBACK-XXXX` (ultimos del MAC).
- Regla "nueva conexion gana": max 1 conexion central.
- Baseline actual en `firmware/sensor/sensor.ino`; migracion a NimBLE
  en curso.

### VPS minimo (fase 2)

Un solo servidor barato (~$5/mes) o servicios free-tier. Tres piezas:

1. **API de licencias**: emite tokens firmados `{user_id, gym_id, exp}`.
2. **API de sync**: recibe sesiones y perfiles de maquina agregados.
3. **Panel de control**: lista de usuarios por gimnasio, estado de pago,
   boton para suspender renovacion de tokens de un `gym_id`.

La app NO habla con el VPS durante el ejercicio — solo con el ESP32 por BLE.

### Landing + QR

- QR por maquina: `https://tudominio.com/g/<GYM_ID>/m/<MACHINE_ID>`.
- La landing ofrece "Descargar APK" y "Abrir en la app"
  (`fitback://machine?id=<MACHINE_ID>&gym=<GYM_ID>`).
- El `gym_id` queda asociado al usuario al registrarse: es la etiqueta
  para facturacion y corte de servicio.

## Modelo de licenciamiento (corte por falta de pago)

- Al registrarse, la app recibe un **token firmado** con fecha de
  expiracion (ventana de ~30 dias).
- La app lo renueva automaticamente cuando tiene internet.
- Si el gimnasio no paga, el VPS deja de renovar tokens de ese `gym_id`.
- Al vencer el token, la app se bloquea **sin necesidad de internet**:
  la expiracion esta dentro del token.
- Corte total (incluye producto principal): es el apalancamiento real.
- Sin login fuerte en MVP: registro anonimo con `device_id` + `gym_id`
  basta para la trazabilidad. Google Sign-In llega en fase 2 para que el
  usuario conserve su historial al cambiar de telefono.

## Perfiles de maquina y auto-calibracion

Cada maquina tiene un perfil `{tipo, rango_min, rango_max, orientacion}`.

- **Primera sesion**: el usuario hace 2-3 reps de calibracion y la app
  aprende el rango observado.
- **Refinamiento continuo**: cada sesion actualiza el perfil con
  percentiles (p5/p95 del rango observado). Converge solo tras ~10 sesiones.
- **Agregado en VPS**: se suben solo min/max/count por maquina (no la
  sesion cruda), construyendo un catalogo de perfiles que mejora con el
  tiempo. Ventaja competitiva: un competidor no puede copiarlo sin
  instalar hardware.

## Flujo de datos

1. ESP32 mide distancia cada ~50 ms y notifica por BLE.
2. App suaviza la senal y detecta reps contra el perfil de la maquina.
3. Sesion se guarda en SQLite local.
4. Con internet: la app sube la sesion y renueva su token de licencia.

## Decisiones de diseno

| Decision | Justificacion |
|----------|---------------|
| Offline-first | Gimnasios con internet inestable o nulo |
| BLE (NimBLE) | Estandar moderno; BT clasico deprecado en moviles |
| Licencia por expiracion | Corta servicio sin internet; dificil de evadir |
| Registro anonimo + gym_id | Cero friccion; trazabilidad suficiente |
| SQLite local + sync | App nunca depende del VPS para funcionar |
| VPS minimo | $5/mes; no mantener conexiones, solo API |
| Distancia en cm | Como lo implemento el firmware original |
| Un QR por maquina con gym_id | Una sola APK para todos los gimnasios |
| Auto-calibracion por sesion | No requiere medir fisicamente cada maquina |
| "Nueva conexion gana" | Evita sesiones zombie bloqueando la maquina |

## Limites del MVP

- No detecta el peso seleccionado (el usuario lo anota manual).
- Sin autenticacion fuerte ni cuentas multi-dispositivo.
- Sin historial en la nube (solo local).
- Solo Android, APK sideload (sin Google Play).
- Sin dashboard web aun (el panel llega en fase 2).

## Fases (detalle en `docs/roadmap.md`)

- **MVP**: sensor BLE + app reps + QR + licencias basicas.
- **Fase 2**: VPS (API licencias + sync + panel), Google auth,
  perfiles adaptativos, auto-update del APK, OTA del firmware.
- **Fase 3**: entrenador/rutinas, IA (DeepSeek), Google Play,
  multi-gimnasio a escala.
