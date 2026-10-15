# ADR-001 — Arquitectura y stack
**Estado:** Aceptada por requisitos de usuario (2026-10-15).

**Decisión:** workspace con tres raíces `app/` Flutter Web (Provider + GoRouter recomendado), `api/` NestJS TypeScript, `context/` SDD; PostgreSQL DB. Backend BFF/REST modular con adaptadores Calendar.

**Motivo:** reutiliza experiencia Flutter, aislamiento de reglas críticas en servidor, integridad transaccional SQL, implementación incremental y testeable.

**Consecuencias:** no usar React para producto ni Riverpod/Bloc sin cambio de ADR; el ZIP HTML es referencia visual/comportamental y se reimplementa en widgets Flutter.
