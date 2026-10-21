# InkSlot: sesión móvil mediante proxy same-origin

## Contexto

El frontend productivo se sirve desde `https://inkslot-app.netlify.app` y el
backend desde `https://proyect-inkslot.onrender.com`. El login responde
correctamente en escritorio, pero en navegadores móviles la sesión no se
conserva al navegar al dashboard. La causa probable es el bloqueo de cookies
cross-site por Safari/WebKit y configuraciones de cookies de terceros.

## Decisión

El navegador consumirá el API mediante la ruta same-origin:

```text
https://inkslot-app.netlify.app/v1
```

Netlify reenviará internamente `/v1/*` a:

```text
https://proyect-inkslot.onrender.com/v1/:splat
```

El backend continuará desplegado en Render. No se agregará autenticación por
token en `localStorage`; la sesión seguirá usando la cookie HTTP-only existente.

## Cambios

1. Agregar una regla de proxy externa en `netlify.toml` para `/v1/*`.
2. Cambiar el comando de build de Netlify para usar
   `API_BASE_URL=https://inkslot-app.netlify.app/v1`.
3. Mantener `BrowserClient.withCredentials = true`.
4. Mantener `CORS_ALLOWED_ORIGINS` del backend con el origen de Netlify.
5. Validar que login, `/auth/me` y una consulta protegida del dashboard
   funcionen con la misma cookie en el origen de Netlify.

## Fuera de alcance

- No se cambia el dominio público del backend.
- No se modifican credenciales ni la lógica de autenticación.
- No se modifica la cookie HTTP-only ni se expone la sesión a Dart o
  `localStorage`.
- No se cambian los enlaces públicos `/r/:token`.

## Criterios de aceptación

- La compilación productiva genera el frontend apuntando a
  `https://inkslot-app.netlify.app/v1`.
- Las solicitudes del navegador a `/v1/*` se resuelven mediante Netlify hacia
  Render.
- Después de iniciar sesión desde Safari móvil y Chrome móvil, el dashboard
  permanece autenticado al ejecutar `/auth/me` y sus consultas protegidas.
- El backend sigue aceptando solicitudes directas de su origen configurado
  para operaciones permitidas y no se relajan CORS ni los headers de seguridad.

