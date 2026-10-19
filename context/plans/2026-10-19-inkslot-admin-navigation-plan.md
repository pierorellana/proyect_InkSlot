# Admin Navigation and Web Keyboard Implementation Plan

> **For agentic workers:** Execute the tasks in order, preserving the existing SDD and using a focused commit after each independently verified slice.

**Goal:** Fix the white iOS Web keyboard backdrop, replace mobile admin bottom navigation with a hamburger drawer, and add a subtle accessible transition between admin routes.

**Architecture:** Keep the current `AdminShell` as the single responsive navigation boundary. Move the mobile presentation from a bottom tab bar to a shell-level header plus Flutter `Scaffold.drawer`; keep the desktop rail unchanged. Use `CustomTransitionPage` only for admin routes, while preserving Provider controllers and existing page-level animations.

**Tech Stack:** Flutter Web 3.47.5 through FVM, Provider, GoRouter, existing InkSlot tokens/widgets, Flutter Web HTML/CSS.

## Global Constraints

- Preserve the three workspace roots: `app`, `api`, and `context`.
- Do not change NestJS, Prisma, authentication contracts, public routes, the prototype HTML/ZIP, or the PDF.
- Preserve the `860 px` desktop breakpoint and the existing desktop rail.
- Use `InkSlotColors`, `InkSlotMotion`, local assets and existing accessibility/reduced-motion conventions.
- Keep touch targets at least `44 px` and do not persist navigation or session state.
- Verify with `fvm flutter test`, `fvm flutter analyze`, `fvm flutter build web`, and `git diff --check`.

---

### Task 1: Make the Flutter Web document dark behind the keyboard

**Files:**
- Modify: `app/web/index.html` in the document head/body styles.
- Test: `app/test/features/auth/admin_login_page_test.dart` only if a regression assertion is needed for the login viewport.

**Interfaces:**
- Consumes: `InkSlotColors.deep` (`#050505`) and `InkSlotColors.ink` (`#0A0A0B`).
- Produces: A Web document whose exposed viewport remains dark when iOS resizes the Flutter canvas for the virtual keyboard.

- [x] **Step 1: Add the failing/static regression check**

Verify the current document does not declare a dark `html/body` background:

```bash
rg -n "html|body|background|color-scheme" app/web/index.html
```

Expected before the change: no InkSlot dark document rule.

- [x] **Step 2: Add the Web surface rules**

Add a small inline style before `</head>`:

```html
<style>
  html,
  body {
    height: 100%;
    margin: 0;
    background: #050505;
    color-scheme: dark;
    overscroll-behavior: none;
  }

  body {
    overflow: hidden;
  }
</style>
```

The Flutter canvas remains responsible for scrolling inside the login page; the browser document must not paint a white overscroll area.

- [x] **Step 3: Verify the document and login behavior**

Run:

```bash
git diff --check
fvm flutter test test/features/auth/admin_login_page_test.dart
```

Expected: no whitespace errors and all login tests pass.

- [x] **Step 4: Commit**

```bash
git add app/web/index.html
git commit -m "fix(app): keep web login viewport dark"
```

### Task 2: Add the mobile admin header and drawer

**Files:**
- Modify: `app/lib/features/admin/presentation/admin_shell.dart`.
- Modify: `app/lib/core/widgets/inkslot_icon.dart` only if the approved icon set needs a reusable menu icon; prefer a local three-line painter to avoid adding an unapproved asset.
- Test: `app/test/features/admin/admin_router_test.dart`.

**Interfaces:**
- Consumes: `_AdminDestination`, `_destinationFor`, session controller and existing route paths.
- Produces: Mobile `AdminMobileHeader`, `AdminDrawer`, drawer route actions and a shell without `_AdminTabBar` below `860 px`.

- [x] **Step 1: Write failing responsive navigation tests**

Extend the existing shell test to assert on a `390 × 844` viewport:

```dart
expect(find.bySemanticsLabel('Abrir menú'), findsOneWidget);
expect(find.text('ENLACES'), findsNothing);
await tester.tap(find.bySemanticsLabel('Abrir menú'));
await tester.pumpAndSettle();
expect(find.text('Inicio'), findsOneWidget);
expect(find.text('Cerrar sesión'), findsOneWidget);
```

Add a desktop assertion that `Abrir menú` is absent and `Cerrar sesión` remains visible.

- [x] **Step 2: Run the shell tests and confirm the old mobile behavior**

Run:

```bash
fvm flutter test test/features/admin/admin_router_test.dart
```

Expected before the change: the current mobile test still finds `ENLACES` and does not find a hamburger.

- [x] **Step 3: Refactor `AdminShell` around one responsive `Scaffold`**

Use `LayoutBuilder` to create a `Scaffold` with:

```dart
drawer: isDesktop
    ? null
    : Drawer(
        child: _AdminDrawer(
          sessionController: sessionController,
          selected: selected,
        ),
      ),
```

