# InkSlot Admin Auth Implementation Plan

> SDD slice: contrato HTTP → pruebas e2e → sesión persistida → Argon2id → verificación → commit enfocado.

**Objetivo:** implementar la autenticación administrativa inicial para el entorno local sin exponer credenciales ni mezclarla con los enlaces públicos.

**Fuentes:** `context/specs/01-auth-and-roles.md`, `context/adr/ADR-003-auth-and-public-tokens.md`, `context/architecture/api-contracts.md`, `context/architecture/solution.md`.

## Contrato

- `POST /v1/auth/login`: `{email,password}` → `200 {user:{id,name,role}}` y cookie HttpOnly.
- `GET /v1/auth/me`: sesión válida → usuario; ausencia, expiración o revocación → `401 AUTH_INVALID`.
- `POST /v1/auth/logout`: revoca la sesión actual y devuelve `204`.
- Error de usuario, contraseña o artista inactivo: mismo `401 AUTH_INVALID` sin revelar cuál dato falló.
- El token de sesión se genera aleatoriamente, se entrega solo en cookie y se persiste únicamente como hash SHA-256.
- `Secure` se activa en producción; local HTTP usa `HttpOnly`, `SameSite=Lax`, `Path=/` y TTL finito.

## No incluido

- Guard de rutas `/admin/*` sin un módulo admin real.
- CSRF de despliegue compartido, MFA, recuperación de contraseña y creación de artistas.
- Tokens públicos de solicitudes, Calendar OAuth o pagos.

## Criterios de salida

- Argon2id verifica contraseñas; nunca se compara ni guarda texto plano.
- Login inválido, artista inactivo y cookie ausente producen el mismo payload/código.
- Logout revoca la sesión y la cookie deja de autenticar.
- Tests e2e pasan contra PostgreSQL local y la respuesta no incluye `passwordHash` ni el token crudo.

## Pasos

1. [x] Escribir tests e2e para login, me, logout, expiración y credencial inválida.
2. [x] Agregar `admin_sessions` al esquema/migración Prisma.
3. [x] Implementar DTO, servicio y controller con cookie local segura y Argon2id.
4. [x] Ejecutar formato, build, tests e2e y revisar contrato.
5. Registrar evidencia y crear commits pequeños de plan, código y documentación.
