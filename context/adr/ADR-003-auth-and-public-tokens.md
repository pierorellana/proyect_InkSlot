# ADR-003 — Sesión administrativa y links públicos
**Estado:** Propuesta de implementación (pendiente ratificar hosting/domínios).

**Decisión recomendada:** sesión admin mediante cookie HttpOnly/Secure/SameSite + CSRF si aplica al dominio; `Argon2id`, throttling y revocación. Cliente sin login, URL token opaco criptográfico ≥256 bit almacenado hasheado, vida finita, rotación/revocación y límites rate.

**Motivo:** no exponer secret administrativo al JS ni permitir enumeración de datos privados; minimizar fricción del cliente.

**Consecuencias:** CORS/CSRF/referrer/redirecciones/deep links deben probarse al definir dominio público.
