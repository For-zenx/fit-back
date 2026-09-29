# Spec de la app - FitBack (MVP)

Stack: **Flutter** (Android). Estado: **Riverpod**. Rutas/deep links:
**go_router** + **app_links**. Local DB: **drift** (SQLite). BLE:
**flutter_blue_plus**. Graficas: **fl_chart** (o CustomPainter para la
onda en vivo). Codigo en ingles, UI en espanol, tema oscuro.

Referencia visual: Virtuagym Connect — fondo negro, contador de reps
gigante, onda de movimiento en vivo con punto brillante, resultados con
anillo de score y lista por set.

## Pantallas

### 1. Escaner QR / entrada

- Camara escanea `https://tudominio.com/g/<GYM_ID>/m/<MACHINE_ID>`.
- Tambien acepta deep link `fitback://machine?id=<MACHINE_ID>&gym=<GYM_ID>`.
- Fallback: entrada manual del codigo de maquina.
- Primera vez: pasa a registro. Con registro existente: va a conexion.

### 2. Registro (una sola vez)

- Campos: nombre/apodo, edad, peso (kg) — inputs para rutinas futuras.
- Por debajo: `device_id` + `gym_id` automaticos.
- Al enviar (con internet): el VPS devuelve token firmado
  `{user_id, gym_id, exp}` que la app guarda localmente.
- Sin internet en el primer registro: modo "pendiente de activar" —
  el producto principal funciona pero se pide activar lo antes posible.

### 3. Conexion BLE

- Escanea dispositivos `FITBACK-*`, conecta, suscribe a `DISTANCE`.
- **Chequeo de licencia aqui** (y al abrir la app): token vencido ->
  pantalla de bloqueo "Contacta a tu gimnasio". Con internet, renovacion
  silenciosa en background.
- Estados visibles: buscando / conectando / listo / error.

### 4. Sesion en vivo (pantalla estrella)

Layout (tema oscuro, elementos grandes, legible a 2 metros):

- Arriba: X (salir), **timer** del set.
- Fila de datos: **set actual** | **REPS** (numero gigante) | **kg**
  (peso ingresado manual, editable entre sets).
- Centro: **onda de movimiento en vivo** — la distancia dibujada como
  curva con punto brillante en la posicion actual; puntos marcados en
  cada pico/valle detectado (referencia Virtuagym).
- Abajo: grafica de distancia (vista tecnica, colapsable) y botones:
  "Terminar set" / "Pausa".
- Modalidad (elegida antes de iniciar): **Normal / Excentrico /
  Concentrico**. En modos con tempo objetivo, la onda muestra la fase
  actual y la app indica "mas lento" / "mas rapido" por color o texto.
- Entre sets: temporizador de descanso con boton "Siguiente set".

### 5. Resumen de sesion

- "Buen trabajo" + anillo de score (regularidad de tempo/ROM).
- Totales: reps, sets, kg levantados, duracion.
- Lista por set: reps + score individual.
- Boton "Finalizar" -> guarda en SQLite y libera BLE.

### 6. Historial + estadisticas

- Lista de sesiones pasadas (fecha, maquina, reps, kg).
- **Estadisticas personales** calculadas localmente desde el historial:
  sesiones por semana, reps totales, kg acumulados, maquina mas usada,
  progreso de score por maquina. Todo derivado de SQLite — sin servidor.

### 7. Ajustes

- Datos del perfil (nombre, edad, peso).
- Version de la app.
- Entrada al modo dev (oculto, ej. 7 toques sobre la version).
- **La licencia NO se muestra al usuario**: es asunto del gimnasio.
  Solo aparece la pantalla de bloqueo si el token vence; el detalle de
  dias restantes vive en el panel del VPS (fase 2) y en el modo dev.

## Pipeline de deteccion de reps

1. Entrada: `distancia_cm` a ~20 Hz desde BLE.
2. Suavizado: mediana movil (ventana 5) — igual que el firmware.
3. Deteccion de picos/valles con **histeresis**: la senal debe recorrer
   >= umbral (ej. 15% del rango calibrado) desde el ultimo extremo para
   confirmar cambio de direccion. Un valle+pico completos = 1 rep.
4. Fases: subida de distancia = fase A, bajada = fase B; mapeo a
   concentrica/excentrica segun el tipo de maquina. En modos tempo, se
   mide duracion de cada fase contra objetivo (ej. 3-1-0).
5. Auto-calibracion: primeras 2-3 reps fijan rango_min/max; cada sesion
   refina con p5/p95 de lo observado. El perfil viaja con el machine_id.

## Datos locales (drift/SQLite)

Tablas: `users`, `machines` (id, gym_id, tipo, rango_min/max),
`sessions` (id, machine_id, fecha, score, duracion),
`sets` (id, session_id, reps, kg, tempo_medio), `license_tokens`.

## Licencia

- Chequeo en: (a) apertura de app, (b) antes de conectar BLE.
- Renovar cuando hay internet; offline funciona hasta vencer `exp`.
- Token vencido -> bloqueo total de la app (producto incluido).

## Modo dev (critico para pruebas en gimnasio real)

Acceso oculto desde ajustes. Es nuestra herramienta de campo:

- **Fuente de datos**: interfaz `DistanceSource` con dos
  implementaciones: `BleDistanceSource` (real) y
  `SimulatedDistanceSource` (onda senoidal + ruido, o replay de CSV
  grabado). Desarrollar todo sin hardware.
- **Grabacion de sesiones**: guardar la senal cruda (t, distancia) de
  sesiones reales en el gimnasio para reproducirlas luego en casa —
  asi comparamos el algoritmo contra datos verdaderos.
- **Exportar datos**: volcar sesiones y senales crudas a CSV/archivo
  para traerlos al repo y analizarlos.
- **Debug de licencia**: ver token actual, expiracion, forzar renovacion.
- **Overrides**: forzar machine_id/gym_id, saltar pantalla de licencia.

## Fuera del MVP

Google auth, sync al VPS, panel, OTA, notificaciones, wearables/HR —
ver `docs/roadmap.md`. La app debe estar estructurada para agregar sync
despues sin reescribir el modelo local.
