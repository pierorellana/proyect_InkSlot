# Hoja de validación de paridad Flutter vs prototipo

La implementación de las rutas se encuentra cubierta; “pendiente” en esta matriz significa que falta la captura comparativa/golden documentada, no que la pantalla no exista.

Usar `InkSlot_Prototipo/capturas/*.jpg` como referencia, viewport base 390×844 @2x; además 375×812, 430×932, tablet/desktop. Por cada captura rellenar:

| Captura | Ruta Flutter | Paridad estructura | Tokens/fuentes | Animación | Estado API | Accesibilidad | Resultado |
|---|---|---|---|---|---|---|---|
| 01-cliente-splash.jpg | `/` | ✓ | ✓ | ✓ | N/A | ✓ | slice verificado |
| 02-cliente-bienvenida.jpg | `/r/:token` | ✓ | ✓ | ✓ | fixture visual | ✓ | slice verificado |
| 06-cliente-horarios.jpg | `/r/:token/dates` | ✓ | ✓ | ✓ | ✓ | ✓ | implementación cubierta; captura pendiente |
| 08-cliente-revision.jpg | `/r/:token/review` | ✓ | ✓ | ✓ | ✓ | ✓ | implementación cubierta; captura pendiente |
| 10-cliente-exito.jpg | `/r/:token/result` | ✓ | ✓ | ✓ | ✓ | ✓ | implementación cubierta; captura pendiente |
| 16-cliente-conflicto-409.jpg | `/r/:token/review` | ✓ | ✓ | ✓ | ✓ | ✓ | estado cubierto; captura pendiente |
| 20-tatuador-login.jpg | `/admin/login` | ✓ | ✓ | N/A | ✓ | ✓ | implementación cubierta; captura pendiente |
| 26-tatuador-nueva-solicitud-completa.jpg | `/admin/requests/new` | ✓ | ✓ | ✓ | ✓ | ✓ | implementación cubierta; captura pendiente |
| 36-tatuador-agenda.jpg | `/admin/agenda` | ✓ | ✓ | ✓ | ✓ | ✓ | implementación cubierta; captura pendiente |

**Completar para TODAS las capturas listadas en `design/prototype-inventory.md`.** No aceptar UI reemplazada por componentes Flutter Material genéricos si se apartan del prototipo sin motivo técnico documentado.

## Evidencia del slice visual público — 2026-10-15

Referencia comparada: `01-cliente-splash.jpg` y `02-cliente-bienvenida.jpg` del ZIP ignorado del prototipo. El producto no incluye esas capturas como UI; utiliza los SVG y WOFF2 fuente entregados.

| Aspecto | Resultado | Evidencia |
|---|---|---|
| Logo, isotipo y tipografías | Conforme | assets locales en `app/assets`; `InkSlotLogo`, `Instrument Serif`, `Geist` y `Geist Mono` |
| Paleta y superficies | Conforme | `app/lib/core/theme/inkslot_tokens.dart` y `inkslot_theme.dart` |
| Splash | Conforme en estados implementados | D con transformación 3D, halo cobre, wordmark, skip intro y finalización reduced-motion |
| Bienvenida | Conforme en estados implementados | mosaico de seis ilustraciones, chip de enlace privado, resumen, artista, CTA y ayuda |
| Navegación | Conforme | `/` → `/r/demo-token`; `/r/:token` → `/r/:token/dates` real |
| Accesibilidad | Conforme en pruebas | semantic label del logo, targets mínimos de 44 px y CTA navegable |
| Responsive | Verificación automatizada | scroll vertical, ancho máximo 560 px y contenido usable en el viewport de referencia |
| Build | Conforme | `fvm flutter build web --release` exitoso con Flutter 3.47.5 |

### Estados cubiertos

- Splash normal con `SALTAR INTRO`.
- Splash con `MediaQuery.disableAnimations = true`, que termina sin esperar 4.6 s.
- Deep link privado, que omite el splash.
- Bienvenida con CTA a la ruta de fechas real.
- Mosaico animado y fallback estático con reduced motion.

### Gaps explícitos

- La comparación pixel a pixel y las golden de las 38 capturas siguen abiertas aunque las rutas y estados ya estén implementados.
- La captura final debe validarse en 390×844, 375×812, 430×932, tablet y desktop, incluyendo Safari móvil y Chrome móvil.
- Los valores de bienvenida (Valentina, Gio, duración y vigencia) son fixtures visuales, no datos de producción.