Keep the desktop `Row` with `_AdminRail`. For mobile, compose:

```dart
Column(
  children: [
    _AdminMobileHeader(),
    Expanded(child: Stack(children: [content, grain])),
  ],
)
```

The header must expose `Semantics(label: 'Abrir menú', button: true)` and call
`Scaffold.of(context).openDrawer()` from a `Builder`. It should use the local
logo, `DODOGIO`, a compact 44 px action target and a custom three-line menu
mark in the InkSlot palette.

- [x] **Step 4: Implement drawer route behavior**

The drawer must list these exact destinations:

```text
Inicio       /admin
Enlaces      /admin/requests
Citas        /admin/appointments
Agenda       /admin/agenda
Nueva solicitud /admin/requests/new
Cerrar sesión sessionController.logout()
```

Each route action first closes the drawer with `Navigator.of(context).pop()`
and then calls `context.go(path)`. Use the active copper/tobacco treatment
already used by `_RailItem`; do not change API state or Provider lifetimes.

- [x] **Step 5: Remove dashboard header duplication**

Remove or reduce the dashboard page’s mobile-only identity header so the shell
header is the single logo/menu surface. Preserve the dashboard greeting,
session data and logout behavior through the drawer.

- [x] **Step 6: Run responsive tests and commit**

Run:

```bash
fvm flutter test test/features/admin/admin_router_test.dart
```

Expected: desktop keeps the rail, mobile exposes the hamburger and drawer, and
all route assertions pass.

```bash
git add app/lib/features/admin/presentation/admin_shell.dart app/lib/features/dashboard/presentation/admin_dashboard_page.dart app/test/features/admin/admin_router_test.dart
git commit -m "feat(app): add mobile admin navigation drawer"
```

### Task 3: Add accessible admin route transitions

**Files:**
- Modify: `app/lib/core/router/app_router.dart`.
- Test: `app/test/features/admin/admin_router_test.dart`.

**Interfaces:**
- Consumes: existing admin route builders and `InkSlotMotion.standard`.
- Produces: `_adminPage` returning `CustomTransitionPage<void>` for admin child routes.

- [x] **Step 1: Add a reduced-motion transition test**

Keep the router test’s `MediaQueryData(disableAnimations: true)` and assert that
navigation reaches the destination without waiting for an animation:

```dart
await tester.tap(find.text('CITAS'));
await tester.pump();
expect(find.byType(AdminAppointmentsPage), findsOneWidget);
```

- [x] **Step 2: Implement `_adminPage`**

Replace admin child route `builder:` entries with `pageBuilder:` entries that
call a helper of this shape:

```dart
Page<void> _adminPage({
  required GoRouterState state,
  required Widget child,
}) => CustomTransitionPage<void>(
  key: state.pageKey,
  transitionDuration: InkSlotMotion.screen,
  reverseTransitionDuration: const Duration(milliseconds: 260),
  child: child,
  transitionsBuilder: (context, animation, secondaryAnimation, child) {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return child;
    final curved = CurvedAnimation(
      parent: animation,
      curve: InkSlotMotion.standard,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(.025, 0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  },
);
```

Apply this only to routes under the admin shell; public deep links retain their
current routing and motion.

- [x] **Step 3: Verify navigation and commit**

Run:

```bash
fvm flutter test test/features/admin/admin_router_test.dart
fvm flutter analyze
git diff --check
git add app/lib/core/router/app_router.dart app/test/features/admin/admin_router_test.dart
git commit -m "feat(app): animate admin route transitions"
```

### Task 4: Full verification and Web build

**Files:**
- Verify only; no new source files.

- [x] **Step 1: Run focused login and admin tests**

```bash
fvm flutter test test/features/auth/admin_login_page_test.dart test/features/admin/admin_router_test.dart
```

- [ ] **Step 2: Run the complete Flutter suite and analyzer**

```bash
fvm flutter test
fvm flutter analyze
```

- [x] **Step 3: Regenerate the tunnel build**

```bash
fvm flutter build web --no-wasm-dry-run --dart-define=API_BASE_URL=https://9hqbzkgw-3000.use.devtunnels.ms/v1
```

- [x] **Step 4: Confirm the local web server and preserve unrelated work**

```bash
git diff --check
git status --short
```

The build must serve through the existing port `8080`. Any unrelated user
changes must remain unstaged and uncommitted.

## Ejecución 2026-10-19

- Commits: `d45e9a4`, `33bdd6a`, `2e29bf2`.
- Tests enfocados admin/dashboard/auth: 14/14 aprobados.
- `fvm flutter analyze`: sin issues.
- Build Web con `API_BASE_URL=https://9hqbzkgw-3000.use.devtunnels.ms/v1`: aprobado.
- La suite completa alcanzó 194 pruebas, pero conserva fallos fuera de este
  slice en `admin_appointment_detail_test.dart`,
  `new_booking_request_page_test.dart` y snapshots de booking; no se alteraron
  esos archivos.

