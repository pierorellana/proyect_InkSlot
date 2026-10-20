# ADR-003 — Sesión administrativa y links públicos
**Estado:** Aceptada para el MVP local y el primer despliegue productivo (2026-10-20).

**Decisión:** sesión admin mediante cookie HttpOnly/Secure/SameSite, validación de origen para mutaciones, `Argon2id`, throttling y revocación. En producción, mientras el frontend y el API estén en dominios distintos, la cookie usa `SameSite=None` junto con `Secure`; en local conserva `SameSite=Lax`. Cliente sin login, URL token opaco criptográfico ≥256 bit almacenado hasheado, vida finita, rotación/revocación y límites rate.

**Motivo:** no exponer secret administrativo al JS ni permitir enumeración de datos privados; minimizar fricción del cliente.

**Consecuencias:** CORS usa `CORS_ALLOWED_ORIGINS`; los headers incluyen CSP, `Referrer-Policy` y protección de framing; las respuestas exponen `X-Request-Id`. La allowlist debe incluir exactamente el dominio de Netlify y ambos despliegues deben usar HTTPS. Un dominio personalizado bajo el mismo sitio registrable para frontend y API sigue siendo la evolución recomendada si las políticas de bloqueo de cookies de terceros del navegador afectan al despliegue.
