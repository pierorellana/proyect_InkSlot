# InkSlot responsive layout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Adapt InkSlot Web to tablet and iPad widths while preserving the current mobile composition and visual language.

**Architecture:** Centralize width classification in a pure Dart helper based on `LayoutBuilder` constraints. Reuse that classification in the admin shell, page frames, dashboard cards, and public screen frame. Routes, Provider controllers, API contracts, design tokens, assets, animations, and the current compact mobile composition remain unchanged.

**Tech Stack:** Flutter Web 3.47.5, Dart, Provider, GoRouter, existing InkSlot widgets and design tokens.

## Global Constraints

- Mobile widths below 600 px must preserve the current visual composition and hamburger navigation.
- Tablet widths from 600 px through 1023 px use a compact persistent navigation rail and centered content.
- Desktop widths from 1024 px use the existing full navigation rail and wider content.
- All layout decisions use available constraints; do not detect hardware type or orientation.
- Do not change backend behavior, routes, API contracts, authentication, public booking copy, colors, typography, assets, or animation policy.
- Keep touch targets at least 44 px where navigation controls are interactive.
- Every slice must include focused tests and a small commit.

---

### Task 1: Add shared responsive width classification

**Files:**
- Create: `app/lib/core/layout/inkslot_breakpoints.dart`
- Create: `app/test/core/layout/inkslot_breakpoints_test.dart`
- Modify: `app/lib/features/admin/presentation/admin_layout.dart`
- Modify: `app/test/features/admin/admin_layout_test.dart`

**Interfaces:**
- Produces `InkSlotScreenClass inkSlotScreenClassForWidth(double width)`.
- Produces `double adminPageMaxWidthFor(double width)`.
- Produces `AdminPageFrame`, a widget that centers a page and applies the max width selected from the available constraint.

- [ ] **Step 1: Write failing breakpoint tests**

Create tests covering the three boundary classes and page max widths:

```dart
test('classifies compact, tablet, and desktop widths', () {
  expect(inkSlotScreenClassForWidth(390), InkSlotScreenClass.compact);
  expect(inkSlotScreenClassForWidth(600), InkSlotScreenClass.tablet);
  expect(inkSlotScreenClassForWidth(1023.99), InkSlotScreenClass.tablet);
  expect(inkSlotScreenClassForWidth(1024), InkSlotScreenClass.desktop);
});

test('keeps page widths bounded by screen class', () {
  expect(adminPageMaxWidthFor(390), 640);
  expect(adminPageMaxWidthFor(768), 860);
  expect(adminPageMaxWidthFor(1280), 1120);
});
```

Run: `cd app && fvm flutter test test/core/layout/inkslot_breakpoints_test.dart`

Expected: FAIL because the helper does not exist.

- [ ] **Step 2: Implement the pure helper**

Create the enum and functions with these exact thresholds and max widths:

```dart
enum InkSlotScreenClass { compact, tablet, desktop }

InkSlotScreenClass inkSlotScreenClassForWidth(double width) {
  if (width < 600) return InkSlotScreenClass.compact;
  if (width < 1024) return InkSlotScreenClass.tablet;
  return InkSlotScreenClass.desktop;
}

double adminPageMaxWidthFor(double width) {
  switch (inkSlotScreenClassForWidth(width)) {
    case InkSlotScreenClass.compact:
      return 640;
    case InkSlotScreenClass.tablet:
      return 860;
    case InkSlotScreenClass.desktop:
      return 1120;
  }
}
```

- [ ] **Step 3: Add the reusable admin page frame**

Implement `AdminPageFrame` in `admin_layout.dart` using `LayoutBuilder`, `Align(alignment: Alignment.topCenter)`, and `ConstrainedBox`. Pass the original child through unchanged and derive `maxWidth` from `constraints.maxWidth`.

Update `adminPageTopInset` so widths below 1024 return 20 and desktop widths return 28; retain existing 390 and 1280 behavior.

- [ ] **Step 4: Run focused tests**

