# InkSlot — mosaico responsive de tres columnas

Fecha: 2026-10-16  
Estado: aprobado para implementación

## Objetivo

Hacer visibles simultáneamente las tres columnas del mosaico de flashes en la pantalla pública de bienvenida, especialmente en teléfonos, sin cambiar la identidad visual ni la animación del prototipo.

## Diagnóstico

`FlashMosaic` ya construye tres columnas, pero su contenedor usa un ancho fijo de `540px`, un desplazamiento horizontal fijo y una rotación de `-13°`. En viewports móviles, ese lienzo excede el ancho visible y solo dos columnas aparecen completas.

## Diseño aprobado

El widget conservará su composición de tres columnas y calculará el ancho del mosaico a partir del ancho disponible:

- `LayoutBuilder` será la fuente del ancho del viewport.
- El ancho útil del mosaico se limitará al viewport con un pequeño bleed horizontal para mantener el carácter editorial del fondo.
- El ancho de cada columna se calculará después de descontar los dos gaps.
- La altura de las tarjetas, su separación vertical, radio, paleta, ilustraciones y texto permanecen sin cambios.
- Se conserva la rotación de `-13°`, los offsets de las columnas y los controladores `up`/`dn`.
- El fundido inferior de `260px` permanece intacto para que el contenido de la reserva mantenga legibilidad.

En pantallas anchas no se forzará un mosaico excesivamente grande: se mantiene un ancho máximo visual. En teléfonos, las tarjetas se estrechan proporcionalmente para que las tres columnas entren en el bloque visible.

## Alcance y no alcance

El cambio se limita a `app/lib/features/public_booking/presentation/widgets/flash_mosaic.dart`. No modifica la API, el modelo de reserva, el contenido de la pantalla, los assets, la tipografía, la paleta ni la navegación.

No se agregan imágenes, columnas de datos ni un carrusel interactivo. El término carrusel se refiere únicamente al mosaico animado de fondo existente.

## Verificación

- Formatear el archivo y ejecutar los tests Flutter existentes.
- Ejecutar `fvm flutter analyze`.
- Ejecutar `fvm flutter build web` con el `API_BASE_URL` del túnel.
- Revisar que el mosaico siga usando tres columnas y que el cambio no altere los estados offline, booked o loading.
