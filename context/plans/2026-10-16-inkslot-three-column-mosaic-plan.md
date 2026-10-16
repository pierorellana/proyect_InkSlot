# InkSlot responsive three-column mosaic Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mostrar simultáneamente las tres columnas del mosaico animado de flashes dentro del ancho disponible en teléfonos, conservando el diseño aprobado.

**Architecture:** `FlashMosaic` seguirá siendo el único responsable del fondo visual. `LayoutBuilder` calculará el ancho del lienzo y el ancho de cada columna; los controladores `up` y `down`, la rotación, el fade inferior y `_MosaicColumn` conservarán sus responsabilidades actuales. Una prueba widget verificará que la fila del mosaico contiene tres columnas y dos gaps.

**Tech Stack:** Flutter Web 3.47.5 mediante FVM, Dart, `flutter_test`, Provider existente sin cambios.

## Global Constraints

- Mantener tres columnas visibles y la rotación `-13°` del prototipo.
- Mantener altura de tarjeta `200px`, separación vertical `14px`, radio, assets, tipografías, paleta y animaciones `up`/`dn`.
- El ancho debe adaptarse al viewport móvil y tener un máximo visual en pantallas anchas.
- No modificar API, navegación, estados de reserva ni dependencias.
- Respetar `MediaQuery.disableAnimationsOf(context)`.
- No incluir los cambios preexistentes de `app/lib/features/public_booking/presentation/public_welcome_page.dart` ni `public_review_page.dart` en el commit de este slice.

---

### Task 1: Hacer responsive la fila del mosaico

**Files:**
- Modify: `app/lib/features/public_booking/presentation/widgets/flash_mosaic.dart`
- Test: `app/test/features/public_booking/flash_mosaic_test.dart`

**Interfaces:**
- Consumes: constraints de `LayoutBuilder` y los widgets privados `_MosaicColumn`/`_FlashTile` existentes.
- Produces: `FlashMosaic` con una fila identificable por `ValueKey('flash-mosaic-columns')`, cinco hijos estructurales —columna, gap, columna, gap, columna— y tres columnas visibles en un viewport de teléfono.

- [x] **Step 1: Escribir la prueba widget estructural**

Crear `app/test/features/public_booking/flash_mosaic_test.dart` con una superficie móvil de `390x844`, desactivar animaciones y comprobar que la fila del mosaico identificado contiene tres columnas y dos gaps:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/features/public_booking/presentation/widgets/flash_mosaic.dart';

void main() {
  testWidgets('renders three mosaic columns in the mobile viewport', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: FlashMosaic()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final row = tester.widget<Row>(
      find.byKey(const ValueKey('flash-mosaic-columns')),
    );

    expect(row.children, hasLength(5));
    expect(row.children.whereType<Expanded>(), hasLength(3));
    expect(row.children.whereType<SizedBox>(), hasLength(2));
  });
}
```

- [x] **Step 2: Ejecutar la prueba para confirmar el fallo**

Run from `app`:

```bash
fvm flutter test test/features/public_booking/flash_mosaic_test.dart
```

Expected: FAIL porque `FlashMosaic` todavía no expone la key `flash-mosaic-columns` y el test no encuentra el `Row` responsive.

- [x] **Step 3: Implementar el cálculo responsive mínimo**

En `FlashMosaic.build`, reemplazar el `Positioned` de ancho fijo por un `Positioned` con `left: -14` y `right: -14`. Su `LayoutBuilder` debe limitar el ancho a `620px`, centrarlo y conservar exactamente los tres `_MosaicColumn` existentes:

```dart
LayoutBuilder(
  builder: (context, constraints) {
    final availableWidth = constraints.maxWidth.isFinite
        ? constraints.maxWidth
        : 418.0;
    final mosaicWidth = math.min(availableWidth, 620.0);

    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: mosaicWidth,
        child: Transform.rotate(
          angle: -13 * math.pi / 180,
          child: Row(
            key: const ValueKey('flash-mosaic-columns'),
            children: [
              Expanded(
                child: _MosaicColumn(
                  animation: _up,
                  offset: 0,
                  reverse: false,
                ),
              ),
              const SizedBox(width: _tileGap),
              Expanded(
                child: _MosaicColumn(
                  animation: _down,
                  offset: 2,
                  reverse: true,
                ),
              ),
              const SizedBox(width: _tileGap),
              Expanded(
                child: _MosaicColumn(
                  animation: _up,
                  offset: 4,
                  reverse: false,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  },
)
```

El ancho de cada tarjeta será el ancho natural de su `Expanded`; conservar el `height` calculado con `_tilesPerColumn`, el `top: -150`, el `ClipRect` y los controladores actuales. El `Transform.rotate` debe quedar dentro del ancho responsive para que el bleed sea simétrico.

- [x] **Step 4: Ejecutar la prueba para confirmar el paso a verde**

Run:

```bash
fvm flutter test test/features/public_booking/flash_mosaic_test.dart
```

Expected: PASS con una fila de cinco hijos, tres `Expanded` y dos `SizedBox`.

- [x] **Step 5: Formatear y ejecutar la regresión Flutter**

Run from `app`:

```bash
fvm dart format lib/features/public_booking/presentation/widgets/flash_mosaic.dart test/features/public_booking/flash_mosaic_test.dart
fvm flutter analyze
fvm flutter test
```

Expected: formato sin cambios pendientes, análisis sin issues y prueba específica del mosaico aprobada. La suite completa queda condicionada a las pruebas preexistentes no relacionadas con este slice.

- [x] **Step 6: Verificar el build web con el API del túnel**

Run:

```bash
fvm flutter build web \
  --dart-define=API_BASE_URL=https://9hqbzkgw-3000.use.devtunnels.ms/v1
```

Expected: `✓ Built build/web`; el servidor PHP existente en `8080` continúa sirviendo el nuevo bundle sin reiniciarse.

- [x] **Step 7: Commit del slice**

Comprobar que solo se incluyan los archivos del mosaico y la prueba:

```bash
git diff --check
git add app/lib/features/public_booking/presentation/widgets/flash_mosaic.dart app/test/features/public_booking/flash_mosaic_test.dart context/plans/2026-10-16-inkslot-three-column-mosaic-plan.md context/tasks/backlog.md
git commit -m "feat(app): fit three flash mosaic columns"
```

Actualizar `context/tasks/backlog.md` con la evidencia del test, análisis y build antes del commit.

## Resultado de ejecución — 2026-10-16

- La prueba específica del mosaico pasó con tres `Expanded` y dos separadores.
- `fvm flutter analyze`: sin issues.
- `fvm flutter test`: 196 pruebas ejecutadas; una falla aislada y reproducible en `admin_appointment_detail_test.dart`, fuera del mosaico y de sus dependencias.
- `fvm flutter build web --dart-define=API_BASE_URL=https://9hqbzkgw-3000.use.devtunnels.ms/v1`: build aprobado.
