# Production Admin Bootstrap Implementation Plan

> **For agentic workers:** Execute each task as a focused vertical slice with tests and a small commit. Do not run the local demo seed against the production database.

**Goal:** Provision the single production administrator for Dodogio through an explicit CLI command, while keeping the production database free of demo clients, requests, tokens, appointments and schedules.

**Architecture:** The bootstrap is a standalone Prisma CLI under `api/prisma/`. It reads a strictly validated, one-time environment contract, hashes the supplied password with Argon2id, and performs an idempotent `Artist.upsert`. Runtime login resolution reads only the non-secret `ADMIN_LOGIN_USERNAME`/`ADMIN_EMAIL` mapping; the local demo seed remains an independent development fixture.

**Tech Stack:** NestJS 11, TypeScript, Prisma 6.19, PostgreSQL/Neon, Argon2id, Jest and `ts-node`.

## Global Constraints

- The workspace keeps only `app/`, `api/` and `context/` as top-level project folders.
- PostgreSQL remains external/local by environment; no Docker or Compose is added.
- The production bootstrap never calls `npm run db:seed` and never creates demo rows.
- The password, `DATABASE_URL`, OAuth secrets and confirmation value never enter tracked files, logs, API responses or Flutter assets.
- `ADMIN_LOGIN_USERNAME`, `ADMIN_EMAIL` and `ADMIN_DISPLAY_NAME` are non-secret runtime configuration and remain configured in Render after provisioning so `dodo` continues to resolve correctly.
- `ADMIN_PASSWORD` and `ADMIN_BOOTSTRAP_CONFIRM` exist only for the one-time command execution and are removed immediately afterward.
- The existing Artist model is reused; no schema migration is needed because the login username is an environment-to-email mapping, not persisted PII.
- The seed remains available only for local development/QA and continues to use its `DEMO_*` variables.
- Every task ends with a focused test/check and an isolated commit.

---

### Task 1: Separate production login mapping from local demo configuration

**Files:**
- Modify: `api/src/auth/auth.constants.ts`
- Modify: `api/src/auth/auth.constants.spec.ts`
- Modify: `api/.env.example`
- Modify: `api/README.md`
- Test: `api/src/auth/auth.constants.spec.ts`

**Interfaces:**
- Consumes: `NodeJS.ProcessEnv` and the existing `resolveLoginEmail(login, env)` function.
- Produces: `resolveLoginEmail` mapping `ADMIN_LOGIN_USERNAME` to `ADMIN_EMAIL`, with no dependency on `DEMO_*` variables.

- [ ] **Step 1: Write the failing resolver tests**

Replace the demo-specific fixture in `api/src/auth/auth.constants.spec.ts` with production configuration and add the explicit demo-isolation case:

```ts
import { resolveLoginEmail } from './auth.constants';

describe('resolveLoginEmail', () => {
  const productionEnv = {
    ADMIN_LOGIN_USERNAME: 'dodo',
    ADMIN_EMAIL: 'piero@example.test',
    DEMO_LOGIN_USERNAME: 'dodo',
    DEMO_ARTIST_EMAIL: 'demo@inkslot.local',
  };

  it('resolves the configured production username', () => {
    expect(resolveLoginEmail(' DODO ', productionEnv)).toBe(
      'piero@example.test',
    );
  });

  it('normalizes direct email logins', () => {
    expect(resolveLoginEmail(' Artist@Example.com ', productionEnv)).toBe(
      'artist@example.com',
    );
  });

  it('does not use DEMO_* values for runtime login resolution', () => {
    expect(
      resolveLoginEmail('dodo', {
        DEMO_LOGIN_USERNAME: 'dodo',
        DEMO_ARTIST_EMAIL: 'demo@inkslot.local',
      }),
    ).toBe('dodo');
  });
});
```

- [ ] **Step 2: Run the focused test and verify it fails**

Run from `api/`:

```bash
npm test -- --runInBand src/auth/auth.constants.spec.ts
```

Expected: the production username test fails because the current resolver reads `DEMO_*` only.

- [ ] **Step 3: Implement the production resolver**

