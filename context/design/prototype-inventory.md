# Inventario y fidelidad al prototipo real

Origen: `InkSlot_Prototipo.zip/InkSlot_Prototipo/README.md`, archivos y capturas del ZIP entregado.

## Pantallas cliente
`01-cliente-splash.jpg`, `02-cliente-bienvenida.jpg`, `03-cliente-calendario-vacio.jpg`, `04-cliente-calendario-dia.jpg`, `05-cliente-horarios-cargando.jpg`, `06-cliente-horarios.jpg`, `07-cliente-horarios-rueda.jpg`, `08-cliente-revision.jpg`, `09-cliente-confirmando.jpg`, `10-cliente-exito.jpg`, `11-cliente-vencido.jpg`, `12-cliente-cancelado.jpg`, `13-cliente-sin_red.jpg`, `14-cliente-sin_horarios.jpg`, `15-cliente-agenda-no-verificable.jpg`, `16-cliente-conflicto-409.jpg`, `17-cliente-sincronizacion-pendiente.jpg`.

## Pantallas admin
`20-tatuador-login.jpg`, `21-tatuador-login-error.jpg`, `22-tatuador-inicio.jpg`, `23-tatuador-incidencia.jpg`, `24-tatuador-incidencia-resuelta.jpg`, `25-tatuador-nueva-solicitud.jpg`, `26-tatuador-nueva-solicitud-completa.jpg`, `27-tatuador-enlace-listo.jpg`, `28-tatuador-enlace-copiado.jpg`, `29-tatuador-compartir.jpg`, `30-tatuador-solicitudes.jpg`, `31-tatuador-solicitud-vencida.jpg`, `32-tatuador-citas.jpg`, `33-tatuador-cita.jpg`, `34-tatuador-reprogramar.jpg`, `35-tatuador-cancelar.jpg`, `36-tatuador-agenda.jpg`, `37-tatuador-reconectar-calendar.jpg`.

Además `00-ejecutable.jpg`, `40-identidad.jpg`, `41-estados.jpg` (38 capturas totales según README).

## Archivos fuente prioritarios
`prototipo/InkSlot_Prototipo.html`; `pantallas/{Cliente,Tatuador,Identidad,Estados}.html`; `fuente-canvas/{Main,Admin,Marca,Estados}.dc.html`; `design-tokens/{tokens.json,tokens.css}`; `animaciones/{keyframes.css,estilos-cliente.css,estilos-tatuador.css}`; `assets/logo`, `assets/iconos`, `assets/ilustraciones`, `assets/fuentes`.

## Escenarios directos del HTML
Cliente URL params `estado=activo|vencido|cancelado|agendado|sin_horarios|sin_red|error_agenda`, `conflicto=true`, `sincronizacion=pendiente`, `saltarIntro=true`.
Admin: `calendario=reconectar`, `incidencias=false`, `saltarLogin=true`.

## Protocolo de comparación
1. Render Flutter en 390×844 y también móvil pequeño / desktop; validar navegabilidad real sin mockup teléfono.
2. Comparar captura por captura tipografía, contraste, espacio, radio, animaciones, botones, CTA y safe areas.
3. Señalar gaps en matriz `quality/visual-parity.md`.
4. Preferir fidelidad al prototipo final sobre prompts antiguos (p. ej. el cobre reemplaza el rojo primario).
