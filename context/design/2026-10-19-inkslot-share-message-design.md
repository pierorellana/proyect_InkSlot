# InkSlot — Compartir enlace de reserva

**Fecha:** 2026-10-19  
**Estado:** Aprobado para implementación  
**Alcance:** Pantalla administrativa de enlace generado

## Decisión

La hoja de compartir mostrará únicamente dos destinos: `WhatsApp` y `Más`.
Instagram se elimina de esta hoja porque no forma parte del flujo de contacto
definido para nuevas solicitudes.

WhatsApp abrirá `https://wa.me/?text=...` con un mensaje profesional ya
codificado. `Más` usará el menú nativo de `share_plus` con el mismo texto. El
enlace privado seguirá siendo el mismo enlace hash generado para la solicitud.

## Mensaje

```text
Hola, [Nombre] 👋

Te comparto tu enlace privado para reservar tu cita.

[Enlace]

Desde este enlace podrás elegir la fecha y hora que mejor te convenga para tu sesión de [duración].

El enlace es de un solo uso y estará disponible durante [vigencia].

Si tienes alguna duda, escríbeme por este medio.

¡Nos vemos!
```

El nombre usa el primer nombre disponible. Si no existe, se usa `cliente`. La
duración se omite si no está disponible; la vigencia se calcula a partir de la
fecha de expiración del enlace.

## Compatibilidad y errores

- No se cambia el token ni la ruta del enlace.
- El texto completo se usa tanto para WhatsApp como para `share_plus`.
- Si WhatsApp no puede abrirse, se muestra un toast para copiar el enlace.
- Si el menú nativo no está disponible, se conserva el mensaje de error actual.

## Verificación

- La hoja muestra WhatsApp y Más, pero no Instagram.
- El mensaje contiene la frase aprobada, nombre, enlace, duración y vigencia.
- Las pruebas existentes de copiar y compartir continúan pasando.
- `flutter analyze` y build Web deben finalizar correctamente.
