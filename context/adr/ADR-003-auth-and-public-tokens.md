# ADR-003 — Sesión administrativa y links públicos
**Estado:** Aceptada para el MVP local (2026-10-20); hosting, dominio y política final de cookies quedan pendientes para producción.

**Decisión:** sesión admin mediante cookie HttpOnly/Secure/SameSite, validación de origen para mutaciones, `Argon2id`, throttling y revocación. Cliente sin login, URL token opaco criptográfico ≥256 bit almacenado hasheado, vida finita, rotación/revocación y límites rate.

**Motivo:** no exponer secret administrativo al JS ni permitir enumeración de datos privados; minimizar fricción del cliente.

**Consecuencias:** CORS usa `CORS_ALLOWED_ORIGINS`; los headers incluyen CSP, `Referrer-Policy` y protección de framing; las respuestas exponen `X-Request-Id`. El dominio público, cookies cross-site y pruebas de despliegue siguen pendientes.