Change only the configuration lookup in `api/src/auth/auth.constants.ts`:

```ts
export const resolveLoginEmail = (
  login: string,
  env: NodeJS.ProcessEnv = process.env,
): string => {
  const normalizedLogin = login.trim().toLowerCase();
  const configuredUsername = env.ADMIN_LOGIN_USERNAME?.trim().toLowerCase();
  const configuredEmail = env.ADMIN_EMAIL?.trim().toLowerCase();

  if (
    configuredUsername &&
    configuredEmail &&
    normalizedLogin === configuredUsername
  ) {
    return configuredEmail;
  }

  return normalizedLogin;
};
```

- [ ] **Step 4: Document the two environment profiles**

In `api/.env.example`, retain the `DEMO_*` variables for `npm run db:seed` and add:

```env
# Runtime login mapping. Keep the username/email mapping in the deployed API.
ADMIN_LOGIN_USERNAME=dodo
ADMIN_EMAIL=
ADMIN_DISPLAY_NAME=Dodogio
```

In `api/README.md`, state that local demo seeding and production bootstrap are different commands, and that `ADMIN_PASSWORD` is supplied out-of-band only for the one-time bootstrap. Do not write any real password into the README or `.env.example`.

- [ ] **Step 5: Run the focused test and verify it passes**

```bash
npm test -- --runInBand src/auth/auth.constants.spec.ts
```

Expected: 3 tests pass.

- [ ] **Step 6: Commit the runtime mapping change**

```bash
git add api/src/auth/auth.constants.ts api/src/auth/auth.constants.spec.ts api/.env.example api/README.md
git commit -m "refactor(auth): separate production login mapping from demo seed"
```

---

### Task 2: Add strict production-admin configuration validation

**Files:**
- Create: `api/src/auth/production-admin.config.ts`
- Create: `api/src/auth/production-admin.config.spec.ts`

**Interfaces:**
- Consumes: `NodeJS.ProcessEnv`.
- Produces: `ProductionAdminBootstrapConfig` and `readProductionAdminConfig(env)`.

Use this exact contract:

```ts
export type ProductionAdminBootstrapConfig = {
  loginUsername: string;
  email: string;
  password: string;
  displayName: string;
};

export const PRODUCTION_ADMIN_CONFIRMATION =
  'CREATE_PRODUCTION_ADMIN' as const;

export function readProductionAdminConfig(
  env: NodeJS.ProcessEnv = process.env,
): ProductionAdminBootstrapConfig;
```

- [ ] **Step 1: Write failing validation tests**

The test file must cover the actual boundary values:

```ts
import {
  PRODUCTION_ADMIN_CONFIRMATION,
  readProductionAdminConfig,
} from './production-admin.config';

const validEnv = (): NodeJS.ProcessEnv => ({
  ADMIN_LOGIN_USERNAME: 'dodo',
  ADMIN_EMAIL: 'piero@example.test',
  ADMIN_PASSWORD: 'secret-from-shell',
  ADMIN_DISPLAY_NAME: 'Dodogio',
  ADMIN_BOOTSTRAP_CONFIRM: PRODUCTION_ADMIN_CONFIRMATION,
});

describe('readProductionAdminConfig', () => {
  it('normalizes the configured username and email', () => {
    const config = readProductionAdminConfig({
      ...validEnv(),
      ADMIN_LOGIN_USERNAME: ' DODO ',
      ADMIN_EMAIL: ' Piero@Example.Test ',
    });

    expect(config).toEqual({
      loginUsername: 'dodo',
      email: 'piero@example.test',
      password: 'secret-from-shell',
      displayName: 'Dodogio',
    });
  });

  it.each([
    'ADMIN_LOGIN_USERNAME',
    'ADMIN_EMAIL',
    'ADMIN_PASSWORD',
    'ADMIN_DISPLAY_NAME',
    'ADMIN_BOOTSTRAP_CONFIRM',
  ])('rejects a missing %s', (key) => {
    const env = validEnv();
    delete env[key];
    expect(() => readProductionAdminConfig(env)).toThrow(/required/i);
  });

  it('rejects an invalid email', () => {
    expect(() =>
      readProductionAdminConfig({ ...validEnv(), ADMIN_EMAIL: 'not-an-email' }),
    ).toThrow(/email/i);
  });

  it('rejects an incorrect production confirmation', () => {
    expect(() =>
      readProductionAdminConfig({
        ...validEnv(),
        ADMIN_BOOTSTRAP_CONFIRM: 'YES',
      }),
    ).toThrow(/confirmation/i);
  });

  it('does not read DEMO_PASSWORD as a fallback', () => {
    const env = validEnv();
    delete env.ADMIN_PASSWORD;
    env.DEMO_PASSWORD = 'demo-secret';
    expect(() => readProductionAdminConfig(env)).toThrow(/password|required/i);
  });
});
```

