# Sistema de diseño y movimiento — especificación Flutter

## Tokens — fuente principal `design-tokens/tokens.json`
Paleta `#050505` fondo profundo, `#0A0A0B` tinta, `#131315` superficie, `#1C1C1F` superficie 2, `#EEE9E0` hueso, `#F2ECE2` crema, `#A7A29A` secundario, `#C87939` cobre, `#D48A45` hover, `#241A12` tabaco. Estados: verde `#8FBF9A`, amarillo `#E6C77A`, coral error `#E2604C` **solo semántico**. No rojo como marca.

Tipografías: titulares Instrument Serif; interfaz Geist; horas/etiquetas Geist Mono. Escala: display 52/44/40, heading 32, body 16/15, small 13, mono 11. Radios botón 28, tarjeta 24, sheet 38, mosaico 26. Padding horizontal 20-24 y target táctil 44 px mínimo; safe areas superior 58/inferior 34 como referencias de dispositivo demo, no hardcodes universales.

## Efectos
- Splash `coinIn`, `sway`, `draw`, `fillin`, `drop`, `ripple`, `beam`, `halo`, `wm`.
- Welcome `up`,`dn`.
- Navegación `scrIn`,`rise`.
- Día `pop`, rueda de horarios `pill` + scroll curvo.
- Ticket `tkIn` y tilt 3D; éxito `stamp`,`ringOut`, check animado.
- Sheets/toasts/login `sheet`,`toast`,`shake`; link `chain`,`tok`; loading `pulse`,`spin`.
- Curvas ejemplo `cubic-bezier(.2,.8,.2,1)` estándar, `.2,.9,.25,1` hoja, `.16,.84,.3,1` 3D.
- Duración micro 200ms, pantallas 550-600ms, sheet 550ms y splash total 4.6s; respetar reduce motion y ajustes de accesibilidad.

## Reglas de implementación
Conservar jerarquía de horarios activos/inactivos legible: no esconder slots secundarios con blur excesivo; copper glow solo activo, contraste alto texto hueso. Usar `AnimationController`, AnimatedSwitcher, Tween, Transform, CustomPaint; controlar repaints en Web, no usar video externo por defecto. Registrar diferencias por rendimiento y validar 60 FPS objetivo en dispositivo de prueba (no garantía).
