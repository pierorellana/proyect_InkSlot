# Diseño responsive de InkSlot para móviles, tablets y escritorio

**Fecha:** 2026-10-21  
**Estado:** aprobado para implementación  
**Alcance:** Flutter Web administrativo y flujo público de reserva

## Contexto

La interfaz actual conserva correctamente el diseño móvil, pero en iPad y
tablets verticales utiliza una composición demasiado estrecha: el shell
administrativo mantiene el tratamiento móvil hasta `860 px` y varias páginas
internas limitan su contenido a `640 px`. El resultado desaprovecha el ancho
disponible y hace que una tablet parezca un teléfono grande.

## Decisión

La adaptación se basará únicamente en el ancho disponible entregado por
`LayoutBuilder.constraints.maxWidth`. No se detectará hardware, plataforma ni
orientación, porque una ventana redimensionable debe conservar el mismo
comportamiento responsive.

### Breakpoints

| Ancho disponible | Composición | Navegación | Contenido |
|---|---|---|---|
| `0–599 px` | móvil existente | encabezado + hamburguesa | una columna |
| `600–1023 px` | tablet | rail compacto de aproximadamente `88 px`, iconos con tooltip | marco centrado hasta `860 px`, columnas cuando sea seguro |
| `1024 px+` | escritorio | rail completo de `248 px` con etiquetas | marco centrado hasta `1120 px` |

El comportamiento de `0–599 px` debe conservarse visual y funcionalmente sin
alterar el diseño móvil validado.

## Componentes y responsabilidades

### Shell administrativo

`AdminShell` seleccionará entre tres composiciones de navegación:

- compacto: encabezado actual y drawer;
- tablet: rail estrecho persistente con iconos y tooltips;
- escritorio: rail actual con iconos, etiquetas y usuario.

La navegación, las rutas GoRouter y los controllers Provider no cambian. Solo
se modifica la composición visual que rodea a la página activa.

### Marcos de página

Se añadirá un patrón de marco responsive para que las páginas administrativas
puedan usar el espacio disponible sin estirar indefinidamente textos y
formularios. Dashboard, solicitudes y citas podrán distribuir tarjetas en dos
columnas únicamente cuando las restricciones lo permitan. Formularios y
detalles conservarán una columna cuando dividirlos reduzca la legibilidad.

Las páginas públicas mantendrán sus componentes, paleta, tipografías, fondos,
animaciones y estados. En tablet solo se ampliará el marco y se centrará el
contenido; no se convertirá el flujo público en un dashboard ni se escalará
artificialmente toda la pantalla móvil.

### Accesibilidad y entradas

El rail compacto tendrá `Tooltip` y objetivos táctiles mínimos de `44 px`.
La navegación seguirá funcionando con mouse, trackpad, teclado y touch. No se
bloqueará la orientación.

## Pruebas y validación

- Widget tests del shell a `390 px`, `768 px` y `1024 px`.
- A `390 px` debe aparecer el encabezado con hamburguesa y no el rail.
- A `768 px` debe aparecer el rail compacto y no el drawer móvil.
- A `1024 px` debe aparecer el rail completo con etiquetas.
- Las páginas administrativas principales deben renderizar sin overflow en
  los tres anchos.
- Las páginas públicas deben conservar sus pruebas existentes y añadir una
  comprobación de marco centrado en tablet.
- Ejecutar `fvm flutter analyze`, pruebas Flutter y build Web de producción.

## Fuera de alcance

- Cambiar el diseño móvil validado.
- Cambiar contratos NestJS, Prisma, autenticación o navegación pública.
- Detectar iPad/tablet mediante `Platform`, user-agent u orientación.
- Agregar dependencias de layout o rediseñar componentes visuales.
- Modificar el prototipo HTML/ZIP o el PDF original.

