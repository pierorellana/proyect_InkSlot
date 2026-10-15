# InkSlot Visual Foundation Implementation Plan

> **For agentic workers:** execute this plan task-by-task with tests, visual evidence, and a focused commit after each independently verifiable slice.

**Goal:** Replace the Flutter bootstrap placeholder with a faithful, responsive InkSlot visual foundation and a navigable public slice from splash to welcome.

**Architecture:** Keep visual primitives in `app/lib/core` and public screens in `app/lib/features/public_booking/presentation`. Assets are copied from the provided prototype ZIP into `app/assets` and declared explicitly in `pubspec.yaml`; no screenshot is used as product UI. `GoRouter` owns `/` and `/r/:token`, while a small `ChangeNotifier` controls the splash lifecycle and respects reduced motion.

**Tech Stack:** Flutter Web 3.47.5 via FVM, Provider, GoRouter, `flutter_svg`, local WOFF2 assets, `AnimationController`, `AnimatedSwitcher`, `Transform`, and widget tests.

## Global Constraints

- Preserve `app/`, `api/`, and `context/` as the only project roots.
- Use Flutter 3.47.5 through `fvm`; do not use Riverpod or Bloc.
- Use the prototype ZIP as the source of truth for colors, typography, logo, illustrations, spacing, and motion.
- Reuse the licensed local SVG and WOFF2 assets; do not recreate or embed screenshots.
- Mobile-first reference viewport is 390×844, with responsive behavior for narrower mobile and desktop.
- Every interactive target is at least 44 px, every screen has semantics, and `MediaQuery.disableAnimations` disables non-essential motion.
- Public copy remains Spanish; provisional names and dates are presentation fixtures only and are not API/domain policy.
- Splash uses the approved 4.6 s visual timing only for the root entry; `/r/:token` skips directly to the welcome screen.
- Run `fvm dart format`, `fvm flutter analyze`, and focused widget tests before each commit.

---

### Task 1: Import the approved visual assets and tokens

**Files:**
- Create: `app/assets/fonts/Geist-Variable.woff2`
- Create: `app/assets/fonts/GeistMono-Regular.woff2`
- Create: `app/assets/fonts/GeistMono-Medium.woff2`
- Create: `app/assets/fonts/InstrumentSerif-Regular.woff2`
- Create: `app/assets/fonts/InstrumentSerif-Italic.woff2`
- Create: `app/assets/assets/logo/isotipo-D-cobre.svg`
- Create: `app/assets/assets/logo/isotipo-D-hueso.svg`
- Create: `app/assets/assets/logo/isotipo-D-tinta.svg`
- Create: `app/assets/assets/logo/lockup-hueso.svg`
- Create: `app/assets/assets/illustrations/flash-corazon.svg`
- Create: `app/assets/assets/illustrations/flash-daga.svg`
- Create: `app/assets/assets/illustrations/flash-luna.svg`
- Create: `app/assets/assets/illustrations/flash-ojo.svg`
- Create: `app/assets/assets/illustrations/flash-polilla.svg`
- Create: `app/assets/assets/illustrations/flash-rosa.svg`
- Modify: `app/pubspec.yaml`
- Create: `app/lib/core/theme/inkslot_tokens.dart`

**Interfaces:**
- Produces `InkSlotColors`, `InkSlotRadii`, `InkSlotSpacing`, and `InkSlotMotion` constants.
- Produces asset paths used by the logo and flash mosaic widgets.
- Consumes only the supplied ZIP assets and `design-system-and-motion.md`.

- [ ] **Step 1: Copy only the approved assets from the ZIP.**

Run from the workspace root:

```bash
mkdir -p app/assets/fonts app/assets/assets/logo app/assets/assets/illustrations
unzip -p context/references/InkSlot_Prototipo.zip 'InkSlot_Prototipo/assets/fuentes/Geist-Variable.woff2' > app/assets/fonts/Geist-Variable.woff2
unzip -p context/references/InkSlot_Prototipo.zip 'InkSlot_Prototipo/assets/fuentes/GeistMono-Regular.woff2' > app/assets/fonts/GeistMono-Regular.woff2
unzip -p context/references/InkSlot_Prototipo.zip 'InkSlot_Prototipo/assets/fuentes/GeistMono-Medium.woff2' > app/assets/fonts/GeistMono-Medium.woff2
unzip -p context/references/InkSlot_Prototipo.zip 'InkSlot_Prototipo/assets/fuentes/InstrumentSerif-Regular.woff2' > app/assets/fonts/InstrumentSerif-Regular.woff2
unzip -p context/references/InkSlot_Prototipo.zip 'InkSlot_Prototipo/assets/fuentes/InstrumentSerif-Italic.woff2' > app/assets/fonts/InstrumentSerif-Italic.woff2
for asset in isotipo-D-cobre isotipo-D-hueso isotipo-D-tinta lockup-hueso; do unzip -p context/references/InkSlot_Prototipo.zip "InkSlot_Prototipo/assets/logo/$asset.svg" > "app/assets/assets/logo/$asset.svg"; done
for asset in flash-corazon flash-daga flash-luna flash-ojo flash-polilla flash-rosa; do unzip -p context/references/InkSlot_Prototipo.zip "InkSlot_Prototipo/assets/ilustraciones/$asset.svg" > "app/assets/assets/illustrations/$asset.svg"; done
```

