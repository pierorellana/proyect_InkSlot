# SPEC-FLUTTER-WEB — UI-PUBLIC / ADMIN

## Tecnología obligatoria
Flutter Web + Provider (`ChangeNotifier` por flujo/feature, `Selector`/`Consumer` para granularidad); GoRouter con rutas declarativas, repository + Dio/http, capas UI/domain/data ligeras. No exponer secretos Google en cliente. Diseño responsive con prioridad iPhone 390×844; pantalla desktop útil para admin sin depender de dos teléfonos mockup.

## Flujos visuales del ZIP (reproducir fielmente)
- Splash: `coinIn/sway`, `draw/fillin`, `drop/ripple`, `beam/halo`, `wm`; duración demo 4.6 s, evaluar salto para enlace profundo/accesibilidad.
- Welcome: mosaico de seis ilustraciones flash animado `up/dn`.
- Días: selección `pop`, solo días con huecos completos.
- Horarios: **rueda curva** con gestos/touch, wheel y flechas; horario activo píldora con glow cobre y contraste legible; horarios vecinos visibles.
- Revisión: ticket con entrada/tilt 3D (`tkIn`); confirmar con estado cargando.
- Resultado: stamp, ringOut y check, botón `Ver mi reserva`; `Guardar en mi calendario` se muestra deshabilitado como `Próximamente` hasta implementar exportación o integración del calendario del cliente.
- Admin: login, home, nueva solicitud, enlace, listas/detalles, agenda, sheets y toasts.

## Estados obligatorios
`activo`, `vencido (410)`, `cancelado`, `agendado`, `sin_horarios`, `sin_red`, `error_agenda`, `conflicto (409)`, `sincronizacion=pendiente`, loader de horarios, loader al confirmar, error de login, `calendario=reconectar`, incidente sync/resuelto y calendario del cliente futuro. Implementar mensajes/CTA apropiados; no replicar datos mock como definitivos.

## Tokens exactos
`#0A0A0B` tinta, `#050505` profundo, `#131315` superficie, `#EEE9E0` hueso, `#9B968E` ceniza, `#C87939` cobre, `#D48A45` cobre claro, `#241A12` tabaco; semánticos `#8FBF9A` éxito, `#E6C77A` aviso, `#E2604C` error. Tipos: Instrument Serif, Geist, Geist Mono; archivos origen `assets/fuentes/*` del ZIP (consultar licencia; **no redistribuir** en docs). Estilos y medidas concretas en tokens.json.

## Animaciones Flutter
Transiciones con `AnimationController`, `Tween`, `Transform`/`Matrix4`, `CustomPainter` para trazo D y splash; `GestureDetector`, `PageView` o picker animado para rueda; `Hero` solo si coincide con prototipo. Preferir animación transform/opacity frente a repintado costoso, precache assets; respetar Reduce Motion (`MediaQuery.disableAnimations`), pausar/offscreen; evitar dependencia de WebGL innecesaria.

## Rutas sugeridas (propuesta)
`/r/:token`, `/r/:token/dates`, `/r/:token/times`, `/r/:token/review`, `/r/:token/result`, `/admin/login`, `/admin`, `/admin/requests`, `/admin/requests/new`, `/admin/appointments`, `/admin/availability`, `/admin/calendar`. Evitar token en analytics/referrer; considerar URL limpia para confirmación y política Referrer-Policy.

## AC UI
Comparar a 390×844 con capturas nombradas en `design/prototype-inventory.md`; navegación back/forward y enlaces profundos; safe areas; soporte táctil y teclado; hit targets ≥44px; focus/semantics/contraste; no loading infinito; no white flash durante splash; animaciones no impiden reservar.
