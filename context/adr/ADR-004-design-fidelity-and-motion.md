# ADR-004 — Paridad visual iOS y animaciones
**Estado:** Decisión basada en prototipo adjunto.

**Decisión:** prototipo ZIP es referencia para UI (no simple inspiración): isotipo D, paleta cobre sobre tinta, tipografías, estados, selección de horarios tipo rueda, ticket 3D, splash animado, hojas iOS. Implementar en Flutter Web con Provider para estado y herramientas nativas de animación; importar SVG/font licenciados desde ZIP cuando implementen.

**Consecuencias:** escribir widgets custom y pruebas golden; optar por fallback reduce motion, accesibilidad, performance web/iOS Safari. Documentar cualquier diferencia de diseño y no introducir rojo como marca.