Expected: only the five font files, four logo files, and six illustration files are added under `app/assets`.

- [ ] **Step 2: Register the assets and fonts in `app/pubspec.yaml`.**

The Flutter section must contain:

```yaml
  uses-material-design: true
  assets:
    - assets/assets/logo/
    - assets/assets/illustrations/
  fonts:
    - family: Geist
      fonts:
        - asset: assets/fonts/Geist-Variable.woff2
    - family: Geist Mono
      fonts:
        - asset: assets/fonts/GeistMono-Regular.woff2
        - asset: assets/fonts/GeistMono-Medium.woff2
          weight: 500
    - family: Instrument Serif
      fonts:
        - asset: assets/fonts/InstrumentSerif-Regular.woff2
        - asset: assets/fonts/InstrumentSerif-Italic.woff2
          style: italic
```

- [ ] **Step 3: Encode the exact token set in `inkslot_tokens.dart`.**

Define immutable constants for `#050505`, `#0A0A0B`, `#131315`, `#1C1C1F`, `#EEE9E0`, `#F2ECE2`, `#A7A29A`, `#9B968E`, `#C87939`, `#D48A45`, `#241A12`, and semantic green/yellow/coral. Define radii 28/24/38/26/20, spacing 20/24, and durations 200/550/600/4600 milliseconds.

- [ ] **Step 4: Run asset and token checks.**

Run:

```bash
cd app
fvm flutter pub get
fvm flutter analyze
fvm flutter test
```

Expected: all existing tests pass and no asset declaration errors occur.

- [ ] **Step 5: Commit.**

```bash
git add app/assets app/pubspec.yaml app/pubspec.lock app/lib/core/theme/inkslot_tokens.dart
git commit -m "feat(app): add InkSlot visual assets and tokens"
```

---

### Task 2: Build the typography-aware theme and reusable visual primitives

**Files:**
- Modify: `app/lib/core/theme/inkslot_theme.dart`
- Create: `app/lib/core/widgets/inkslot_logo.dart`
- Create: `app/lib/core/widgets/inkslot_mono_label.dart`
- Create: `app/lib/core/widgets/inkslot_primary_button.dart`
- Create: `app/lib/core/widgets/inkslot_page.dart`
- Create: `app/test/core/visual_primitives_test.dart`

**Interfaces:**
- `InkSlotLogo({required Color color, double size = 64, Key? key})` renders the supplied SVG with semantics.
- `InkSlotMonoLabel(String text, {Color? color, Key? key})` applies Geist Mono, 11 px, uppercase, and letter spacing.
- `InkSlotPrimaryButton({required String label, required VoidCallback? onPressed, Widget? trailing, Key? key})` renders a 44 px minimum copper CTA.
- `InkSlotPage({required Widget child, EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(20, 24, 20, 34), Key? key})` provides the dark responsive page surface.

- [ ] **Step 1: Write widget tests for typography, semantics, and target size.**

Test that the logo has a non-empty semantic label, the mono label uppercases its text, and the primary button has at least 44 px height and invokes its callback.

- [ ] **Step 2: Implement the theme.**

Use `ThemeData.dark` with `fontFamily: 'Geist'`, `headline` styles in `Instrument Serif`, mono labels in `Geist Mono`, surface `#131315`, background `#050505`, copper primary, 28 px button radius, and no default splash color that conflicts with the copper treatment.

- [ ] **Step 3: Implement the primitives with `flutter_svg`.**

Use `SvgPicture.asset` for the D logo and exact local asset paths. Keep the button's visual state in Flutter's `MaterialStateProperty`; use a copper glow only for enabled/pressed states.

- [ ] **Step 4: Run the focused tests and analyze.**