- [ ] **Step 2: Run the focused test and verify it fails**

```bash
npm test -- --runInBand src/auth/production-admin.config.spec.ts
```

Expected: Jest fails because the module and function do not exist.

- [ ] **Step 3: Implement the validator without logging secrets**

`readProductionAdminConfig` must trim username/email/display name, lowercase username/email, require all five environment keys, validate the username with `^[a-z0-9._-]{2,64}$`, validate the email with a non-whitespace local/domain shape, require a non-empty password, and compare the confirmation with `PRODUCTION_ADMIN_CONFIRMATION`. Error messages may name the missing variable or field but must never include the password or `DATABASE_URL`.

The implementation must return only the `ProductionAdminBootstrapConfig` fields shown above; it must not return the confirmation value or any `DEMO_*` value.

- [ ] **Step 4: Run the focused test and verify it passes**

```bash
npm test -- --runInBand src/auth/production-admin.config.spec.ts
```

Expected: all validation tests pass.

- [ ] **Step 5: Commit the configuration boundary**

```bash
git add api/src/auth/production-admin.config.ts api/src/auth/production-admin.config.spec.ts
git commit -m "feat(auth): validate production admin bootstrap config"
```

---

### Task 3: Implement the idempotent Artist bootstrap operation

**Files:**
- Create: `api/src/auth/production-admin.bootstrap.ts`
- Create: `api/src/auth/production-admin.bootstrap.spec.ts`

**Interfaces:**
- Consumes: `ProductionAdminBootstrapConfig` from Task 2 and the Prisma `artist` delegate.
- Produces: `bootstrapProductionAdmin(prisma, config)` returning `{ artistId, displayName }`.

Use this public result type:

```ts
export type ProductionAdminBootstrapResult = {
  artistId: string;
  displayName: string;
};

export async function bootstrapProductionAdmin(
  prisma: Pick<PrismaClient, 'artist'>,
  config: ProductionAdminBootstrapConfig,
): Promise<ProductionAdminBootstrapResult>;
```

- [ ] **Step 1: Write the failing bootstrap tests**

The unit test must mock only the `artist.upsert` delegate and verify the complete Prisma payload:

```ts
import * as argon2 from 'argon2';
import type { PrismaClient } from '@prisma/client';

import { bootstrapProductionAdmin } from './production-admin.bootstrap';
import type { ProductionAdminBootstrapConfig } from './production-admin.config';

describe('bootstrapProductionAdmin', () => {
  const config: ProductionAdminBootstrapConfig = {
    loginUsername: 'dodo',
    email: 'piero@example.test',
    password: 'secret-from-shell',
    displayName: 'Dodogio',
  };
  const upsert = jest.fn().mockResolvedValue({
    id: 'artist-id',
    displayName: 'Dodogio',
  });
  const prisma = { artist: { upsert } } as unknown as Pick<PrismaClient, 'artist'>;

  beforeEach(() => jest.clearAllMocks());

  it('hashes with Argon2id and upserts only the Artist row', async () => {
    const result = await bootstrapProductionAdmin(prisma, config);
    const call = upsert.mock.calls[0][0];
    const passwordMatches = await argon2.verify(
      call.create.passwordHash,
      config.password,
    );

    expect(passwordMatches).toBe(true);
    expect(call.create).toMatchObject({
      email: config.email,
      displayName: config.displayName,
      active: true,
    });
    expect(call.update).toMatchObject({
      displayName: config.displayName,
      active: true,
    });
    expect(call.where).toEqual({ email: config.email });
    expect(result).toEqual({ artistId: 'artist-id', displayName: 'Dodogio' });
  });
});
```

