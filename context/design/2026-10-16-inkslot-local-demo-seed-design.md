# InkSlot local demo seed — diseño

Fecha: 2026-10-16  
Estado: aprobado

## Objetivo

Crear un fixture reproducible para PostgreSQL local que permita abrir el enlace público `demo-token` y probar la experiencia Flutter pública sin insertar datos de producción ni depender de Google Calendar.

## Alcance

El fixture crea o restablece únicamente el conjunto identificado por el correo `demo@inkslot.local` y la referencia `demo-local-seed`:

- artista `Dodogio`;
- configuración de estudio `America/Guayaquil`, paso de 30 minutos, sin buffer, sin aviso mínimo y horizonte de 60 días;
- disponibilidad semanal de lunes a sábado, de 10:00 a 18:00;
- cliente demo;
- solicitud pendiente de 60 minutos con depósito verificado;
- token público plano `demo-token`, persistido exclusivamente como SHA-256 y con expiración amplia para pruebas locales.

No crea una cita confirmada, no conecta Google Calendar y no se ejecuta al arrancar NestJS ni en producción.

## Idempotencia y aislamiento

El seed se ejecuta mediante `prisma db seed`. El artista se identifica por un correo dedicado; la solicitud por `artistId`, `clientId` y `paymentReference`. Las ventanas y tokens del conjunto demo se reemplazan de forma determinista. Si una ejecución anterior de las pruebas creó una cita para esa solicitud, el seed elimina únicamente esa cita demo y sus outbox/auditorías asociadas antes de restablecer el estado pendiente.

## Flujo de datos

```text
seed.ts
  -> Artist + StudioSettings + WeeklyAvailability
  -> Client
  -> BookingRequest(PENDING)
  -> BookingToken(hash("demo-token"))
  -> GET /v1/public/reservations/demo-token
```

La consulta pública debe devolver `200` con estado `pending`, artista, duración, zona horaria y expiración. La disponibilidad pública puede devolver `CALENDAR_UNAVAILABLE` mientras no exista una conexión Calendar real; ese estado es esperado y no se simula con credenciales OAuth.

## Verificación

1. Ejecutar el seed dos veces y comprobar que no duplica artista, cliente, solicitud ni token.
2. Consultar `GET /v1/public/reservations/demo-token` y esperar `200`.
3. Consultar el enlace desde Flutter Web y comprobar que desaparece el estado “Sin conexión” de la bienvenida.
4. Ejecutar la suite API y el build web sin modificar el contrato existente.