```bash
cd app
fvm dart format lib test
fvm flutter analyze
fvm flutter test test/core/visual_primitives_test.dart
```

- [ ] **Step 5: Commit.**

```bash
git add app/lib/core app/test/core
git commit -m "feat(app): add InkSlot theme primitives"
```

---

### Task 3: Implement the public splash and welcome slice

**Files:**
- Create: `app/lib/features/public_booking/presentation/public_splash_page.dart`
- Create: `app/lib/features/public_booking/presentation/public_welcome_page.dart`
- Create: `app/lib/features/public_booking/presentation/widgets/flash_mosaic.dart`
- Create: `app/lib/features/public_booking/presentation/public_entry_controller.dart`
- Modify: `app/lib/core/router/app_router.dart`
- Modify: `app/lib/app.dart`
- Modify: `app/test/smoke_test.dart`
- Create: `app/test/features/public_booking/public_entry_test.dart`

**Interfaces:**
- `PublicEntryController extends ChangeNotifier` exposes `bool get shouldSkipSplash`, `void skip()`, and `bool get isComplete`.
- `PublicSplashPage({required VoidCallback onFinished, Key? key})` presents the D/wordmark animation and skip-intro affordance.
- `PublicWelcomePage({required String token, required VoidCallback onChooseDate, Key? key})` presents the private-link welcome state without calling the API.
- `/` shows splash then welcome; `/r/:token` opens welcome directly with its opaque token kept in route state only.

- [ ] **Step 1: Write route and entry widget tests.**

Cover root rendering, skip action, deep link `/r/demo-token` bypassing splash, and the primary welcome CTA navigating to `/r/demo-token/dates` placeholder route. Test with `MediaQuery.disableAnimations` so tests do not wait 4.6 s.

- [ ] **Step 2: Implement the splash.**

Use `AnimationController` with the approved `coinIn`, `sway`, `draw`, `drop`, `ripple`, `halo`, and `wm` sequence. Reuse the D SVG and render the copper glow using layered `DecoratedBox`/`CustomPaint`; do not use the screenshot as a background. Show `SALTAR INTRO` as a 44 px minimum target. If animations are disabled, call `onFinished` immediately after the first frame.

- [ ] **Step 3: Implement the welcome.**

Recreate the six-card flash mosaic with alternating vertical movement, the private-link chip, mono copper status, Instrument Serif headline, summary card, artist row, copper CTA, and help link from the reference capture. Keep the sample display values clearly presentation-only and make the CTA route-only until the availability slice exists.

- [ ] **Step 4: Add responsive constraints and navigation.**

Use `LayoutBuilder` with a 390 px content baseline, clamp horizontal padding between 20 and 24 px, preserve scrollability on short screens, and provide `/r/:token/dates` as a route placeholder that does not claim availability exists.

- [ ] **Step 5: Run focused and complete frontend checks.**

```bash
cd app
fvm dart format lib test
fvm flutter analyze
fvm flutter test
fvm flutter build web
```

Expected: all tests pass, the build contains local font/SVG assets, and no screenshot asset is referenced by Dart code.

- [ ] **Step 6: Commit.**

```bash
git add app/lib app/test app/pubspec.yaml app/pubspec.lock
git commit -m "feat(app): add public splash and welcome slice"
```

---

### Task 4: Record visual parity evidence

**Files:**
- Create: `context/quality/visual-parity.md`
- Modify: `context/tasks/backlog.md` only for the completed visual slice.

**Interfaces:**
- Records the reference captures, viewport, tested states, and known gaps without introducing new product requirements.

- [ ] **Step 1: Run the app at the reference viewport.**

```bash
cd app
fvm flutter run -d chrome --web-port 8080
```

Inspect at 390×844 and a desktop width. Compare splash and welcome against `01-cliente-splash.jpg` and `02-cliente-bienvenida.jpg` from the ignored prototype ZIP.

- [ ] **Step 2: Record evidence.**

Document typography, colors, logo, card composition, CTA, responsive behavior, reduced motion, and any intentional gap. Do not add screenshots to Git.

- [ ] **Step 3: Commit the evidence.**

```bash
git add context/quality/visual-parity.md context/tasks/backlog.md
git commit -m "docs(context): record visual foundation parity"
```

## Verification summary

The plan is complete only when the visual assets are local and licensed, the theme uses the exact prototype tokens, root and token routes render the public entry states, widget tests cover semantics and navigation, `fvm flutter build web` passes, and parity evidence is recorded. Availability, booking data, and admin flows remain separate slices.
