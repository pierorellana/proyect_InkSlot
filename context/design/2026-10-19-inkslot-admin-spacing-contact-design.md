# InkSlot — Espaciado administrativo y canales de contacto

**Fecha:** 2026-10-19  
**Estado:** Aprobado para implementación  
**Alcance:** Flutter Web, shell administrativo y formulario de nuevas solicitudes

## Problema

El encabezado móvil del panel administrativo ya aplica el área segura superior
mediante `SafeArea`. Varias pantallas hijas vuelven a usar
`MediaQuery.padding.top` con un mínimo de 58 px, por lo que el espacio seguro se
cuenta dos veces y aparece una separación excesiva antes del primer contenido.

El selector de contacto de nuevas solicitudes también muestra cuatro canales,
aunque la operación actual solo requiere WhatsApp y correo.

## Decisión

1. Las pantallas que viven dentro de `AdminShell` usarán una separación de
   contenido reducida y consistente: 20 px en móvil y 28 px en escritorio.
2. El login administrativo no se modifica porque no vive dentro de
   `AdminShell`; conserva su cálculo de área segura propio.
3. El selector de nuevas solicitudes mostrará únicamente `WhatsApp` y
   `Correo`.
4. `ContactChannel` y los valores de API `instagram`/`phone` se mantienen para
   leer y representar solicitudes históricas sin romper compatibilidad.

## Componentes afectados

- Espaciado superior de dashboard, solicitudes, nueva solicitud, citas, detalle
  de cita, agenda, incidencias, detalle de solicitud y enlace generado.
- `ContactChannelField`, que pasa a construir su selector con una lista explícita
  de canales disponibles para creación.
- Pruebas Flutter de layout y selector de contacto.

## Comportamiento esperado

- En móvil, después del encabezado del panel, el primer contenido aparece con
  una separación visual de aproximadamente 20 px, sin volver a sumar el área
  segura del navegador.
- En escritorio, el contenido conserva una separación superior de 28 px para
  no quedar pegado al borde de la ventana.
- Una solicitud nueva puede seleccionar WhatsApp o Correo, y el campo de dato
  cambia entre número y correo según la selección.
- Solicitudes existentes con Instagram o teléfono siguen renderizándose porque
  esos valores no se eliminan del dominio ni del contrato HTTP.

## Verificación

- Prueba widget de espaciado móvil para una pantalla administrativa.
- Prueba widget del selector: muestra exactamente WhatsApp y Correo, cambia el
  label/hint y conserva la validación del correo.
- `flutter analyze`.
- Suite de pruebas Flutter de admin y solicitudes.
- Build Web con la URL de API local/túnel configurada.
