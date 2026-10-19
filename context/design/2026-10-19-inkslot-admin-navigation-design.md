# Diseño: navegación administrativa responsive y fondo Web del login

**Fecha:** 2026-10-19  
**Estado:** aprobado conceptualmente; pendiente de revisión del documento  
**Alcance:** ajuste visual del shell administrativo, login Web y transiciones

## Objetivo

Corregir la experiencia administrativa en pantallas móviles sin convertirla en
una aplicación móvil: conservar la navegación lateral de escritorio, sustituir
la barra inferior móvil por un menú hamburguesa y mejorar la transición entre
vistas administrativas. Además, evitar que iOS/Safari muestre un área blanca
detrás del teclado virtual al enfocar los campos del login.

## Decisiones

- En anchos de `860 px` o más se conserva el rail lateral actual.
- En anchos menores a `860 px` se elimina la tab bar inferior y se muestra un
  encabezado administrativo compacto con logo, nombre del estudio y botón
  hamburguesa.
- El hamburguesa abre un drawer desde la izquierda con fondo `deep`, grano,
  identidad del estudio, Inicio, Enlaces, Citas, Agenda y Cerrar sesión.
- El drawer se cierra al elegir una ruta, tocar el scrim o usar el botón de
  cierre. La ruta activa conserva el tratamiento cobre del rail.
- La navegación administrativa usa una transición de `fade + slide` sutil,
  compatible con `MediaQuery.disableAnimations`. No se cambia la navegación
  pública ni se duplican animaciones internas existentes más de lo necesario.
- El documento Web declara fondo tinta y esquema de color oscuro en `html` y
  `body`, para que el viewport expuesto por el teclado de iOS no muestre
  blanco. El `Scaffold` del login continúa usando `resizeToAvoidBottomInset` y
  el contenido seguirá siendo desplazable.

## Componentes y flujo

### Login Web

1. Safari enfoca Usuario o Contraseña.
2. El viewport puede reducirse por el teclado.
3. `html`, `body` y el root de Flutter conservan `#0A0A0B`/`#050505`.
4. El formulario se desplaza dentro de su `CustomScrollView` sin revelar una
   superficie blanca.

### Shell administrativo

1. `AdminShell` calcula el breakpoint existente.
2. En escritorio monta el rail permanente.
3. En móvil monta el encabezado y un drawer controlado por el shell.
4. Una selección del drawer ejecuta la navegación GoRouter y cierra el drawer.
5. La vista destino entra con la transición administrativa definida; el estado
   de Provider y los filtros de cada controller se mantienen.

## Transición

La transición de rutas administrativas combinará:

- opacidad de `0` a `1`;
- desplazamiento horizontal leve, aproximadamente `16 px`;
- curva `InkSlotMotion.standard`;
- duración aproximada de `360–450 ms`;
- duración cero o transición estática cuando `disableAnimations` esté activo.

El drawer tendrá una entrada lateral independiente, con scrim oscuro y una
curva de hoja coherente con `InkSlotMotion.sheet`. No se añadirá WebGL ni una
dependencia de navegación nueva.

## Pruebas

- El login conserva el fondo tinta en la estructura Web y mantiene sus pruebas
  de validación/error.
- En viewport móvil, el shell no renderiza la tab bar inferior y sí expone el
  botón hamburguesa y las opciones del drawer.
- El drawer navega a cada ruta, marca la opción activa y permite cerrar sesión.
- En viewport de escritorio se conserva el rail y no aparece el hamburguesa.
- La transición respeta `disableAnimations` y no altera la ruta final.
- `fvm flutter analyze`, pruebas admin/auth relacionadas y build Web pasan.

## Fuera de alcance

- Cambios en contratos NestJS, Prisma o autenticación.
- Rediseño de las pantallas públicas.
- Cambios en el prototipo HTML/ZIP o el PDF original.
- Sustituir el breakpoint de escritorio o reestructurar los controllers de
  Provider.

