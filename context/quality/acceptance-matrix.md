# Matriz de aceptación trazable

| ID | Dado / Cuando / Entonces | Prueba sugerida | Estado actual |
|---|---|---|---|
| AC-01 | Anticipo validado → crear solicitud → queda pendiente, token único | API integration + admin widget | Cubierto |
| AC-02 | Token vigente → acceso público sin cuenta | E2E token | Cubierto |
| AC-03 | Duración 180m → nunca ofrecer hueco <180m | Jest parametrize | Cubierto |
| AC-04 | Ocupación externa/interna → esos intervalos no disponibles | Calendar fake + PG fixture | Cubierto |
| AC-05 | Dos solicitudes disputan slot → solo 1 confirmada; otra 409 | dos conexiones PG concurrentes | Cubierto |
| AC-06 | Confirmación válida → cita DB y Calendar synced/pending claro | outbox fake + UI pending | Cubierto |
| AC-07 | Token caduca → 410; renovar conserva solicitud y revoca anterior | API + admin UI | Cubierto |
| AC-08 | Cancelar cita → DB libera intervalo y Calendar converge sin doble evento | integration worker | Cubierto |
| AC-09 | Sin freeBusy → 503 y no confirmación/slots falsamente libres | provider outage fake | Cubierto |
| AC-10 | Integración falla → issue visible, retry controlado y auditado | queue fault injection | Cubierto |

## Estados visuales (capturas exactas)
Splash, welcome, calendario sin día/seleccionado, loading horarios, rueda, ticket, confirmando, éxito, vencido, cancelado, sin red, sin horarios, error agenda, 409, sync pendiente; admin login/error, dashboard/incidencias, nueva solicitud/link, listas/detalles, reprogramar/cancelar, agenda/reconectar.

## Performance / seguridad / accesibilidad
Objetivo consultado habitual <2s tras medir, no SLA garantizado; 44px targets; reduce motion; WCAG contraste AA para texto y controles donde sea factible; rate limit público por IP y token; nunca exponer calendario personal; CSP/Referrer-Policy; controles contra replay/token enumeration; test mobile Safari, Chrome móvil y desktop.

## Estado de calidad transversal — 2026-10-20

- CORS por allowlist, validación de origen para mutaciones administrativas, headers de seguridad, throttles por ruta y `X-Request-Id` están implementados en el API.
- “Guardar en mi calendario” del cliente está explícitamente fuera del MVP y se muestra como funcionalidad futura.
- La verificación pixel a pixel, golden tests, CI, OpenAPI versionado, backup/restore y pruebas manuales en navegadores móviles siguen pendientes.
