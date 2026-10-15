# InkSlot Platform Design

**Fecha:** 2026-10-15  
**Estado:** Aprobado por el usuario para planificación e implementación incremental  
**Método:** SDD — specs → tests → implementación → evidencia → commit

## Objetivo

Construir el MVP P0 de InkSlot como una plataforma localmente ejecutable para que un tatuador emita enlaces privados después de validar manualmente un anticipo, el cliente seleccione un horario seguro y la cita se persista en PostgreSQL con sincronización eventual a Google Calendar.

El producto conservará la fidelidad visual del prototipo entregado: composición mobile-first, isotipo D, paleta cobre sobre tinta, tipografías locales, estados, rueda curva, ticket 3D, splash y transiciones. El HTML, ZIP y PDF originales son referencias locales y no se subirán al repositorio.

## Restricciones aprobadas

- El workspace tendrá únicamente tres carpetas principales: `app/`, `api/` y `context/`.
- Frontend: Flutter Web 3.47.5, managed with FVM, + Provider + GoRouter.
- Backend: NestJS + TypeScript estricto.
- Persistencia: PostgreSQL local, sin Docker ni Docker Compose.
- ORM: Prisma, con migraciones SQL explícitas para capacidades de PostgreSQL no expresadas de forma segura en el modelo ORM.
- El prototipo y el PDF quedarán en `context/references/` y estarán excluidos de Git.
- No se implementarán pagos, validación automática de anticipos, chat, catálogo, múltiples estudios, app nativa ni funcionalidades P1 antes de estabilizar P0.
- Los valores de demostración del prototipo —fechas 2026, martes a sábado, 10:00–20:00, pausa y dirección de ejemplo— serán fixtures o configuración editable, no políticas permanentes.

## Fuentes y resolución de contradicciones

La jerarquía aplicada es: decisiones recientes del usuario, PDF técnico, ZIP del prototipo, HTML autocontenido y luego propuestas del SDD.

- El PDF menciona Riverpod; la decisión posterior del usuario, ADR-001 y `context/00-governance/AGENTS.md` fijan Provider. Se usará Provider.
- El PDF y el prototipo usan nombres y etiquetas en español; la API conservará estados internos estables en inglés (`pending`, `booked`, `cancelled`, entre otros) y la UI mostrará textos en español.
- El PDF propone `/public/reservations/:token/slots`; el contrato SDD más reciente define `/availability`. Se usará `/availability` como endpoint canónico.
- El PDF propone un `PATCH` amplio para citas; la spec de citas define acciones explícitas. Se usarán `PATCH /reschedule` y acciones `POST /cancel`, `POST /complete`, `POST /no-show`.
- El ORM estaba abierto; queda resuelto como Prisma + SQL.
- El entorno será local y PostgreSQL se administrará como servicio instalado en el equipo. No se añadirá infraestructura de contenedores.

Las decisiones que siguen abiertas para producción —marca definitiva, contacto obligatorio, política del anticipo, calendario real, TTL final, dominio, cookies y retención— no bloquean el desarrollo local, pero no se asumirán silenciosamente como políticas de negocio.

## Estructura del workspace

```text
app/
  assets/
  lib/
    core/
    features/
    shared/
  test/
api/
  prisma/
    migrations/
  src/
    common/
    modules/
    worker/
  test/
context/
  00-governance/
  adr/
  architecture/
  design/
  plans/
  product/
  quality/
  specs/
  tasks/
  references/              # archivos de entrada locales, ignorados por Git
```

No se crearán otras raíces de primer nivel.

## Arquitectura

```text
Flutter Web (Provider + GoRouter)
       │ HTTPS JSON / cookie admin / token público
       ▼
NestJS API (controllers → casos de uso → repositorios)
       ├── PostgreSQL local (fuente de verdad, auditoría, outbox)
       ├── Google Calendar (freeBusy y eventos)
       └── worker de outbox/reintentos
```

### Frontend

La app se organizará por feature, con capas ligeras de presentación, dominio y datos.

- `public_booking`: carga del token, resumen, calendario, horarios, revisión, confirmación, resultado y consulta posterior.
- `admin_auth`: login, sesión y logout.
- `admin_dashboard`: pendientes, próximas citas e incidencias.
- `admin_requests`: clientes, solicitudes, filtros, detalle, historial, renovar, revocar, cerrar y enlace.
- `admin_appointments`: lista, detalle, reprogramar, cancelar, completar, no-show y retry.
- `availability`: jornada, pausas, bloqueos, parámetros y zona horaria.
- `calendar`: estado de conexión, OAuth, reconexión y estado de sincronización.
- `core`: tema, tokens, fuentes, red, router, configuración, accesibilidad y manejo de errores.

