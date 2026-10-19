# Compartir enlace de reserva — Implementation Plan

**Goal:** Limitar la hoja de compartir a WhatsApp/Más y enviar un mensaje profesional con el enlace privado.

**Architecture:** Mantener la construcción del enlace en `LinkReadyPage`, extraer un formateador determinista para el texto compartido y separar las acciones WhatsApp/directa y Más/nativa. Reutilizar `openExternalLink` para no duplicar la integración con `url_launcher`.

**Tech Stack:** Flutter Web 3.47.5 vía FVM, `share_plus`, `url_launcher`, Flutter WidgetTester.

## Tasks

### Task 1: Mensaje y destinos de compartir

**Files:**
- Modify: `app/lib/features/requests/presentation/link_ready_page.dart`
- Modify: `app/test/features/requests/link_ready_page_test.dart`

- [ ] Crear `buildBookingShareMessage` con parámetros deterministas para URL, nombre, duración y vigencia.
- [ ] Cambiar `_ShareSheet` para mostrar solo WhatsApp y Más.
- [ ] Hacer que WhatsApp abra `Uri.https('wa.me', '/', {'text': message})` mediante `openExternalLink`.
- [ ] Hacer que Más llame `SharePlus.instance.share(ShareParams(text: message))`.
- [ ] Agregar pruebas del mensaje y de las opciones visibles.
- [ ] Ejecutar la prueba enfocada y corregir cualquier regresión.
- [ ] Commit: `feat(app): improve booking link sharing`.

### Task 2: Verificación final

- [ ] Ejecutar `fvm flutter analyze`.
- [ ] Ejecutar las suites de solicitudes, admin y dashboard.
- [ ] Ejecutar `fvm flutter build web --no-wasm-dry-run --dart-define=API_BASE_URL=https://9hqbzkgw-3000.use.devtunnels.ms/v1`.
- [ ] Ejecutar `git diff --check` y verificar estado limpio.
