# Diseño: panel administrativo de solicitudes

**Fecha:** 2026-10-16  
**Estado:** aprobado para planificación  
**Alcance:** slice T-011 — login administrativo, solicitudes y enlaces

## Objetivo

Implementar en Flutter Web el flujo administrativo que permite iniciar sesión, crear una solicitud de reserva real, mostrar el enlace privado una sola vez, copiarlo o compartirlo, consultar solicitudes y administrar el detalle de cada solicitud. La UI usará Provider, consumirá la API NestJS existente y respetará los tokens visuales y estados del prototipo.

## Dependencias

- API de autenticación: `POST /v1/auth/login`, `GET /v1/auth/me`, `POST /v1/auth/logout`.
- API de solicitudes: creación, listado, detalle, renovación, revocación y cierre.
- PostgreSQL local y Prisma para los nuevos campos de contacto y referencia de anticipo.
- Flutter Web 3.47.5 mediante FVM.
- `package:http` para HTTP y cookies de sesión web.
- Provider y GoRouter ya definidos en la aplicación.

## Corrección de contrato y persistencia

El prototipo solicita canal de contacto y referencia del anticipo, mientras que el primer contrato administrativo solo tenía `email`, `phone` y `depositVerified`. Para conservar la información que el estudio captura visualmente, se amplía el contrato:

- `Client.contactChannel` opcional, con valores `whatsapp`, `instagram`, `email` o `phone`.
- `Client.contactValue` opcional, texto validado de máximo 320 caracteres.
- `BookingRequest.paymentReference` opcional, texto validado de máximo 160 caracteres.

Los campos existentes `email` y `phone` no se eliminan. Las solicitudes antiguas y clientes existentes siguen siendo válidos. La UI nueva enviará `contactChannel` y `contactValue`; el backend conservará también los campos normalizados `email` o `phone` cuando el canal lo permita.

Reglas:

- `contactChannel` y `contactValue` deben llegar juntos o ambos omitirse.
- Para `email`, `contactValue` debe ser un email válido.
- Para `whatsapp` y `phone`, `contactValue` debe ser un teléfono no vacío de máximo 32 caracteres.
- Para `instagram`, `contactValue` debe ser un identificador no vacío de máximo 64 caracteres.
- `paymentReference` es opcional, se recorta y no se devuelve en rutas públicas.
- `depositVerified` continúa siendo obligatorio y debe ser `true` para crear o renovar un enlace utilizable.

La migración será aditiva y nullable para no invalidar registros existentes.

## API administrativa consumida

La aplicación usará los contratos existentes:

- `POST /v1/auth/login` → usuario y cookie HttpOnly.
- `GET /v1/auth/me` → sesión actual.
- `POST /v1/auth/logout` → revoca la sesión.
- `POST /v1/admin/booking-requests` → crea solicitud y devuelve el enlace claro únicamente en esa respuesta.
- `GET /v1/admin/booking-requests?status=&cursor=` → lista paginada.
- `GET /v1/admin/booking-requests/:id` → detalle e historial seguro.
- `POST /v1/admin/booking-requests/:id/renew` → rota el token.
- `POST /v1/admin/booking-requests/:id/revoke` → cancela la solicitud y revoca el enlace.
- `POST /v1/admin/booking-requests/:id/close` → cierra la solicitud y revoca el enlace.

Los errores se convierten desde `{ error: { code, message } }` a un error seguro de presentación. `401 AUTH_INVALID` limpia el estado local y redirige a login. Las respuestas no se guardan en local storage.

## Arquitectura Flutter

### Cliente HTTP

`ApiClient` encapsulará `package:http`, la base `/v1`, serialización JSON, `Content-Type`, credenciales de navegador y errores tipados. En Flutter Web se usará un cliente con cookies habilitadas para que la cookie HttpOnly de sesión acompañe las peticiones administrativas.

### Auth

`AuthRepository` implementará login, sesión actual y logout. `AdminSessionController` será un `ChangeNotifier` con estados `checking`, `signedOut`, `signedIn` y `error`. El router escuchará el controlador para proteger `/admin/*` sin bloquear las rutas públicas.

### Solicitudes

`BookingRequestsRepository` implementará el contrato administrativo y mapeará JSON a modelos Dart. `BookingRequestsController` será un `ChangeNotifier` para listado, detalle, creación y acciones de ciclo de vida, con estados independientes `loading`, `ready`, `empty`, `submitting` y `error`.

El token claro de creación o renovación permanecerá solo en memoria dentro del resultado de navegación hacia `LinkReadyPage`. No formará parte de la ruta, query string, logs, analytics ni almacenamiento persistente.

## Navegación

Se añadirán estas rutas declarativas:

```text
/admin/login
/admin
/admin/requests
/admin/requests/new
/admin/requests/:id
/admin/requests/link
```

`/admin` redirigirá a `/admin/requests` porque el endpoint de dashboard aún no existe. `LinkReadyPage` se abrirá después de una creación o renovación mediante estado efímero; si se recarga sin enlace en memoria, mostrará una salida segura hacia solicitudes en lugar de inventar un token.