Cada flujo usará `ChangeNotifier` propio. `Selector` y `Consumer` limitarán repintados en listas, rueda y dashboard. Los repositorios dependerán de interfaces y recibirán el cliente HTTP mediante Provider para que los tests puedan usar dobles.

GoRouter expondrá las rutas públicas `/r/:token`, `/r/:token/dates`, `/r/:token/times`, `/r/:token/review` y `/r/:token/result`, además de las rutas `/admin/*`. El token no se enviará a analytics ni se conservará como referrer.

El cliente HTTP será `package:http`, con un `Client` inyectable y configuración web de credenciales para la sesión administrativa. Las respuestas se convertirán a DTOs antes de llegar a los modelos de UI.

### Backend

NestJS se dividirá por dominio: `auth`, `clients`, `requests`, `availability`, `appointments`, `calendar`, `sync`, `audit`, `settings` y `health`.

La configuración global incluirá `ValidationPipe` con transformación, whitelist y rechazo de campos desconocidos. Guards separados protegerán `/admin/*`; los endpoints públicos aceptarán únicamente el token de solicitud. Throttling se aplicará especialmente a login, lectura pública, renovación y confirmación.

La autenticación administrativa usará contraseña Argon2id y cookie HttpOnly/Secure/SameSite en despliegue. La configuración local podrá desactivar `Secure` únicamente para HTTP local. CORS, origin y CSRF se configurarán según la topología final.

Prisma proveerá acceso tipado a las entidades. Las migraciones SQL habilitarán `btree_gist`, crearán el rango `tstzrange` y la restricción `EXCLUDE` para impedir solapamientos por artista. Las confirmaciones usarán transacciones y reintentos controlados para errores PostgreSQL `40001` y `40P01`.

El adaptador Calendar vivirá detrás de una interfaz. Guardará refresh tokens cifrados únicamente en servidor, consultará `freeBusy` con rango y zona explícitos y usará el mismo evento externo durante reprogramaciones. La sincronización después del commit se ejecutará mediante outbox durable con backoff, jitter, límite de intentos e incidencia visible.

## Flujo y reglas de negocio

1. El admin valida el anticipo fuera del sistema.
2. La API crea o referencia el cliente, registra la verificación manual y crea una solicitud `pending`.
3. La API genera un token opaco de al menos 256 bits, almacena solo su hash y establece vencimiento UTC.
4. El cliente accede sin cuenta y obtiene datos públicos mínimos.
5. La API calcula disponibilidad como intersección de jornada, restricciones, bloqueos, citas internas, Calendar, anticipación, horizonte, duración y buffer.
6. Si Calendar no es verificable, la API falla cerrado y no publica slots seguros.
7. La confirmación recibe `Idempotency-Key`, recalcula el slot, bloquea la solicitud, inserta la cita con rango excluyente, consume el token y crea el evento outbox dentro de una transacción.
8. Si el evento de Calendar falla después del commit, la cita conserva `confirmed` y `sync_pending`; el intervalo continúa bloqueado en PostgreSQL.
9. Renovar rota el token de forma atómica, invalida el anterior y conserva solicitud, anticipo e historial.

La hora se almacena en UTC y se muestra en `America/Guayaquil` o en la zona configurable del estudio. Los rangos son semiabiertos `[start, end)`.

## Estados de interfaz y errores

El flujo público cubrirá `loading`, `active`, `expired`, `cancelled`, `already_booked`, `no_slots`, `offline`, `calendar_unavailable`, `conflict_409`, `sync_pending` y la carga de confirmación.

El panel administrativo cubrirá login inválido, solicitudes vacías, vencidas, revocadas, agendadas, incidencias de sincronización, Calendar desconectado y reconexión pendiente.

- `410`: pantalla segura de enlace vencido o revocado, sin PII innecesaria.
- `409`: conserva contexto, muestra la hoja de conflicto y vuelve a consultar horarios.
- `503`: no ofrece ni confirma huecos con disponibilidad externa desconocida.
- `sync_pending`: comunica que la cita interna está reservada y que Calendar sigue pendiente.
- Offline: conserva selección y ofrece reintento sin prometer una reserva.

## Fidelidad visual

La referencia principal será el ZIP y su inventario de 38 capturas. Se incorporarán al frontend únicamente los assets necesarios y autorizados: isotipos D, iconos, ilustraciones flash y fuentes OFL.

