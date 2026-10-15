# SPEC-AUTH — RF-01

Admin único inicial. `POST /v1/auth/login` con email/password, credenciales hasheadas Argon2id; respuestas genéricas para usuario/clave erróneos; throttle/rate limit; estrategia JWT de acceso corto + refresh con rotación o sesión HttpOnly segura según despliegue. **Decisión ADR-003** favorece cookies HttpOnly Secure SameSite con defensa CSRF si frontend/API comparten sitio; validar origin/CORS.

## Contratos
`POST /v1/auth/login`: `{email,password}` → `200 {user:{id,name,role}}` + cookies de sesión; `401 AUTH_INVALID`.
`GET /v1/auth/me` → usuario admin o `401`.
`POST /v1/auth/logout` → `204` y revocación.

## Seguridad
Separar rutas `/v1/admin/*` por guard; rutas públicas solo aceptan token de solicitud; no compartir auth admin con cliente. Guardar auditoría de inicios fallidos limitados, sin credenciales. Token OAuth Calendar cifrado server-side.

## Acceptance
AUTH-AC1 credencial válida permite entrar. AUTH-AC2 incorrecta produce error y bloqueo gradual. AUTH-AC3 usuario público no accede admin. AUTH-AC4 logout invalida renovación y sesión. AUTH-AC5 estados loading/error del login del prototipo.
