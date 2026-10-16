# Plan de implementación: dashboard administrativo e incidencias

> **Para agentes de implementación:** ejecutar una tarea a la vez, mantener las casillas actualizadas y cerrar cada tarea con un commit Conventional Commit enfocado.

**Estado de ejecución:** completado el 2026-10-16. Las siete tareas fueron implementadas, verificadas y registradas en commits enfocados.

**Objetivo:** entregar T-017 como un slice vertical con dashboard administrativo real, incidencias operables y filtros persistentes de Solicitudes/Citas en Flutter Web.

**Arquitectura:** NestJS expondrá `GET /v1/admin/dashboard` como una proyección read-only scoped por `artistId`; las incidencias conservarán sus endpoints existentes. Flutter añadirá modelos, repositorios y `ChangeNotifier` por feature, integrados en el `AdminShell` responsive. Los filtros vivirán en los controllers para sobrevivir al cambio de rutas durante la sesión.

**Stack:** Flutter Web 3.47.5 mediante FVM, Provider, GoRouter, `package:http`; NestJS 11, TypeScript, Prisma 6.19, PostgreSQL local, Jest y Supertest.

## Restricciones globales

- Mantener solo `app`, `api` y `context` como carpetas principales del workspace.
- Usar PostgreSQL local; no añadir Docker, Compose, Redis, migraciones ni colas externas.
- Mantener `AdminSessionGuard` y el alcance por `artistId` en todos los endpoints administrativos.
- El dashboard contará solicitudes `PENDING`, citas `CONFIRMED` futuras e incidencias `OPEN`.
- `nextAppointments` devolverá como máximo cinco citas confirmadas futuras, ordenadas por `startAt ASC, id ASC`.
- No devolver tokens, hashes, credenciales, contacto, pago, `calendarId`, `externalEventId` ni mensajes crudos del proveedor.
- Mantener los contratos existentes de solicitudes, citas e incidencias; T-017 no modifica Prisma.
- Los errores conservarán `{ error: { code, message } }`; `401` debe limpiar sesión y redirigir a login.
- Reutilizar Provider, `InkSlotTokens`, tipografías y componentes existentes; no crear assets ni datos simulados.
- Respetar `MediaQuery.disableAnimations` y objetivos táctiles mínimos de 44 px.
- Ejecutar pruebas enfocadas y `git diff --check` antes de cada commit.
- No hacer push remoto durante la implementación.

## Mapa de archivos

Backend:

- Crear `api/src/dashboard/admin-dashboard.controller.ts` para `GET /admin/dashboard`.
- Crear `api/src/dashboard/admin-dashboard.service.ts` para la proyección Prisma.
- Crear `api/src/dashboard/dashboard.module.ts` y registrarlo en `api/src/app.module.ts`.
- Crear `api/src/dashboard/admin-dashboard.service.spec.ts`.
- Crear o modificar `api/test/admin-dashboard.e2e-spec.ts` para dashboard, aislamiento e incidencias.

Flutter:

- Crear `app/lib/features/dashboard/domain/admin_dashboard.dart`.
- Crear `app/lib/features/dashboard/data/admin_dashboard_repository.dart`.
- Crear `app/lib/features/dashboard/presentation/admin_dashboard_controller.dart`.
- Crear `app/lib/features/dashboard/presentation/admin_dashboard_page.dart` y widgets locales si el tamaño lo requiere.
- Crear `app/lib/features/appointments/domain/admin_appointment.dart`.
- Crear `app/lib/features/appointments/data/admin_appointments_repository.dart`.
- Crear `app/lib/features/appointments/presentation/admin_appointments_controller.dart`.
- Crear `app/lib/features/appointments/presentation/admin_appointments_page.dart`.
- Crear `app/lib/features/sync_issues/domain/sync_issue.dart`.
- Crear `app/lib/features/sync_issues/data/sync_issues_repository.dart`.
- Crear `app/lib/features/sync_issues/presentation/sync_issues_controller.dart`.
- Crear `app/lib/features/sync_issues/presentation/sync_issues_page.dart`.
- Modificar `app/lib/core/router/app_router.dart` para controllers y rutas `/admin`, `/admin/appointments` y `/admin/sync-issues`.
- Modificar `app/lib/features/admin/presentation/admin_shell.dart` para cuatro destinos de navegación.
- Modificar `app/lib/features/requests/presentation/booking_requests_controller.dart` y `booking_requests_page.dart` para conservar el filtro.
- Crear pruebas bajo `app/test/features/dashboard`, `app/test/features/appointments` y `app/test/features/sync_issues`; ampliar las pruebas de requests/router.