## Pantallas y componentes

### Login

- Logo e identidad InkSlot sobre fondo tinta.
- Campos email y contraseña.
- Botón principal con estado deshabilitado/loading.
- Error de credenciales inline y animación de shake compatible con reduced motion.
- Reintento sin perder el email.

### Solicitudes

- Shell administrativo responsive: navegación lateral en escritorio y navegación compacta en móvil.
- Encabezado, CTA `Nueva solicitud` y filtros por `Pendientes`, `Agendadas`, `Vencidas` y `Canceladas`.
- Estado loading con skeleton, estado vacío con CTA, error con reintento y lista real paginada.
- Tarjetas con nombre/contacto, duración, estado de solicitud y estado del enlace.
- Tap/teclado abre detalle sin perder el filtro.

### Nueva solicitud

- Nombre del cliente.
- Selector de canal: WhatsApp, Instagram, email o teléfono.
- Campo de contacto adaptado al canal.
- Confirmación visual de anticipo validado.
- Referencia opcional del anticipo.
- Duración con stepper y opciones rápidas.
- Restricciones opcionales: días, rango de fechas, franja horaria y TTL.
- Validaciones inline, submit bloqueado durante la petición y mensajes seguros de API.

### Enlace listo

- Estado de éxito con URL completa visible para copiar.
- `Copiar enlace` usando clipboard y confirmación toast.
- `Compartir enlace` usando Web Share cuando el navegador lo soporte y clipboard como fallback.
- CTA para volver a solicitudes.
- No se vuelve a recuperar ni reconstruir el token después de abandonar la pantalla.

### Detalle

- Datos administrativos del cliente y solicitud.
- Estado del enlace activo, vencido, revocado o consumido.
- Historial de auditoría seguro.
- Renovar con nuevo enlace y navegación a `LinkReadyPage`.
- Revocar y cerrar mediante hoja de confirmación.
- Estados incompatibles `BOOKED` y terminales mostrados según errores reales de la API.

## Fidelidad visual y accesibilidad

- Colores: tinta `#0A0A0B`, superficie `#131315`, hueso `#EEE9E0`, secundario `#A7A29A`, cobre `#C87939`, éxito `#8FBF9A`, aviso `#E6C77A`, error `#E2604C`.
- Tipografías: Geist para UI, Geist Mono para etiquetas/horas/enlaces e Instrument Serif para titulares.
- Radios, espaciado, sombras y curvas se tomarán de `InkSlotTokens` ya implementado.
- Objetivos táctiles mínimos de 44 px, foco visible, labels semánticos y contraste AA donde sea factible.
- Las transiciones de pantalla, hojas, toasts y estados de carga respetarán las duraciones existentes y `MediaQuery.disableAnimations`.
- No se usarán screenshots como widgets ni datos simulados en controles de persistencia.

## Estados y manejo de errores

| Contexto | Estado | Comportamiento |
|---|---|---|
| Sesión | checking | Splash corto o indicador discreto mientras se consulta `/auth/me`. |
| Login | error | Mensaje seguro, formulario editable y reintento. |
| Solicitudes | loading | Skeleton de tarjetas. |
| Solicitudes | empty | Mensaje y CTA para crear la primera solicitud. |
| API | network error | Aviso de conexión y botón reintentar. |
| API | 401 | Limpiar sesión y volver a `/admin/login`. |
| Crear/renovar | submitting | Botón bloqueado, indicador y sin doble envío. |
| Crear | success | Navegar a enlace listo con token efímero. |
| Acción lifecycle | 409/400 | Mostrar mensaje de negocio y refrescar detalle. |
| Enlace | expired/revoked | Mostrar estado del backend sin exponer secretos adicionales. |

## Pruebas

- API: migración, validación de canal/contacto/referencia y persistencia de respuestas administrativas.
- Dart: `ApiClient`, serialización, errores HTTP, auth repository y requests repository con cliente HTTP falso.
- Provider: login, sesión expirada, carga, vacío, error, creación, renovación y acciones idempotentes.
- Widget: login/error, formulario/validación, filtros/lista, empty/error, enlace/copy/share fallback y detalle.
- Router: deep link público intacto, protección admin y redirección por sesión.
- Verificación Flutter con FVM: format, analyze y test.

## Fuera de alcance

- Dashboard real, citas, agenda, incidencias y configuración de Calendar.
- Endpoint público de disponibilidad.
- Confirmación de cita, idempotencia y sincronización outbox.
- Envío automático por correo, WhatsApp o Instagram.
- Persistencia de sesión en local storage.

## Referencias trazables

- `context/specs/01-auth-and-roles.md`
- `context/specs/02-clients-and-deposits.md`
- `context/specs/03-booking-requests-and-tokens.md`
- `context/specs/07-admin-dashboard-and-config.md`
- `context/specs/08-public-flutter-experience.md`
- `context/design/prototype-inventory.md`
- `context/design/design-system-and-motion.md`
- `context/adr/ADR-003-auth-and-public-tokens.md`
- `context/adr/ADR-004-design-fidelity-and-motion.md`