- [ ] **Step 2: Run the focused test and verify it fails**

```bash
npm test -- --runInBand src/auth/production-admin.bootstrap.spec.ts
```

Expected: Jest fails because the bootstrap module does not exist.

- [ ] **Step 3: Implement the minimal Argon2id upsert**

The implementation must:

1. Hash `config.password` with `{ type: argon2.argon2id }`.
2. Call exactly one `prisma.artist.upsert` with `where: { email: config.email }`.
3. Create `{ email, passwordHash, displayName, active: true }`.
4. Update `{ passwordHash, displayName, active: true }`.
5. Return only the generated artist id and display name.

It must not write `StudioSettings`, `WeeklyAvailability`, `AvailabilityBlock`, `Client`, `BookingRequest`, `BookingToken`, `Appointment`, `CalendarConnection` or any other table.

- [ ] **Step 4: Run the focused test and verify it passes**

```bash
npm test -- --runInBand src/auth/production-admin.bootstrap.spec.ts
```

Expected: the Argon2id and payload assertions pass.

- [ ] **Step 5: Commit the bootstrap operation**

```bash
git add api/src/auth/production-admin.bootstrap.ts api/src/auth/production-admin.bootstrap.spec.ts
git commit -m "feat(auth): add idempotent production admin bootstrap"
```

---

### Task 4: Expose the one-time Prisma CLI and guard its output

**Files:**
- Create: `api/prisma/bootstrap-production-admin.ts`
- Modify: `api/package.json`
- Test: `api/src/auth/production-admin.config.spec.ts` and `api/src/auth/production-admin.bootstrap.spec.ts`

**Interfaces:**
- Consumes: `readProductionAdminConfig`, `bootstrapProductionAdmin`, and `DATABASE_URL` consumed internally by `PrismaClient`.
- Produces: `npm run db:bootstrap-admin`.

- [ ] **Step 1: Add the script entry before implementation**

Add this exact package script:

```json
"db:bootstrap-admin": "ts-node --transpile-only prisma/bootstrap-production-admin.ts"
```

- [ ] **Step 2: Implement the CLI lifecycle**

The CLI must:

- read and validate configuration before connecting to Prisma;
- instantiate one `PrismaClient` only after validation;
- call `bootstrapProductionAdmin`;
- print only a safe JSON result such as `{ "bootstrapped": true, "artistId": "...", "displayName": "Dodogio" }`;
- never print `ADMIN_PASSWORD`, `ADMIN_BOOTSTRAP_CONFIRM`, `DATABASE_URL` or a Prisma error containing connection details;
- set a non-zero exit code on validation/database failure;
- always disconnect Prisma in `finally`.

The error path must use a fixed safe message (`Production admin bootstrap failed`) plus a non-secret validation message. Do not serialize arbitrary database errors.

- [ ] **Step 3: Verify TypeScript, package wiring and existing tests**

Run from `api/`:

```bash
npm test -- --runInBand src/auth/auth.constants.spec.ts src/auth/production-admin.config.spec.ts src/auth/production-admin.bootstrap.spec.ts
npm run build
```

Expected: all focused tests pass and NestJS compiles.

- [ ] **Step 4: Commit the CLI**

```bash
git add api/prisma/bootstrap-production-admin.ts api/package.json
git commit -m "feat(api): expose production admin bootstrap command"
```

---

### Task 5: Verify against the empty Neon production schema and document the release runbook

**Files:**
- Modify: `api/README.md`
- Modify: `context/design/2026-10-20-inkslot-production-admin-bootstrap-design.md`
- Modify: `context/tasks/backlog.md`
- Modify: `context/manifest.json` only if a newly referenced document is added

**Interfaces:**
- Consumes: the deployed schema, `npm run db:bootstrap-admin`, and Render environment configuration.
- Produces: reproducible evidence that exactly one active Artist exists and no demo rows were created.

