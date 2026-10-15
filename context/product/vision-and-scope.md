# Visión y alcance — MVP (P0)

**Problema:** tras anticipo pagado y validado en canales externos, el tatuador puede olvidar crear una cita en Google Calendar. **Propuesta:** generar solicitud trazable con enlace seguro, permitir que cliente elija solo huecos válidos y guardar/sincronizar cita.

## Actores
- Tatuador/administrador: login, disponibilidad semanal, bloqueos, conectar Calendar, alta de solicitud con anticipo validado, enlace y acciones sobre citas.
- Cliente: token privado, elige fecha y hora, revisa, confirma y consulta resultado; **sin registro**.
- Sistema: consulta Calendar, valida huecos, previene conflictos, audita, reintenta sincronización.

## P0
RF-01..RF-16 del documento técnico, incluidos login, horarios/bloqueos, OAuth, clientes mínimos, solicitudes y tokens, vista pública, reserva con control de concurrencia, Calendar, lista de pendientes, reprogramación/cancelación, auditoría y recuperación de errores.

## P1 (no bloquear lanzamiento)
RF-17 recordatorios propios por correo, RF-18 reprogramación por cliente, RF-19 alertas proactivas sobre pendientes.

## Fuera de alcance
Chat, asesoría, cobro/validación automática de pagos, contabilidad, catálogo, múltiples estudios/tatuadores, aplicación nativa, IA, analytics avanzado.

## KPIs pilotos
- Solicitudes pagadas no agendadas y su antigüedad.
- Tiempo de crear solicitud y copiar enlace.
- Conversión solicitud→cita.
- Doble reservas confirmadas (objetivo cero).
- Tiempo y porcentaje de sincronización Calendar.
