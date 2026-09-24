# Contribuyendo a FitBack

Guía de trabajo mínima para el equipo del MVP.

## Resumen del proyecto

FitBack es una app Android que guía al usuario en máquinas de gimnasio con peso apilado. Se conecta por BLE a un ESP32 equipado con un sensor ultrasónico. No hay servidor ni autenticación en el MVP.

- **Repo**: `https://github.com/For-zenx/fit-back`
- **Rama principal**: `main` (protegida; los cambios entran solo por Pull Request)
- **App mobile**: Android-only (stack por definir: React Native / Flutter / nativo)
- **Firmware**: ESP32 + NimBLE (a cargo del socio)

## Estructura del repo

```
fitback/
├── README.md
├── CONTRIBUTING.md
├── .gitignore
├── docs/                  # Arquitectura, protocolos, decisiones
│   ├── architecture.md
│   ├── ble-protocol.md    # por definir
│   ├── machine-profiles.md # por definir
│   └── ui-wireframes.md   # por definir
├── src/                   # código de la app cuando se elija stack
└── assets/                # logos, iconos, plantillas QR
```

## Configuración local

Por ahora el MVP es solo documentación. Para contribuir a los docs solo hace falta Git y un editor de texto.

El stack mobile y la guía de setup se agregarán una vez que se elija la tecnología.

## Flujo de trabajo (Git)

1. Actualizá `main` antes de empezar:

```bash
git checkout main
git pull origin main
```

2. Creá una rama descriptiva:

```bash
git checkout -b feat/descripcion-corta
# o docs/, fix/, refactor/, test/
```

3. Hacé commits pequeños con mensajes claros:

```text
tipo(alcance): descripción

Ejemplos:
- docs(ble): define UUIDs del servicio de distancia
- feat(app): agrega pantalla de escaneo de QR
- fix(sensor): corrige lectura de distancia negativa
```

4. Pusheá la rama y abrí un Pull Request hacia `main`:

```bash
git push -u origin feat/descripcion-corta
```

5. **No hagas merge directo a `main`**. Francisco revisa y mergea.

## Seguimiento de tareas

No usamos Trello ni Jira en el MVP. Usamos una de dos opciones:

- **GitHub Issues**: una issue por tarea o bug.
- **`docs/tasks.md`**: lista de tareas activas si preferimos mantener todo en el repo.

En el PR, incluí una referencia a la issue o tarea:

```text
Relacionado con: #3
```

Si no hay issue, describí en el cuerpo del PR **qué se está haciendo y por qué**.

## Pull Requests

- Título claro: `feat: agrega guía de contribución`.
- Descripción corta: qué cambia y por qué.
- Si el cambio toca el protocolo BLE, documentá el formato y avisá al socio.
- Si cambiás algo del hardware o del QR, actualizá `docs/architecture.md`.
- No commitear `.env`, keystores, ni credenciales.

## Definition of Done

Antes de pedir review:

- [ ] El cambio hace lo que dice el PR.
- [ ] No se commitearon secrets ni archivos de build.
- [ ] Se actualizó la documentación afectada (`README.md`, `docs/`, etc.).
- [ ] No se rompe el contrato BLE ya acordado (cuando exista).
- [ ] Se probó localmente lo que se pueda probar.

## Reglas de convivencia

- Trabajar solo sobre tareas asignadas o acordadas.
- Si hay duda o un tradeoff, preguntar antes de asumir.
- No refactorizar código ajeno sin consultar.
- Mantener los cambios quirúrgicos: solo lo que pide la tarea.
