# ADR-002 — Integridad de citas y sincronización Google
**Estado:** Aceptada e implementada para el MVP local (2026-10-20).

**Decisión:** PostgreSQL conserva solicitudes y reservas. `freeBusy` Google se exige al ofrecer/confirmar; confirmation transaccional con constraint EXCLUDE, idempotency key, outbox, worker/retry y syncStatus separado de bookingStatus.

**Razones:** fallo entre transacción SQL y API Google no admite transacción distribuida. Outbox evita perder comandos y permite auditar pendientes. Si falla freeBusy antes del commit, se bloquea la confirmación; si falla escritura después, se comunica confirmed+sync_pending (documento AC-06).

**Riesgos:** divergencia por edición manual del evento Calendar, retry y latencia. La estrategia de resolución y el alcance de polling/webhooks siguen abiertos y deben definirse antes de producción.