- [ ] **Step 1: Add the safe production runbook**

Document this procedure without embedding the secret value:

```bash
cd api
read -r -s DATABASE_URL
export DATABASE_URL
export ADMIN_LOGIN_USERNAME='dodo'
export ADMIN_EMAIL='pierorellanao6@gmail.com'
export ADMIN_DISPLAY_NAME='Dodogio'
export ADMIN_BOOTSTRAP_CONFIRM='CREATE_PRODUCTION_ADMIN'
read -r -s ADMIN_PASSWORD
export ADMIN_PASSWORD
npm run db:bootstrap-admin
unset ADMIN_PASSWORD ADMIN_BOOTSTRAP_CONFIRM DATABASE_URL
```

The runbook must explicitly say that the username/email/display-name mapping remains in Render, the password and confirmation are removed, and `npm run db:seed` is never run against Neon.

- [ ] **Step 2: Run the production command once against Neon**

Use the already-applied Neon migrations and supply the connection string from the local ignored environment or Render secret manager without printing it. Verify the command returns a safe success object and exit code 0.

- [ ] **Step 3: Verify database invariants with non-secret SQL**

Run a query that returns counts only:

```sql
SELECT
  (SELECT count(*) FROM artists) AS artists,
  (SELECT count(*) FROM studio_settings) AS studio_settings,
  (SELECT count(*) FROM clients) AS clients,
  (SELECT count(*) FROM booking_requests) AS booking_requests,
  (SELECT count(*) FROM booking_tokens) AS booking_tokens,
  (SELECT count(*) FROM appointments) AS appointments,
  (SELECT count(*) FROM weekly_availability) AS weekly_availability,
  (SELECT count(*) FROM availability_blocks) AS availability_blocks;
```

Expected after bootstrap: `artists = 1`, every other count is `0`. A second command execution must leave all counts unchanged and must not create a second artist.

- [ ] **Step 4: Verify runtime authentication without exposing credentials**

Start the API with `ADMIN_LOGIN_USERNAME`, `ADMIN_EMAIL`, `ADMIN_DISPLAY_NAME` and the production `DATABASE_URL`; do not set `DEMO_*` variables. Exercise `POST /v1/auth/login` with the approved credentials through the normal admin client, verify `200` and an HttpOnly session cookie, then verify:

- `GET /v1/auth/me` returns `Dodogio` and role `admin`.
- an incorrect password returns the existing generic `AUTH_INVALID` response.
- a login using an unknown username does not resolve to the demo artist.

- [ ] **Step 5: Record SDD evidence and close the production-admin task**

Update the design status, backlog evidence and any production runbook reference. Include migration status, focused tests, build result, bootstrap result and count verification. Do not include the password, connection string, session cookie or OAuth credentials in the evidence.

- [ ] **Step 6: Commit the release documentation**

```bash
git add api/README.md context/design/2026-10-20-inkslot-production-admin-bootstrap-design.md context/tasks/backlog.md
git commit -m "docs(sdd): document production admin release verification"
```

---

## Self-review against the approved design

- Explicit one-time CLI: covered by Tasks 3 and 4.
- Argon2id password hashing: covered by Task 3 and its verification.
- Artist-only upsert with `Dodogio` and the approved email: covered by Task 3 and Task 5.
- No clients, requests, tokens, appointments, schedules or Calendar data: enforced by the single-delegate implementation and count verification in Task 5.
- Idempotence: covered by Prisma `upsert` and the second-run count check.
- No HTTP bootstrap endpoint: no controller or route is added.
- No `db:seed` in production: runbook and release evidence explicitly forbid it.
- No secret leakage: validation, CLI output, README and SDD evidence all exclude the password and connection string.
- `dodo` login after provisioning: covered by the persistent non-secret `ADMIN_LOGIN_USERNAME`/`ADMIN_EMAIL` mapping and runtime auth tests.

The plan intentionally does not create production schedules, Google Calendar connections, clients or requests; those are separate operational setup decisions after the first admin can authenticate.

