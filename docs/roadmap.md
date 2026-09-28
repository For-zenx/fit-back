# Roadmap

## MVP (actual)

Objetivo: validar el flujo completo en un gimnasio local.

- [x] Firmware baseline (HC-SR04 + Bluetooth clasico, Wokwi)
- [x] Driver CP2102 instalado y aparato enviando datos
- [ ] Migrar firmware a BLE/NimBLE segun `docs/ble-protocol.md`
- [ ] App Flutter: QR/deep link -> conexion BLE -> conteo de reps ->
      resumen local
- [ ] Catalogo inicial de perfiles de maquina + auto-calibracion
- [ ] Landing page con descarga de APK
- [ ] Registro anonimo (device_id + gym_id) y token de licencia
- [ ] Validacion en gimnasio real

## Fase 2 — plataforma minima

- [ ] VPS: API de licencias (emision/renovacion de tokens firmados)
- [ ] VPS: API de sync (sesiones + perfiles de maquina agregados)
- [ ] Panel de control: usuarios por gimnasio, estado de pago,
      suspension por gym_id
- [ ] Google Sign-In (migrar historial entre telefonos)
- [ ] Perfiles adaptativos refinados en servidor (p5/p95 agregado)
- [ ] Auto-update del APK (`/latest.json` + descarga in-app)
- [ ] OTA del firmware (decidir ArduinoOTA vs BLE OTA)
- [ ] Peso ingresado manualmente por el usuario

## Fase 3 — crecimiento

- [ ] Entrenador: recomendacion de rutinas semanales
- [ ] Funciones con IA (DeepSeek) sobre las metricas acumuladas
- [ ] Publicacion en Google Play
- [ ] Escalamiento multi-gimnasio / multi-ciudad
- [ ] Posible deteccion de peso (hardware adicional, por evaluar)

## Principios transversales

- Offline-first: el ejercicio nunca depende de internet.
- El VPS solo ve datos agregados y licencias, nunca es critico para usar
  la maquina en el momento.
- Los perfiles calibrados de maquina son el activo de datos del producto.
