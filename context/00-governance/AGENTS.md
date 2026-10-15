# Instrucciones para agentes de implementación

1. Inspeccionar ZIP, HTML autocontenido, capturas, tokens, animaciones, SVG y fuentes antes de reproducir UI. **No rediseñar** el prototipo ni improvisar assets.
2. Usar `Flutter Web + Provider`, `GoRouter` para navegación, `NestJS + TypeScript` para API y `PostgreSQL` para persistencia. No introducir Riverpod/Bloc/Firebase como sustitución tácita.
3. Todo endpoint, entidad, cambio visual o regla de negocio debe referenciar su `RF`, `RD`, `AC`, `UI` o `ADR`.
4. Priorizar slices verticales pequeños: spec → tests → implementación → pruebas → commit. Mantener Trunk-Based Development, commits pequeños por módulo; no commitear secretos.
5. No implementar validación automática de anticipos: el tatuador verifica el pago externamente y deja constancia administrativa.
6. El cliente reserva sin cuenta por token opaco temporal; la API nunca revela calendarios ajenos, teléfonos privados, tokens OAuth ni datos de otros clientes.
7. Fuente de verdad: DB para solicitudes/citas; Google Calendar para ocupaciones ajenas y espejo eventual de las citas. Bloquear confirmación si no se logra verificar ocupación externa.
8. Evitar doble reserva incluso con solicitudes concurrentes y reintentos HTTP; usar transacciones, restricción EXCLUDE de PostgreSQL o mecanismo equivalente robusto, y claves de idempotencia.
9. La UI debe cubrir todos los estados del prototipo: loading/skeleton/success/error/expired/cancelled/already-booked/no-slots/offline/calendar-unverifiable/conflict-409/sync-pending/admin-reconnect.
10. No incrustar imágenes como screenshots en el producto terminado: recrear componentes Flutter y reutilizar assets autorizados; documentar las animaciones que no puedan reproducirse idénticas y pedir decisión antes de sustituirlas.
11. Lógica de disponibilidad y OAuth **solo en API**. UTC en DB; IANA `America/Guayaquil` para mostrar hora local.
12. No añadir capas genéricas o patterns sin un beneficio concreto; mantener Clean Architecture pragmática, Provider + ChangeNotifier/ViewModel en Flutter y módulos NestJS por dominio.
13. Cada historia termina con tests, estados vacíos/error, accesibilidad, indicadores de carga y evidencia en `tasks/`.
14. Cualquier contradicción se registra como decisión abierta; no reinterpretar silenciosamente los requisitos.