---

### Tarea 1: endpoint de dashboard administrativo

**Agente:** backend NestJS/Prisma  
**Dependencias:** especificación T-017 aprobada  
**Commit:** `feat(api): add admin dashboard projection`

**Archivos:**

- Crear: `api/src/dashboard/admin-dashboard.controller.ts`
- Crear: `api/src/dashboard/admin-dashboard.service.ts`
- Crear: `api/src/dashboard/dashboard.module.ts`
- Modificar: `api/src/app.module.ts`
- Test: `api/src/dashboard/admin-dashboard.service.spec.ts`

**Interfaces:**

```ts
export type AdminDashboardResponse = {
  pendingRequests: number;
  upcomingAppointments: number;
  syncIssues: number;
  nextAppointments: Array<{
    id: string;
    client: { name: string };
    startAt: string;
    endAt: string;
    durationMinutes: number;
    status: 'confirmed';
    syncStatus: 'pending' | 'synced' | 'failed';
  }>;
};

class AdminDashboardService {
  get(artistId: string): Promise<AdminDashboardResponse>;
}
```

- [ ] **Paso 1: escribir pruebas unitarias de la proyección**

Cubrir que el service usa una única fecha `now`, cuenta solo el artista solicitado, excluye solicitudes no pendientes, excluye citas pasadas/no confirmadas, cuenta solo incidencias abiertas de citas propias, ordena por `startAt` e `id`, limita a cinco y devuelve lista vacía sin datos.

Ejemplo mínimo del caso de aislamiento:

```ts
it('projects only the authenticated artist and hides sensitive fields', async () => {
  prisma.bookingRequest.count.mockResolvedValue(2);
  prisma.appointment.count.mockResolvedValue(1);
  prisma.syncIssue.count.mockResolvedValue(1);
  prisma.appointment.findMany.mockResolvedValue([
    {
      id: 'appointment-a',
      startAt: new Date('2026-10-20T15:00:00.000Z'),
      endAt: new Date('2026-10-20T18:00:00.000Z'),
      status: AppointmentStatus.CONFIRMED,
      syncStatus: SyncStatus.SYNCED,
      request: {
        durationMinutes: 180,
        client: { name: 'Cliente A' },
      },
    },
  ] as never);

  await expect(service.get('artist-a')).resolves.toEqual({
    pendingRequests: 2,
    upcomingAppointments: 1,
    syncIssues: 1,
    nextAppointments: [
      expect.objectContaining({
        id: 'appointment-a',
        client: { name: 'Cliente A' },
        status: 'confirmed',
      }),
    ],
  });
  expect(prisma.bookingRequest.count).toHaveBeenCalledWith({
    where: { artistId: 'artist-a', status: BookingRequestStatus.PENDING },
  });
});
```

- [ ] **Paso 2: ejecutar las pruebas enfocadas y verificar que fallen por código ausente**

Ejecutar desde `api`:

```bash
npm test -- --runInBand --watchman=false src/dashboard/admin-dashboard.service.spec.ts
```

Esperado: fallo inicial porque todavía no existen el módulo y el service.

- [ ] **Paso 3: implementar service y controller mínimos**

Usar `const now = new Date()` y cuatro consultas Prisma con `Promise.all`. El `findMany` debe usar `take: 5`, `orderBy: [{ startAt: 'asc' }, { id: 'asc' }]` y `select` únicamente con `id`, `startAt`, `endAt`, `status`, `syncStatus`, `request.durationMinutes` y `request.client.name`. El controller debe ser:

```ts
@Controller('admin/dashboard')
@UseGuards(AdminSessionGuard)
export class AdminDashboardController {
  constructor(private readonly dashboard: AdminDashboardService) {}

  @Get()
  get(@Req() request: AuthenticatedRequest) {
    return this.dashboard.get(request.user.id);
  }
}
```

El service debe mapear enums Prisma a minúsculas y convertir fechas a ISO. Registrar `DashboardModule` con `PrismaModule`, `AuthModule`, controller y service; importar el módulo en `AppModule`.

- [ ] **Paso 4: ejecutar unitarias y build**

```bash
npm test -- --runInBand --watchman=false src/dashboard/admin-dashboard.service.spec.ts
npm run build
```

Esperado: pruebas enfocadas y build exitosos.

- [ ] **Paso 5: revisar diff y commit**

```bash
git diff --check
git add api/src/dashboard api/src/app.module.ts
git commit -m "feat(api): add admin dashboard projection"
```

---

### Tarea 2: E2E de dashboard e incidencias

**Agente:** backend E2E  
**Dependencias:** Tarea 1  
**Commit:** `test(api): cover admin dashboard and sync issues`

**Archivos:**

- Crear: `api/test/admin-dashboard.e2e-spec.ts`
- Usar sin modificar: `api/test/jest-e2e.json` y los fixtures locales de `api/test/admin-appointments.e2e-spec.ts`.

**Interfaces:** consumir `GET /v1/admin/dashboard`, `GET /v1/admin/sync-issues`, `POST /v1/admin/sync-issues/:id/retry`.

- [ ] **Paso 1: crear fixtures reales en PostgreSQL local**

Reutilizar el patrón de `api/test/calendar-outbox.e2e-spec.ts` y `api/test/admin-appointments.e2e-spec.ts`: dos artistas, sesiones autenticadas, solicitudes pendientes, citas futuras/pasadas y una incidencia abierta. El `beforeEach` debe limpiar únicamente las filas creadas por el fixture y no modificar credenciales del `.env`.

- [ ] **Paso 2: escribir pruebas E2E**

Cubrir:

```ts
it('returns only the authenticated artist dashboard', async () => {
  await request(app.getHttpServer())
    .get('/v1/admin/dashboard')
    .set('Cookie', owner.cookie)
    .expect(200)
    .expect(({ body }) => {
      expect(body.pendingRequests).toBe(1);
      expect(body.upcomingAppointments).toBe(1);
      expect(body.syncIssues).toBe(1);
      expect(body.nextAppointments).toHaveLength(1);
      expect(body.nextAppointments[0].client.name).toBe('Cliente propio');
      expect(JSON.stringify(body)).not.toContain('refresh-token');
    });
});
```

Además, verificar dashboard vacío, `401` sin cookie, rechazo de acceso cruzado a incidencias, retry que devuelve `{ status: 'queued' }` y que el dashboard mantiene el issue abierto hasta que el worker lo resuelva.

- [ ] **Paso 3: ejecutar E2E enfocado**

```bash
npm run test:e2e -- --runInBand --watchman=false test/admin-dashboard.e2e-spec.ts
```

Esperado: todas las pruebas del archivo pasan contra PostgreSQL local.

- [ ] **Paso 4: revisar diff y commit**

```bash
git diff --check
git add api/test/admin-dashboard.e2e-spec.ts
git commit -m "test(api): cover admin dashboard and sync issues"
```

---

### Tarea 3: dominio, repositorio y controller Flutter del dashboard

**Agente:** Flutter data/state  
**Dependencias:** contrato de la Tarea 1  
**Commit:** `feat(app): add admin dashboard state`

**Archivos:**

- Crear: `app/lib/features/dashboard/domain/admin_dashboard.dart`
- Crear: `app/lib/features/dashboard/data/admin_dashboard_repository.dart`
- Crear: `app/lib/features/dashboard/presentation/admin_dashboard_controller.dart`
- Test: `app/test/features/dashboard/admin_dashboard_repository_test.dart`
- Test: `app/test/features/dashboard/admin_dashboard_controller_test.dart`

**Interfaces:**

