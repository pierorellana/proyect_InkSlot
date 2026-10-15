# Hoja de validación de paridad Flutter vs prototipo

Usar `InkSlot_Prototipo/capturas/*.jpg` como referencia, viewport base 390×844 @2x; además 375×812, 430×932, tablet/desktop. Por cada captura rellenar:

| Captura | Ruta Flutter | Paridad estructura | Tokens/fuentes | Animación | Estado API | Accesibilidad | Resultado |
|---|---|---|---|---|---|---|---|
| 01-cliente-splash.jpg | `/` | ✓ | ✓ | ✓ | N/A | ✓ | slice verificado |
| 02-cliente-bienvenida.jpg | `/r/:token` | ✓ | ✓ | ✓ | fixture visual | ✓ | slice verificado |
| 06-cliente-horarios.jpg | pendiente | □ | □ | □ | □ | □ | pendiente |
| 08-cliente-revision.jpg | pendiente | □ | □ | □ | □ | □ | pendiente |
| 10-cliente-exito.jpg | pendiente | □ | □ | □ | □ | □ | pendiente |
| 16-cliente-conflicto-409.jpg | pendiente | □ | □ | □ | □ | □ | pendiente |
| 20-tatuador-login.jpg | pendiente | □ | □ | □ | □ | □ | pendiente |
| 26-tatuador-nueva-solicitud-completa.jpg | pendiente | □ | □ | □ | □ | □ | pendiente |
| 36-tatuador-agenda.jpg | pendiente | □ | □ | □ | □ | □ | pendiente |

**Completar para TODAS las capturas listadas en `design/prototype-inventory.md`.** No aceptar UI reemplazada por componentes Flutter Material genéricos si se apartan del prototipo sin motivo técnico documentado.

## Evidencia del slice visual público — 2026-10-15

Referencia comparada: `01-cliente-splash.jpg` y `02-cliente-bienvenida.jpg` del ZIP ignorado del prototipo. El producto no incluye esas capturas como UI; utiliza los SVG y WOFF2 fuente entregados.

| Aspecto | Resultado | Evidencia |
|---|---|---|
| Logo, isotipo y tipografías | Conforme | assets locales en `app/assets`; `InkSlotLogo`, `Instrument Serif`, `Geist` y `Geist Mono` |
| Paleta y superficies | Conforme | `app/lib/core/theme/inkslot_tokens.dart` y `inkslot_theme.dart` |
| Splash | Conforme en estados implementados | D con transformación 3D, halo cobre, wordmark, skip intro y finalización reduced-motion |
| Bienvenida | Conforme en estados implementados | mosaico de seis ilustraciones, chip de enlace privado, resumen, artista, CTA y ayuda |
| Navegación | Conforme | `/` → `/r/demo-token`; `/r/:token` → `/r/:token/dates` placeholder |
| Accesibilidad | Conforme en pruebas | semantic label del logo, targets mínimos de 44 px y CTA navegable |
| Responsive | Verificación automatizada | scroll vertical, ancho máximo 560 px y contenido usable en el viewport de referencia |
| Build | Conforme | `fvm flutter build web --release` exitoso con Flutter 3.47.5 |

### Estados cubiertos

- Splash normal con `SALTAR INTRO`.
- Splash con `MediaQuery.disableAnimations = true`, que termina sin esperar 4.6 s.
- Deep link privado, que omite el splash.
- Bienvenida con CTA a la ruta de fechas provisional.
- Mosaico animado y fallback estático con reduced motion.

### Gaps explícitos

- La comparación pixel a pixel de las 38 capturas queda abierta hasta implementar disponibilidad, revisión, confirmación, estados de error y las pantallas admin.
- `/r/:token/dates` es deliberadamente un placeholder y no afirma disponibilidad real; se reemplazará por el slice de dominio/API de disponibilidad.
- Los valores de bienvenida (Valentina, Gio, duración y vigencia) son fixtures visuales, no datos de producción.
