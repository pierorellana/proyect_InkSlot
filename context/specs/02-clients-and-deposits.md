# SPEC-CLIENTS — RF-05, RF-06

Se guardan datos mínimos para operar: nombre, medio de contacto (email/teléfono según decisión del estudio), notas internas opcionales. Anticipo **validado manualmente**: bandera true, `verifiedAt`, `verifiedBy`, `paymentReference?` opcional. No almacenar imagen del comprobante ni datos bancarios sin decisión explícita.

`POST /v1/admin/booking-requests` permite crear cliente inline o referenciar cliente existente, con `depositVerified: true`. Si es false, rechazar (`422 DEPOSIT_NOT_VERIFIED`) para crear enlaces habilitados. El cliente no ve monto ni notas privadas.

Validar formato de contacto, duración >0, fecha límite válida, días en 0..6, franjas consistentes. Datos de prueba del prototipo no implican clientes reales.

**AC**: solicitud creada conserva trazabilidad del anticipo; ninguna solicitud con token reservable sin verificación; edición de contacto no afecta una cita existente; auditoría registra autor.