Se conservarán:

- Paleta tinta `#0A0A0B`, profundo `#050505`, superficie `#131315`, hueso `#EEE9E0`, ceniza `#9B968E`, cobre `#C87939`, cobre claro `#D48A45` y tabaco `#241A12`.
- Estados verde `#8FBF9A`, amarillo `#E6C77A` y coral `#E2604C` solo semántico.
- Instrument Serif para titulares y fechas, Geist para interfaz y Geist Mono para horas/etiquetas.
- Radios, sombras, espaciado y objetivos táctiles definidos en `context/design` y en los tokens del prototipo.
- Splash `coinIn`, `sway`, `draw`, `fillin`, `drop`, `ripple`, `beam`, `halo`, `wm`; mosaico `up/dn`; rueda `pill`; ticket `tkIn` y tilt; éxito `stamp/ringOut`; sheets, toasts, shake, chain, tok, pulse y spin.

Las animaciones se implementarán con `AnimationController`, `Tween`, `Transform/Matrix4`, `CustomPainter` y gestos. `MediaQuery.disableAnimations` producirá una variante estable y accesible. Las diferencias inevitables por rendimiento web se documentarán en `context/quality/visual-parity.md` antes de sustituir cualquier efecto.

## Orden de implementación

Cada fase entrega software ejecutable y verificable.

1. **Bootstrap local:** raíz `app/api/context`, Git, `.gitignore`, configuración local, PostgreSQL local, Flutter shell, Nest health check y documentación de comandos.
2. **Fundación visual:** tokens, fuentes, SVG, tema, Provider, GoRouter, splash, login visual y navegación base.
3. **Persistencia y auth:** Prisma, migraciones, constraint de rangos, auditoría mínima, login, guards y sesión.
4. **Disponibilidad:** configuración de jornada/bloqueos, motor puro con tests RD-01..RD-12 y pantalla Agenda.
5. **Solicitudes:** clientes, anticipo manual, solicitudes, hash/TTL/rotación de tokens y panel de enlaces.
6. **Reserva pública:** datos por token, calendario de fechas, rueda curva, revisión, reduced motion y estados públicos.
7. **Confirmación:** transacción, idempotencia, exclusión, concurrencia, conflicto 409 y resultado.
8. **Calendar y outbox:** OAuth, freeBusy, crear/actualizar/eliminar evento, retry, reconectar e incidencias.
9. **Administración y endurecimiento:** citas, reprogramación, cancelación, no-show, filtros, accesibilidad, goldens, E2E, OpenAPI, CI y matriz completa.

No se implementará una pantalla que aparente persistir datos mientras el endpoint real no exista.

## Pruebas y Definition of Done

API: Jest para motor de disponibilidad, tokens, auth, estados de cita y adaptador Calendar fake; integración con PostgreSQL local para migraciones, constraint GiST, transacciones concurrentes, idempotencia y outbox; Supertest para 401/403/409/410/422/503.

Flutter: unit tests de ViewModels/repositorios; widget tests para loading, empty, error y acciones; golden tests en 390×844 con fuentes cargadas; pruebas de deep link, back/forward, teclado, semántica y targets de 44 px; integración en navegador real y revisión manual de Safari iOS para gestos/animaciones.

Cada tarea debe citar spec, RF/RD/AC/UI o ADR; incluir errores, loading, empty y accesibilidad; mantener secretos fuera del repo; actualizar evidencia en `context/tasks`; y terminar en un commit enfocado.

## Git y publicación

Se usará Trunk-Based Development sobre `main`, con ramas cortas solo cuando sean necesarias y commits pequeños con prefijos `feat`, `fix`, `test`, `docs`, `refactor` o `chore` y alcance `app`/`api`/`context`.

El remoto previsto es `https://github.com/pierorellana/proyect_insklot.git`. Antes del push se comprobará que no entren `context/references/InkSlot_Prototipo.html`, `context/references/InkSlot_Prototipo.zip`, `context/references/InkSlot_Documentacion_Tecnica.pdf`, secretos ni artefactos generados.

## Criterio de éxito

El MVP queda listo cuando una solicitud con anticipo validado es recuperable, un cliente puede confirmar sin cuenta, dos confirmaciones concurrentes no producen doble reserva, toda cita distingue estado interno de sincronización, Calendar falla cerrado antes de confirmar y la UI reproduce los estados y composición del prototipo en los viewports definidos.