```dart
enum AdminDashboardStatus { idle, loading, loaded, empty, error }

class AdminDashboard {
  const AdminDashboard({
    required this.pendingRequests,
    required this.upcomingAppointments,
    required this.syncIssues,
    required this.nextAppointments,
  });

  final int pendingRequests;
  final int upcomingAppointments;
  final int syncIssues;
  final List<DashboardAppointment> nextAppointments;

  factory AdminDashboard.fromJson(Map<String, dynamic> json);
}

class AdminDashboardRepository {
  Future<AdminDashboard> load();
}

class AdminDashboardController extends ChangeNotifier {
  AdminDashboardStatus get status;
  AdminDashboard? get dashboard;
  String? get errorMessage;
  bool get sessionExpired;
  Future<void> load({bool refresh = false});
}
```

- [ ] **Paso 1: escribir pruebas de parsing y estados**

El parser debe rechazar contadores no enteros, listas inválidas, fechas no ISO y estados desconocidos. El controller debe pasar `idle → loading → loaded`, usar `empty` cuando `nextAppointments` está vacío sin descartar los contadores, conservar el dashboard anterior durante un retry fallido, exponer un mensaje seguro y marcar `sessionExpired` ante `ApiException.isUnauthorized`.

Ejemplo de repository test:

```dart
test('loads and parses the dashboard projection', () async {
  final client = FakeApiClient(<String, dynamic>{
    'pendingRequests': 2,
    'upcomingAppointments': 1,
    'syncIssues': 0,
    'nextAppointments': <Map<String, dynamic>>[],
  });
  final dashboard = await AdminDashboardRepository(client).load();
  expect(dashboard.pendingRequests, 2);
  expect(dashboard.nextAppointments, isEmpty);
  expect(client.lastGetPath, '/admin/dashboard');
});
```

- [ ] **Paso 2: ejecutar pruebas enfocadas para confirmar el rojo inicial**

```bash
fvm flutter test test/features/dashboard/admin_dashboard_repository_test.dart test/features/dashboard/admin_dashboard_controller_test.dart
```

Esperado: fallo inicial por clases ausentes.

- [ ] **Paso 3: implementar modelos, repository y controller**

El repository llamará `ApiClient.getJson('/admin/dashboard')`. El controller usará `notifyListeners()`, no persistirá respuestas y recibirá opcionalmente `AdminSessionController` para ejecutar logout ante `401`, siguiendo el patrón de `BookingRequestsController`.

- [ ] **Paso 4: ejecutar format, tests y analyze**

```bash
fvm dart format lib test
fvm flutter test test/features/dashboard
fvm flutter analyze
```

Esperado: tests y analyze sin issues.

- [ ] **Paso 5: revisar diff y commit**

```bash
git diff --check
git add app/lib/features/dashboard app/test/features/dashboard
git commit -m "feat(app): add admin dashboard state"
```

---

### Tarea 4: pantalla Inicio y navegación administrativa

**Agente:** Flutter UI/router  
**Dependencias:** Tarea 3  
**Commit:** `feat(app): add admin dashboard navigation`

**Archivos:**

- Crear: `app/lib/features/dashboard/presentation/admin_dashboard_page.dart`
- Modificar: `app/lib/core/router/app_router.dart`
- Modificar: `app/lib/features/admin/presentation/admin_shell.dart`
- Test: `app/test/features/dashboard/admin_dashboard_page_test.dart`
- Test: `app/test/features/admin/admin_router_test.dart`

**Interfaces:** `AdminDashboardPage({required AdminDashboardController controller})`; el router debe aceptar `AdminDashboardController? dashboardController` para tests e inyección.

- [ ] **Paso 1: escribir widget/router tests**

Cubrir KPI con valores reales, lista vacía con estado empty, botón retry en error, navegación de KPI a `/admin/requests`, `/admin/appointments` y `/admin/sync-issues`, protección de `/admin` cuando la sesión está cerrada y selección visual de Inicio en desktop/móvil.

- [ ] **Paso 2: ejecutar pruebas para confirmar el rojo inicial**

```bash
fvm flutter test test/features/dashboard/admin_dashboard_page_test.dart test/features/admin/admin_router_test.dart
```

