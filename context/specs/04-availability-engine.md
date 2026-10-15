# SPEC-AVAILABILITY — RF-02, RF-03, RF-09, RF-12; RD-01..RD-12

## Modelo
Input: `studioTimezone` IANA, jornada semanal multi-franja, bloqueos/excepciones, pausa y márgenes, `durationMinutes`, `slotStepMinutes`, `minimumNoticeHours`, `bookingHorizonDays`, rango/weekday/windows de solicitud, ocupaciones externas y citas internas activas.
Output: solo instantes de **inicio** cuyo intervalo `[start,start+duration)` cabe totalmente en jornada y restricciones, no solapa bloqueos/citas (con buffer), y cumple ventana permitida. Expresar salida ISO-8601 UTC + label local.

## Precedencia
`jornada base ∩ restricciones solicitud ∩ (no bloqueos internos) ∩ (no ocupaciones Calendar) ∩ aviso mínimo ∩ horizonte ∩ duración`. Excepciones solo pueden **reducir** la jornada en MVP. Días hábiles del prototipo martes-sábado 10–20, pausa 13:30–14:30, límite nov 30: son datos de demo, no valores inmutables.

## Algoritmo
1. Parsear fechas en zona del estudio, materializar franjas UTC; resolver límites y días.
2. Cargar bloqueos y citas internas no canceladas; consultar freeBusy externo para mismo rango.
3. Si Calendar no verificable, fallar cerrado `503 CALENDAR_UNAVAILABLE`; jamás publicar slots como seguros.
4. Generar inicios a paso de 30 min (configurable), comprobar duración completa y buffer **entre** citas, sin exigir buffer adicional al fin de la jornada.
5. Ordenar, deduplicar, marcar día elegible si contiene ≥1 inicio válido.
6. Al confirmar, **recalcular en backend**, no confiar en slots del cliente.

## Tests mínimos
Sesión 3 h no cabe en 2 h (AC-03); bloqueos externos/internos (AC-04); media hora/almuerzo; límites inclusivos/exclusivos; días prohibidos; anticipación; fecha de horizonte; buffer; cruce de día; time zones; Calendar offline (AC-09); concurrencia (AC-05).

## API
`GET /v1/public/reservations/:token/availability?from=YYYY-MM-DD&to=YYYY-MM-DD` → `{timezone,days:[{date,slots:[{startAt,endAt}]}]}`. Aplicar límites de rango, cache breve solo opcional (no para confirmación).
