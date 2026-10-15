# Matriz de aceptación trazable

| ID | Dado / Cuando / Entonces | Prueba sugerida |
|---|---|---|
| AC-01 | Anticipo validado → crear solicitud → queda pendiente, token único | API integration + admin widget |
| AC-02 | Token vigente → acceso público sin cuenta | E2E token |
| AC-03 | Duración 180m → nunca ofrecer hueco <180m | Jest parametrize |
| AC-04 | Ocupación externa/interna → esos intervalos no disponibles | Calendar fake + PG fixture |
| AC-05 | Dos solicitudes disputan slot → solo 1 confirmada; otra 409 | dos conexiones PG concurrentes |
| AC-06 | Confirmación válida → cita DB y Calendar synced/pending claro | outbox fake + UI pending |
| AC-07 | Token caduca → 410; renovar conserva solicitud y revoca anterior | API + admin UI |
| AC-08 | Cancelar cita → DB libera intervalo y Calendar converge sin doble evento | integration worker |
| AC-09 | Sin freeBusy → 503 y no confirmación/slots falsamente libres | provider outage fake |
| AC-10 | Integración falla → issue visible, retry controlado y auditado | queue fault injection |

## Estados visuales (capturas exactas)
Splash, welcome, calendario sin día/seleccionado, loading horarios, rueda, ticket, confirmando, éxito, vencido, cancelado, sin red, sin horarios, error agenda, 409, sync pendiente; admin login/error, dashboard/incidencias, nueva solicitud/link, listas/detalles, reprogramar/cancelar, agenda/reconectar.

## Performance / seguridad / accesibilidad
Objetivo consultado habitual <2s tras medir, no SLA garantizado; 44px targets; reduce motion; WCAG contraste AA para texto y controles donde sea factible; rate limit público por IP y token; nunca exponer calendario personal; CSP/Referrer-Policy; controles contra replay/token enumeration; test mobile Safari, Chrome móvil y desktop.
