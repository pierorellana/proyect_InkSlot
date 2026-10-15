# InkSlot / Dodogio Studio — Paquete SDD v1.0

**Fecha:** 2026-10-15  | **Estado:** Especificación para implementación; no es código ejecutable.

## Propósito
Transformar el documento técnico de InkSlot v1.0 y el prototipo navegable de Claude Design en un conjunto trazable de **specs → plans → tasks → ADR → pruebas**, listo para implementar tres raíces de workspace: `app/` (Flutter Web + Provider), `api/` (NestJS) y `context/` (este paquete).

## Orden de lectura para Codex
1. `context/00-governance/AGENTS.md` y `context/00-governance/source-of-truth.md`.
2. `context/product/vision-and-scope.md`, `context/product/user-journeys.md`.
3. `context/specs/` (contratos y criterios), `context/architecture/` y `context/adr/`.
4. `context/plans/implementation-plan.md` y `context/tasks/backlog.md`.
5. `context/quality/acceptance-matrix.md` para pruebas verificables.

## Insumos requeridos en el workspace
- `references/InkSlot_Prototipo.zip` (entregado por el usuario, **no duplicado** dentro de este paquete).
- `references/InkSlot_Prototipo.html` (archivo autocontenido adjunto, referencia secundaria).
- `references/InkSlot_Especificacion_Tecnica_MVP_v1.0.pdf` (documento técnico previo, no duplicado).

El ZIP del prototipo es la fuente preferente para assets/tokens, capturas y animaciones. No inferir que el prototipo ya dispone de backend ni autenticación funcional.

## Mapa de archivos
- `product/`: alcance, flujos y decisiones de negocio.
- `specs/`: especificaciones por dominio incluyendo Flutter/UI, API, SQL y sincronización.
- `architecture/`: arquitectura y contratos.
- `adr/`: decisiones y trade-offs.
- `plans/` y `tasks/`: ruta de ejecución por incrementos y Definition of Done.
- `quality/`: pruebas, trazabilidad, seguridad y escenarios de errores.
- `design/`: inventario exacto del prototipo, tokens y guía de fidelidad.
- `open-questions.md`: decisiones aún no confirmadas, con propuestas explícitas.

**No implementar pagos, chat, catálogo ni funciones P1 como si fueran P0.**
