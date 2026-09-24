# Arquitectura de FitBack (MVP)

## Componentes

```
+------------+        BLE         +----------+        Ultrasonido        +-----------+
|  Teléfono  |  <-------------->  |  ESP32   |  <--------------------->  |  Pila de  |
|  (App)     |   (distancia mm)   |  (NimBLE)|      (distancia en mm)    |  pesos    |
+------------+                    +----------+                           +-----------+
      |
      | QR
      v
+------------+
| Landing    |
| page (web) |
+------------+
```

## Responsabilidades

### Teléfono (App Android)
- Escanear QR o recibir deep link con ID de máquina.
- Gestionar permisos de Bluetooth.
- Escanear, conectar y suscribirse a notificaciones BLE.
- Recibir distancia en mm y detectar repeticiones.
- Mostrar guía visual (cuenta de reps, rango objetivo, feedback).
- Guardar resumen de sesión localmente.
- Liberar la conexión BLE al terminar.

### ESP32 (firmware del socio)
- Leer sensor ultrasónico y calcular distancia.
- Exponer un servicio BLE con al menos:
  - characteristic `DISTANCE` (notify): distancia en mm.
  - characteristic `MACHINE_ID` (read): ID único de la máquina.
  - characteristic `COMMAND` (write): reservada para calibración/reset.
- Publicar datos por advertising incluso estando conectado.
- Implementar regla de "nueva conexión gana": al conectar un nuevo central, cerrar la conexión anterior.

### QR
- Apunta a `https://tudominio.com/m/<MACHINE_ID>`.
- La landing page ofrece:
  - Botón "Descargar APK".
  - Botón "Abrir en la app" (`fitback://machine?id=<MACHINE_ID>`).

## Flujo de datos

1. ESP32 mide distancia cada ~50 ms.
2. Envía el valor por BLE como `uint16` en mm mediante notificaciones.
3. App recibe el valor, lo suaviza y detecta picos/valles para contar reps.
4. App compara contra el rango de movimiento del perfil de máquina.
5. App muestra feedback visual en tiempo real.

## Decisiones de diseño

| Decisión | Justificación |
|----------|---------------|
| Offline-first | Conectividad inestable en gimnasios locales. |
| Sin servidor en MVP | Reduce costo, complejidad y dependencias. |
| Sin autenticación en MVP | Menos fricción para el usuario del gimnasio. |
| QR como identificador | Barato, no requiere NFC, fácil de reemplazar. |
| Sensor en la primera placa | Siempre se mueve sin importar el peso seleccionado. |
| "Nueva conexión gana" | Evita que una sesión zombie bloquee la máquina. |

## Límites del MVP

- No se detecta el peso seleccionado automáticamente.
- No hay historial en la nube.
- No hay cuenta de usuario.
- No se soporta iOS.
- No hay dashboards para el dueño del gimnasio.

## Próximos pasos técnicos

1. Definir UUIDs del servicio y characteristics BLE.
2. Definir formato exacto del paquete de distancia.
3. Definir catálogo de máquinas y perfiles.
4. Elegir stack mobile (React Native / Flutter / nativo).
5. Crear landing page de descarga.
