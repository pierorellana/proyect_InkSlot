# InkSlot — calidad, seguridad y trazabilidad

## Objetivo

Cerrar los cuatro fallos conocidos de Flutter, endurecer las operaciones HTTP administrativas y públicas, añadir trazabilidad por petición, declarar la acción de calendario público como futura y sincronizar el SDD con el estado real del producto.

## Decisiones

- Los fixtures visuales no dependerán de un día fijo que pueda quedar en el pasado; elegirán el primer día disponible expuesto por el repositorio de prueba.
- La reprogramación administrativa usará una referencia temporal estable en las pruebas para no depender de la hora del sistema.
- CORS se limitará mediante `CORS_ALLOWED_ORIGINS`; no se reflejará cualquier origen cuando existan credenciales.
- Las mutaciones administrativas basadas en cookie validarán `Origin` y, cuando el navegador no lo envíe, `Referer` contra la misma allowlist. Las peticiones sin origen solo se permitirán fuera de producción para herramientas locales.
- Se habilitarán headers de seguridad con la API de NestJS y una política de referencia restrictiva.
- Los límites específicos serán más estrictos para login, resolución pública de enlaces y confirmación; el límite global seguirá como protección secundaria.
- Cada petición tendrá un `X-Request-Id` validado o generado por el API. El valor se devolverá en la respuesta y se incluirá en errores y logs estructurados sin datos personales.
- “Guardar en mi calendario” será una capacidad futura: la UI no ejecutará un toast que sugiera una integración terminada y mostrará el estado “Próximamente”.
- Los contratos, ADR, specs y matrices documentarán la implementación actual; las decisiones de marca, hosting, retención y reconciliación de Calendar seguirán explícitamente abiertas.

## Alcance fuera de este slice

- No se implementa exportación ICS ni integración de calendarios del cliente.
- No se agregan Docker, colas externas, Redis ni nuevas raíces del workspace.
- No se cambia la lógica de negocio de disponibilidad ni de confirmación salvo lo necesario para pruebas deterministas.

## Verificación

- Flutter: pruebas de citas y capturas públicas, análisis y suite completa.
- API: pruebas unitarias de middleware/guardas, pruebas de controladores y suite completa.
- Documentación: búsqueda de referencias obsoletas, `git diff --check` y matriz de aceptación actualizada.