Esperado: fallo inicial por página y rutas nuevas ausentes.

- [ ] **Paso 3: implementar la página y el shell**

La página debe usar `AnimatedBuilder` o `ListenableBuilder`, `ConstrainedBox(maxWidth: 980)`, `InkSlotMonoLabel`, `InkSlotPrimaryButton`, colores `InkSlotColors` y componentes de tarjeta con mínimo 44 px. La ruta `/admin` quedará dentro del `ShellRoute`; se eliminará el redirect que la enviaba a `/admin/requests`. El shell recibirá un destino seleccionado basado en `GoRouterState.uri.path` y añadirá `Inicio`, `Solicitudes`, `Citas` e `Incidencias` tanto en rail como en navegación móvil.

- [ ] **Paso 4: ejecutar pruebas y verificación visual básica**

```bash
fvm dart format lib test
fvm flutter test test/features/dashboard test/features/admin/admin_router_test.dart
fvm flutter analyze
```

Esperado: tests y analyze exitosos; no deben aparecer overflow ni cambios en rutas públicas `/r/:token`.

- [ ] **Paso 5: revisar diff y commit**

```bash
git diff --check
git add app/lib/core/router/app_router.dart app/lib/features/admin app/lib/features/dashboard/presentation/admin_dashboard_page.dart app/test/features/dashboard app/test/features/admin/admin_router_test.dart
git commit -m "feat(app): add admin dashboard navigation"
```

---

### Tarea 5: lista de Citas con filtros persistentes

**Agente:** Flutter appointments  
**Dependencias:** Tarea 4  
**Commit:** `feat(app): add admin appointments filters`

**Archivos:**

- Crear: `app/lib/features/appointments/domain/admin_appointment.dart`
- Crear: `app/lib/features/appointments/data/admin_appointments_repository.dart`
- Crear: `app/lib/features/appointments/presentation/admin_appointments_controller.dart`
- Crear: `app/lib/features/appointments/presentation/admin_appointments_page.dart`
- Modificar: `app/lib/core/router/app_router.dart`
- Test: `app/test/features/appointments/admin_appointments_repository_test.dart`
- Test: `app/test/features/appointments/admin_appointments_controller_test.dart`
- Test: `app/test/features/appointments/admin_appointments_page_test.dart`

**Interfaces:**

```dart
enum AdminAppointmentFilter { confirmed, completed, cancelled, noShow }

class AdminAppointmentsController extends ChangeNotifier {
  AdminAppointmentFilter get filter;
  AdminAppointmentsStatus get status;
  List<AdminAppointment> get items;
  Future<void> load({bool refresh = false});
  Future<void> setFilter(AdminAppointmentFilter filter);
  Future<void> loadMore();
}
```

- [ ] **Paso 1: escribir parsing, controller y widget tests**

Verificar que el repository genera `/admin/appointments?status=confirmed`, decodifica `nextCursor`, rechaza estados desconocidos, conserva el filtro tras `setFilter`, evita doble carga, muestra empty/error/loading y abre el detalle solo cuando exista una ruta explícita. Como el detalle/acciones Flutter están fuera de T-017, la tarjeta no debe inventar botones de mutación.

- [ ] **Paso 2: ejecutar tests para confirmar el rojo inicial**

```bash
fvm flutter test test/features/appointments
```

Esperado: fallo inicial por feature ausente.

- [ ] **Paso 3: implementar modelo, repository, controller y página**

Usar `GET /admin/appointments`, `status` y `cursor`. La página tendrá cuatro chips de filtro, tarjetas con nombre, horario, duración, status y syncStatus, botón de cargar más, empty/error/retry. El controller debe aceptar `AdminSessionController` opcional y cerrar sesión ante `401`.

- [ ] **Paso 4: conectar la ruta e inicializar controller una sola vez**

Añadir `AdminAppointmentsController? appointmentsController` a `AppRouter.create`, crear la instancia por defecto una vez junto a `BookingRequestsController` y entregarla mediante `ChangeNotifierProvider.value` a `/admin/appointments`. Al volver desde otra ruta, el controller debe conservar `filter` e items.

