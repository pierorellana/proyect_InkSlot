# Espaciado administrativo y canales de contacto — Implementation Plan

**Goal:** Reducir el espacio superior duplicado del panel administrativo y dejar el selector de nuevas solicitudes únicamente con WhatsApp y Correo.

**Architecture:** Añadir una regla compartida para calcular el padding superior de las pantallas que viven dentro de `AdminShell`, distinguiendo el contenido móvil que ya está debajo de un encabezado `SafeArea` del contenido desktop. Mantener `ContactChannel` completo en dominio/API y limitar solo las opciones de creación en `ContactChannelField`.

**Tech Stack:** Flutter Web 3.47.5 vía FVM, Dart, Provider existente, Flutter WidgetTester.

## Global Constraints

- Workspace con únicamente `app`, `api` y `context` como carpetas principales.
- No modificar el contrato backend ni eliminar valores históricos `instagram`/`phone`.
- No cambiar el login administrativo, porque no vive dentro de `AdminShell`.
- Conservar el diseño InkSlot; solo reducir espaciado superior y opciones visibles.
- Validar con `fvm flutter analyze`, pruebas Flutter y build Web.

### Task 1: Regla compartida de espaciado administrativo

**Files:**
- Create: `app/lib/features/admin/presentation/admin_layout.dart`
- Modify: `app/lib/features/dashboard/presentation/admin_dashboard_page.dart`
- Modify: `app/lib/features/requests/presentation/booking_requests_page.dart`
- Modify: `app/lib/features/requests/presentation/new_booking_request_page.dart`
- Modify: `app/lib/features/requests/presentation/link_ready_page.dart`
- Modify: `app/lib/features/requests/presentation/booking_request_detail_page.dart`
- Modify: `app/lib/features/appointments/presentation/admin_appointments_page.dart`
- Modify: `app/lib/features/appointments/presentation/admin_appointment_detail_page.dart`
- Modify: `app/lib/features/agenda/presentation/admin_agenda_page.dart`
- Modify: `app/lib/features/sync_issues/presentation/sync_issues_page.dart`
- Test: `app/test/features/admin/admin_layout_test.dart`

**Interfaces:**
- Produces `double adminPageTopInset(BuildContext context)`.
- Returns `20` for windows below 860 logical px and `28` for windows at or above 860 logical px.
- Pages inside `AdminShell` call this helper instead of using `MediaQuery.padding.top` with a 58 px minimum.

- [ ] **Step 1: Write the failing layout test**

```dart
testWidgets('uses compact content inset below the mobile admin header', (tester) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Text('${adminPageTopInset(context)}'),
      ),
    ),
  );
  expect(find.text('20.0'), findsOneWidget);
});
```

- [ ] **Step 2: Run the focused test and verify it fails**

Run from `app/`:

```bash
fvm flutter test test/features/admin/admin_layout_test.dart
```

Expected result: FAIL because `admin_layout.dart` and `adminPageTopInset` do not exist.

- [ ] **Step 3: Implement the shared inset helper**

```dart
import 'package:flutter/material.dart';

double adminPageTopInset(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= 860 ? 28 : 20;
```

- [ ] **Step 4: Replace duplicated 58 px calculations**

Each shell page replaces its local top calculation with:

```dart
final topInset = adminPageTopInset(context);
```

The dashboard keeps `0` for mobile only where its content intentionally begins with the greeting block, and uses `adminPageTopInset(context)` for desktop. The login page remains unchanged.

- [ ] **Step 5: Run the focused test and related page tests**

```bash
fvm flutter test \
  test/features/admin/admin_layout_test.dart \
  test/features/admin \
  test/features/dashboard \
  test/features/requests
```

Expected result: all tests pass and no page adds the old 58 px minimum inside `AdminShell`.

- [ ] **Step 6: Commit the layout slice**

```bash
git add app/lib/features/admin/presentation/admin_layout.dart \
  app/lib/features/dashboard/presentation/admin_dashboard_page.dart \
  app/lib/features/requests/presentation/booking_requests_page.dart \
  app/lib/features/requests/presentation/new_booking_request_page.dart \
  app/lib/features/requests/presentation/link_ready_page.dart \
  app/lib/features/requests/presentation/booking_request_detail_page.dart \
  app/lib/features/appointments/presentation/admin_appointments_page.dart \
  app/lib/features/appointments/presentation/admin_appointment_detail_page.dart \
  app/lib/features/agenda/presentation/admin_agenda_page.dart \
  app/lib/features/sync_issues/presentation/sync_issues_page.dart \
  app/test/features/admin/admin_layout_test.dart
git commit -m "fix(app): compact admin page spacing"
```

### Task 2: Limit new-request contact options

**Files:**
- Modify: `app/lib/features/requests/presentation/widgets/contact_channel_field.dart`
- Modify: `app/test/features/requests/new_booking_request_page_test.dart`

**Interfaces:**
- Add a private `availableChannels` list containing `ContactChannel.whatsapp` and `ContactChannel.email`.
- Existing `ContactChannel` enum parsing and API serialization remain unchanged.

- [ ] **Step 1: Update the widget test**

```dart
expect(find.text('WhatsApp'), findsOneWidget);
expect(find.text('Correo'), findsOneWidget);
expect(find.text('Instagram'), findsNothing);
expect(find.text('Teléfono'), findsNothing);
await tester.tap(find.text('Correo'));
await tester.pump();
expect(find.text('Correo electrónico'), findsOneWidget);
expect(find.text('cliente@correo.com'), findsOneWidget);
```

- [ ] **Step 2: Run the test and verify the old selector still exposes four options**

```bash
fvm flutter test test/features/requests/new_booking_request_page_test.dart
```

Expected result before implementation: FAIL because Instagram and Teléfono are still rendered.

- [ ] **Step 3: Implement the explicit visible-channel list**

```dart
static const availableChannels = <ContactChannel>[
  ContactChannel.whatsapp,
  ContactChannel.email,
];
```

Use this list for labels, selected index, and `onChanged`; keep the selected value fallback to WhatsApp if a legacy value is ever passed to the widget.

- [ ] **Step 4: Run the contact and request tests**

```bash
fvm flutter test test/features/requests/new_booking_request_page_test.dart
```

Expected result: all request tests pass, including WhatsApp submission and email label/hint behavior.

- [ ] **Step 5: Commit the contact slice**

```bash
git add app/lib/features/requests/presentation/widgets/contact_channel_field.dart \
  app/test/features/requests/new_booking_request_page_test.dart
git commit -m "fix(app): limit request contact channels"
```

### Task 3: Full verification and Web build

**Files:**
- No additional source files.

- [ ] **Step 1: Run static analysis**

```bash
fvm flutter analyze
```

Expected result: `No issues found!`.

- [ ] **Step 2: Run the affected Flutter suites**

```bash
fvm flutter test \
  test/features/auth \
  test/features/admin \
  test/features/dashboard \
  test/features/requests \
  test/features/appointments
```

Expected result: all tests pass.

- [ ] **Step 3: Build Web with the active tunnel API**

```bash
fvm flutter build web --no-wasm-dry-run \
  --dart-define=API_BASE_URL=https://9hqbzkgw-3000.use.devtunnels.ms/v1
```

Expected result: `Built build/web`.

- [ ] **Step 4: Verify repository state**

```bash
git diff --check
git status --short
```

Expected result: no whitespace errors and only intentional generated/build changes, if any, outside tracked source files.
