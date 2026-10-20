# SPEC-AUTH — RF-01

Admin único inicial. `POST /v1/auth/login` con email/password, credenciales hasheadas Argon2id; respuestas genéricas para usuario/clave erróneos; throttle/rate limit y sesión HttpOnly segura. **Decisión ADR-003** usa cookies HttpOnly Secure SameSite con validación de origen para mutaciones; CORS se limita por `CORS_ALLOWED_ORIGINS`. Cuando frontend y API están en dominios distintos en producción, la cookie usa `SameSite=None; Secure`; en local usa `SameSite=Lax`.

## Contratos
`POST /v1/auth/login`: `{email,password}` → `200 {user:{id,name,role}}` + cookies de sesión; `401 AUTH_INVALID`.
`GET /v1/auth/me` → usuario admin o `401`.
`POST /v1/auth/logout` → `204` y revocación.

## Seguridad
Separar rutas `/v1/admin/*` por guard; rutas públicas solo aceptan token de solicitud; no compartir auth admin con cliente. Las mutaciones admin/login rechazan `Origin`/`Referer` no permitidos. Login tiene límite específico y el API agrega `X-Request-Id` a respuestas y errores. Guardar auditoría de inicios fallidos limitados, sin credenciales, y token OAuth Calendar cifrado server-side siguen siendo requisitos de producción pendientes de completar.

## Acceptance
AUTH-AC1 credencial válida permite entrar. AUTH-AC2 incorrecta produce error y bloqueo gradual. AUTH-AC3 usuario público no accede admin. AUTH-AC4 logout invalida renovación y sesión. AUTH-AC5 estados loading/error del login del prototipo.