- [ ] **Paso 5: ejecutar format, tests y analyze**

```bash
fvm dart format lib test
fvm flutter test test/features/appointments test/features/admin/admin_router_test.dart
fvm flutter analyze
```

- [ ] **Paso 6: revisar diff y commit**

```bash
git diff --check
git add app/lib/features/appointments app/lib/core/router/app_router.dart app/test/features/appointments app/test/features/admin/admin_router_test.dart
git commit -m "feat(app): add admin appointments filters"
```

---

### Tarea 6: incidencias, retry y persistencia del filtro de Solicitudes

**Agente:** Flutter sync issues/requests  
**Dependencias:** Tarea 4  
**Commit:** `feat(app): add sync issues and persistent request filters`

**Archivos:**

- Crear: `app/lib/features/sync_issues/domain/sync_issue.dart`
- Crear: `app/lib/features/sync_issues/data/sync_issues_repository.dart`
- Crear: `app/lib/features/sync_issues/presentation/sync_issues_controller.dart`
- Crear: `app/lib/features/sync_issues/presentation/sync_issues_page.dart`
- Modificar: `app/lib/features/requests/presentation/booking_requests_controller.dart`
- Modificar: `app/lib/features/requests/presentation/booking_requests_page.dart`
- Modificar: `app/lib/core/router/app_router.dart`
- Test: `app/test/features/sync_issues/sync_issues_repository_test.dart`
- Test: `app/test/features/sync_issues/sync_issues_controller_test.dart`
- Test: `app/test/features/sync_issues/sync_issues_page_test.dart`
- Modificar: `app/test/features/requests/booking_requests_controller_test.dart`
- Modificar: `app/test/features/requests/booking_requests_page_test.dart`

**Interfaces:**

```dart
enum SyncIssueFilter { open, resolved }

class SyncIssuesController extends ChangeNotifier {
  SyncIssueFilter get filter;
  SyncIssuesStatus get status;
  List<SyncIssue> get items;
  Future<void> load({bool refresh = false});
  Future<void> setFilter(SyncIssueFilter filter);
  Future<void> retry(String id);
}
```

- [ ] **Paso 1: escribir tests de repository, retry y filtros persistentes**

Cubrir query `status=open|resolved`, parseo de `lastAttemptAt: null`, retry `POST /admin/sync-issues/:id/retry`, estado submitting por una sola incidencia y recarga posterior. En requests, cubrir que se selecciona `pending`, se navega a otra ruta y al reconstruir la página el controller conserva ese filtro.

- [ ] **Paso 2: ejecutar tests para confirmar el rojo inicial**

```bash
fvm flutter test test/features/sync_issues test/features/requests/booking_requests_controller_test.dart test/features/requests/booking_requests_page_test.dart
```

- [ ] **Paso 3: implementar incidencia y retry**

El repository usará `GET /admin/sync-issues` y `POST /admin/sync-issues/{id}/retry`. El controller expondrá `retryingId`, bloqueará el botón de la incidencia en curso y, tras éxito, ejecutará `load(refresh: true)`. La página ofrecerá chips `Abiertas`/`Resueltas`, tarjetas con código, mensaje seguro, operación, estado y fecha, y estados loading/empty/error/retry.

- [ ] **Paso 4: mover el filtro de Solicitudes al controller**

Crear un enum público `BookingRequestsFilter` en el controller o dominio, una propiedad `filter`, y métodos `setFilter`/`loadForFilter`. `BookingRequestsPage` debe inicializar su selección desde el controller y dejar de depender únicamente del `_filter` local de `State`; la regla visual `Canceladas` seguirá agrupando `cancelled` y `closed` sin cambiar el contrato API.

- [ ] **Paso 5: conectar la ruta y verificar navegación**

Añadir `SyncIssuesController? syncIssuesController` a `AppRouter.create`, instanciarlo una sola vez y usar `ChangeNotifierProvider.value` en `/admin/sync-issues`. Verificar que el filtro de Solicitudes y el de Incidencias sobreviven al ir a Inicio y regresar.

- [ ] **Paso 6: ejecutar format, tests y analyze**

