# Plan por incrementos verticales (SDD)

Cada incremento: leer spec + pruebas → implementación funcional → screenshot/contrato → review → commit atómico. No migrar en bloque el HTML a widgets sin entender datos y estados.

| Fase | Alcance | Dependencias | Criterio de salida |
|---|---|---|---|
| 0 | Bootstrap workspace app/api/context, lint, test, CI, env | ninguna | web + API local y Postgres levantan |
| 1 | Tokens + shell Flutter/Provider/GoRouter + assets y splash | 0 | paridad visual login/splash/loading |
| 2 | NestJS schema + migraciones + auth admin | 0 | auth/guards/tests DB |
| 3 | Disponibilidad interna: jornadas/bloqueos + motor puro | 2 | RD tests en Jest |
| 4 | OAuth Calendar y consulta freeBusy | 2,3 | Calendar conectado + no slots si desconectado |
| 5 | Alta solicitud/token y panel admin | 1,2,3 | link + detalle + revocar/renovar |
| 6 | Cliente: calendario, rueda, revisión, API slots | 1,3,4,5 | UI y endpoints integrados |
| 7 | Confirmación transaccional + outbox sync + resultado | 4,5,6 | 409 concurrente, sin duplicado, sync pending |
| 8 | Listado, reprogramar, cancelar, no-show, retry | 7 | acciones auditadas + Calendar converge |
| 9 | Estado/error completo, responsive, golden/e2e, deploy | todas | AC-01..AC-10 + go/no-go |

**Trunk-Based:** ramas cortas, 1 cambio pequeño por PR si aplica; commits por feature (`feat(api): ...`, `feat(web): ...`, `test: ...`, `docs: ...`); nunca un commit masivo que mezcle UI, DB y OAuth sin separación.
