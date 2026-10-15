# Flujos / casos de uso (CU-01 a CU-14)

## Cliente (CU-07..CU-10)
`Link válido → splash D animado → bienvenida flash → calendario de fechas elegibles → rueda de horarios → ticket de revisión (3D) → confirmar → estado sincronizada/pendiente → ver reserva`.

- Token vencido → estado `vencido` (HTTP 410), CTA a estudio, sin revelar datos sensibles.
- Token revocado/cancelado → `cancelado`; ya agendado → `agendado`, detalle mínimo (no segunda cita).
- Fecha sin huecos → `sin_horarios`; Calendar no verificable → `error_agenda`; fallo de red → `sin_red`.
- Conflicto entre ver y confirmar → HTTP 409, conservar contexto y actualizar slots.
- Confirmar puede terminar `sync_pending`: cita interna registrada, Calendar pendiente y UI transparente.

## Admin (CU-01..CU-06)
`Login → Inicio (incidencias, pendientes y próximas) → Nueva solicitud (cliente, confirmación de anticipo, duración, restricciones y TTL) → Enlace listo (copiar/compartir) → Solicitudes (filtros y detalle/historial/renovar/revocar/cerrar) → Citas (detalle/reprogramar/completar/no-show/cancelar/reintentar sincronización) → Agenda (jornada/bloqueos/Google Calendar conectividad)`.

## Sistema (CU-11..CU-14)
Cálculo de slots con reglas RD; confirmar transaccional; espejo Calendar asíncrono, auditoría, expiración lógica de tokens, reintentos y reconciliación.

## Casos que deben probarse
Anticipo registrado sin reservar; sin fechas elegibles; link renovado deja inválido el viejo; usuario refresca pantalla confirmación; doble click; dos clientes a la vez; desconexión OAuth; cancelación/reprogramación durante fallo del proveedor; horario cercano a medianoche y cambios DST aunque Ecuador no los tenga.