```bash
fvm dart format lib test
fvm flutter test test/features/sync_issues test/features/requests
fvm flutter analyze
```

- [ ] **Paso 7: revisar diff y commit**

```bash
git diff --check
git add app/lib/features/sync_issues app/lib/features/requests app/lib/core/router/app_router.dart app/test/features/sync_issues app/test/features/requests
git commit -m "feat(app): add sync issues and persistent request filters"
```

---

### Tarea 7: integración final, regresión y documentación SDD

**Agente:** integración/revisión  
**Dependencias:** Tareas 1–6  
**Commit:** `docs(context): record admin dashboard slice`

**Archivos:**

- Modificar: `context/tasks/backlog.md`
- Modificar: `context/plans/2026-10-16-inkslot-admin-dashboard-plan.md`
- Modificar: `context/manifest.json` para registrar `design/2026-10-16-inkslot-admin-dashboard-design.md` y `plans/2026-10-16-inkslot-admin-dashboard-plan.md`.

- [ ] **Paso 1: ejecutar toda la verificación API**

Desde `api`, con PostgreSQL local activo:

```bash
npm test -- --runInBand --watchman=false
npm run test:e2e -- --runInBand --watchman=false
npm run build
```

Esperado: suites unitarias y E2E verdes, build NestJS exitoso y sin regresiones en Calendar, solicitudes, disponibilidad o confirmación.

- [ ] **Paso 2: ejecutar toda la verificación Flutter**

Desde `app`:

```bash
fvm dart format lib test
fvm flutter analyze
fvm flutter test
fvm flutter build web --dart-define=API_BASE_URL=http://localhost:3000/v1
```

Esperado: formato sin cambios pendientes, analyze sin issues, tests verdes y build Web exitoso.

- [ ] **Paso 3: revisar seguridad, diseño y estructura**

Ejecutar:

```bash
git diff --check
rg -n "refresh.?token|tokenHash|externalEventId|calendarId|paymentReference" app/lib/features/dashboard app/lib/features/appointments app/lib/features/sync_issues api/src/dashboard
find . -maxdepth 1 -type d -print | sort
```

Esperado: ninguna credencial/token sensible en nuevas respuestas Flutter o dashboard, solo las tres carpetas principales `app`, `api`, `context`, y ningún prototipo/PDF modificado.

- [ ] **Paso 4: actualizar backlog, plan y manifest**

Agregar al backlog una entrada T-017 con el alcance implementado y la evidencia numérica real de la ejecución. Marcar el encabezado del plan como completado, sin modificar los requisitos históricos. Añadir las dos rutas relativas del diseño y del plan al arreglo `documents` de `context/manifest.json`.

- [ ] **Paso 5: revisar diff y commit documental**

```bash
git diff --check
git add context/tasks/backlog.md context/plans/2026-10-16-inkslot-admin-dashboard-plan.md context/manifest.json
git commit -m "docs(context): record admin dashboard slice"
```

## Orden y paralelización

1. Ejecutar Tarea 1.
2. Ejecutar Tarea 2 y Tarea 3 en paralelo cuando el contrato de Tarea 1 esté estable.
3. Ejecutar Tarea 4 después de Tarea 3.
4. Ejecutar Tareas 5 y 6 en paralelo después de Tarea 4; ambas modifican `app_router.dart`, por lo que el integrador debe resolver cualquier conflicto manteniendo una única instancia de cada controller.
5. Ejecutar Tarea 7 cuando todos los commits anteriores estén integrados.

## Revisión del plan

- **Cobertura:** el endpoint, conteos, orden, aislamiento, Inicio, incidencias, retry, Citas y filtros persistentes tienen tareas y pruebas explícitas.
- **Placeholders:** no se dejan `TBD`, `TODO` ni pasos abiertos; el límite de `nextAppointments` está fijado en cinco.
- **Tipos:** las firmas TypeScript y Dart usadas por tareas posteriores están definidas en las tareas que producen sus interfaces.
- **Alcance:** no se incluye Agenda, configuración, acciones de detalle Flutter, migraciones, Docker, prototipo/PDF ni T-019.
