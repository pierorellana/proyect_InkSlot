# ADR-005 — Seguridad del borde HTTP y trazabilidad

**Estado:** Aceptada para el MVP local (2026-10-20).

**Decisión:** El API mantiene una allowlist explícita de `CORS_ALLOWED_ORIGINS`, nunca refleja cualquier origen junto con credenciales y valida `Origin`/`Referer` en mutaciones administrativas basadas en cookie. El borde añade headers de seguridad, límites específicos para login, resolución pública y confirmación, y un `X-Request-Id` validado o generado.

Los errores conservan su código y mensaje de dominio e incluyen el mismo `requestId`. Los logs HTTP solo registran request ID, ruta normalizada, método, estado y duración; no registran tokens, contactos, nombres ni payloads.

**Consecuencias:** el frontend servido por túnel o dominio nuevo debe agregarse explícitamente al `.env` del API. La allowlist, rate limits, headers y request IDs requieren validación adicional en el dominio de producción y no sustituyen un WAF o gateway cuando el volumen lo exija.
