# Preguntas/decisiones abiertas antes de producción

1. **Marca**: ¿nombre final visible InkSlot, Dodogio o uno distinto? ZIP dice «Dodogio Studio» como dato provisional y logo D; no asumir razón social.
2. **Contacto obligatorio cliente**: ¿email, teléfono, ambos? ¿Cómo enviar confirmación inicial sin mensajería propia P0?
3. **Anticipo**: ¿registrar importe/referencia o solo confirmación manual? Política de retención y evidencia.
4. **Calendario**: ¿un calendario dedicado o calendario personal? ¿qué hacer si tatuador edita/borra eventos manualmente? ¿soporte de varios calendarios ocupados?
5. **Agenda**: horarios reales, duración mínima/máxima, buffer antes/después, anticipación, horizonte, excepciones fuera de jornada.
6. **Enlace**: TTL por defecto 48 horas sugerido, tratamiento al consumir y si consulta posterior puede usar mismo token de forma segura.
7. **Reprogramación**: si Calendar indisponible durante edición admin, ¿bloquear o permitir pendiente como actualización interna?
8. **Autenticación**: dominio y despliegue determinan cookie vs token; MFA admin deseable posteriormente.
9. **Base de datos**: resuelto como Prisma + SQL raw; la migración de persistencia habilita `btree_gist` y la constraint PostgreSQL de rangos.
10. **Operación**: proveedor de hosting, redis/queue opcional, backup, auditoría, retention, correo y política de privacy.
11. **Contenido real**: dirección del estudio, fotos/ilustraciones definitivas, links Instagram, textos e instrucciones de visita.
12. **Datos demo**: fechas 2026-10/11, horarios martes-sábado 10–20 y pausa de almuerzo son para prototipo y no deben fijarse en migraciones como datos reales.

Las decisiones pendientes **no bloquean** scaffolding, migraciones generales ni motor de disponibilidad usando fixtures configurables; sí bloquean integración real en producción.