Run: `cd app && fvm flutter test test/core/layout/inkslot_breakpoints_test.dart test/features/admin/admin_layout_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

Run:

```bash
git add app/lib/core/layout/inkslot_breakpoints.dart app/test/core/layout/inkslot_breakpoints_test.dart app/lib/features/admin/presentation/admin_layout.dart app/test/features/admin/admin_layout_test.dart
git commit -m "feat(layout): add responsive screen classes"
```

---

### Task 2: Add the tablet admin navigation rail

**Files:**
- Modify: `app/lib/features/admin/presentation/admin_shell.dart`
- Modify: `app/test/features/admin/admin_router_test.dart`

**Interfaces:**
- `_AdminRail` accepts `compact: bool`.
- Compact rail width is 88 px and desktop rail width remains 248 px.
- Compact rail exposes the same navigation destinations through icon buttons with tooltips.

- [ ] **Step 1: Add the tablet navigation assertions**

Extend the existing shell test with a 768 px viewport. Assert that the hamburger button is absent, the rail exposes the Inicio destination, the expanded Cerrar sesión label is absent, and tapping the rail Enlaces destination still navigates to `/admin/links`. Keep the existing 390 px and 1200 px assertions unchanged.

- [ ] **Step 2: Run the focused test to verify the new behavior fails**

Run: `cd app && fvm flutter test test/features/admin/admin_router_test.dart`

Expected: FAIL for the new 768 px assertions because the current shell treats 768 px as mobile.

- [ ] **Step 3: Implement the three shell compositions**

Use `LayoutBuilder` and `inkSlotScreenClassForWidth(constraints.maxWidth)`:

- compact: current Column with mobile header and drawer;
- tablet: Row with `_AdminRail(compact: true)` and `_AdminSurface`;
- desktop: existing Row with `_AdminRail()` and `_AdminSurface`.

Keep the drawer only for compact mode. Do not change route definitions or Provider ownership.

- [ ] **Step 4: Implement the compact rail presentation**

Add `compact` to `_AdminRail`. For compact mode:

- use width 88;
- keep the selected-state background and existing icons;
- hide text labels and the expanded account tile;
- wrap each destination in `Tooltip(message: label)`;
- keep the existing logout action as an icon-only tooltip action;
- preserve minimum 44 px hit targets.

For desktop mode, retain the current 248 px rail and labels exactly.

- [ ] **Step 5: Run the focused test**

Run: `cd app && fvm flutter test test/features/admin/admin_router_test.dart`

Expected: PASS for compact, tablet, and desktop navigation assertions.

- [ ] **Step 6: Commit**

Run:

```bash
git add app/lib/features/admin/presentation/admin_shell.dart app/test/features/admin/admin_router_test.dart
git commit -m "feat(admin): add tablet navigation rail"
```

---

### Task 3: Expand admin page frames and dashboard composition

**Files:**
- Modify: `app/lib/features/dashboard/presentation/admin_dashboard_page.dart`
- Modify: `app/lib/features/requests/presentation/booking_requests_page.dart`
- Modify: `app/lib/features/requests/presentation/booking_request_detail_page.dart`
- Modify: `app/lib/features/requests/presentation/link_ready_page.dart`
- Modify: `app/lib/features/requests/presentation/new_booking_request_page.dart`
- Modify: `app/lib/features/appointments/presentation/admin_appointments_page.dart`
- Modify: `app/lib/features/appointments/presentation/admin_appointment_detail_page.dart`
- Modify: `app/lib/features/agenda/presentation/admin_agenda_page.dart`
- Modify: `app/lib/features/sync_issues/presentation/sync_issues_page.dart`
- Modify: focused tests under `app/test/features/` for each affected page

**Interfaces:**
- All affected admin pages use `AdminPageFrame` instead of a hard-coded 640 px outer constraint.
- The dashboard keeps horizontal pending cards on compact widths and uses a wrapping layout when the available content width is at least 720 px.
- Upcoming appointments remain full-width within the responsive page frame.

- [ ] **Step 1: Add 768 px widget tests**

For dashboard, requests, appointments, agenda, and sync issues, pump each page at 768 px and assert no `RenderFlex overflowed` error is reported. For the dashboard, assert that at least two pending cards can be visible without requiring the compact mobile horizontal scroller.

- [ ] **Step 2: Run the focused tests before implementation**

Run:

```bash
cd app
fvm flutter test test/features/dashboard/admin_dashboard_page_test.dart test/features/requests/booking_requests_page_test.dart test/features/appointments/admin_appointments_page_test.dart test/features/agenda/agenda_test.dart test/features/sync_issues/sync_issues_page_test.dart
```

Expected: the new tablet assertions fail or expose the current fixed-width behavior.

- [ ] **Step 3: Replace fixed page wrappers**

In every listed page, replace the outer `ConstrainedBox(maxWidth: 640)` pattern with `AdminPageFrame(child: ...)`. Keep each page’s existing scroll behavior, padding, title, cards, controllers, and callbacks unchanged.

- [ ] **Step 4: Make dashboard pending content width-aware**

Wrap the pending section in `LayoutBuilder`. Use the existing horizontal `SingleChildScrollView` for content widths below 720 px. At 720 px and above, use a `Wrap` with the existing card minimum width and spacing so two or more cards can occupy the tablet row. Keep the “Nueva solicitud” card and all existing card actions.

- [ ] **Step 5: Run focused tests after implementation**

Run the same focused test command from Step 2.

Expected: PASS with no overflow at 390 px and 768 px, and existing desktop tests remain green.

- [ ] **Step 6: Commit**

Run:

```bash
git add app/lib/features/dashboard/presentation/admin_dashboard_page.dart app/lib/features/requests/presentation/booking_requests_page.dart app/lib/features/requests/presentation/booking_request_detail_page.dart app/lib/features/requests/presentation/link_ready_page.dart app/lib/features/requests/presentation/new_booking_request_page.dart app/lib/features/appointments/presentation/admin_appointments_page.dart app/lib/features/appointments/presentation/admin_appointment_detail_page.dart app/lib/features/agenda/presentation/admin_agenda_page.dart app/lib/features/sync_issues/presentation/sync_issues_page.dart app/test/features
git commit -m "feat(admin): expand tablet page layouts"
```

---

### Task 4: Expand the public booking frame on tablets

**Files:**
- Modify: `app/lib/features/public_booking/presentation/widgets/public_chrome.dart`
- Modify: `app/test/features/public_booking/public_entry_test.dart`
- Modify: `app/test/features/public_booking/public_router_test.dart`

**Interfaces:**
- `PublicScreen` keeps a 560 px max content width below 600 px.
- `PublicScreen` uses a 760 px max content width from 600 px upward.
- Safe-area padding, grain overlay, visual tokens, animations, and public route behavior are unchanged.

- [ ] **Step 1: Add viewport assertions**

Pump the public welcome/review frame at 390 px and 768 px. Assert that compact content remains at most 560 px and tablet content is wider than compact but bounded by 760 px. Keep deep-link route assertions unchanged.

- [ ] **Step 2: Run the focused tests to verify the new assertion fails**

Run:

```bash
cd app
fvm flutter test test/features/public_booking/public_entry_test.dart test/features/public_booking/public_router_test.dart
```

Expected: the tablet width assertion fails because `PublicScreen` currently always uses 560 px.

- [ ] **Step 3: Implement the width-aware public frame**

Wrap the existing centered `ConstrainedBox` in `LayoutBuilder`. Select 560 px for compact widths and 760 px for tablet/desktop widths. Do not alter the `SafeArea`, background, grain, route builder, or child content.

- [ ] **Step 4: Run focused public tests**

Run the same command from Step 2.

Expected: PASS.

- [ ] **Step 5: Commit**

Run:

```bash
git add app/lib/features/public_booking/presentation/widgets/public_chrome.dart app/test/features/public_booking/public_entry_test.dart app/test/features/public_booking/public_router_test.dart
git commit -m "feat(public): adapt booking frame to tablet widths"
```

---

### Task 5: Validate all responsive states and production build

**Files:**
- Modify only files required by test or analyzer feedback.
- Verify: `app/lib/core/layout/inkslot_breakpoints.dart`, admin shell/pages, public frame, and their tests.

- [ ] **Step 1: Run static analysis**

Run: `cd app && fvm flutter analyze`

Expected: zero new errors or warnings caused by the responsive changes.

- [ ] **Step 2: Run the complete Flutter test suite**

Run: `cd app && fvm flutter test`

Expected: all existing and new tests pass at their configured viewports.

- [ ] **Step 3: Build the Netlify artifact**

Run: `cd app && fvm flutter build web --release --dart-define=API_BASE_URL=https://inkslot-app.netlify.app/v1`

Expected: release web build completes and writes `app/build/web`.

- [ ] **Step 4: Check repository hygiene**

Run:

```bash
git diff --check
git status --short
find . -maxdepth 1 -type d -print
```

Expected: no whitespace errors, only intentional tracked changes, and only `app`, `api`, and `context` as project directories (plus repository metadata).

- [ ] **Step 5: Commit any final test-only correction**

Run:

```bash
git add app
git commit -m "test(responsive): validate tablet and desktop layouts"
```

If no correction is needed, do not create an empty commit.


