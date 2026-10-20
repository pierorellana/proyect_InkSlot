# InkSlot API

NestJS + TypeScript API for the local InkSlot workspace. PostgreSQL runs as a
native local service; Docker is not required.

## Local setup

From the workspace root, prepare PostgreSQL and the two databases described in
[`context/local-development.md`](../context/local-development.md). Then run:

```bash
cd api
cp .env.example .env
npm install
npx prisma migrate dev
npm run db:seed
npm run start:dev
```

The health endpoint is available at `http://localhost:3000/v1/health` and
reports the PostgreSQL connectivity state.

For the local demo admin, open the Flutter Web hash route
`/#/admin/login` and use `dodo` / `1234`. These credentials are local demo
configuration only. The `DEMO_*` variables belong exclusively to
`npm run db:seed` and are not read by runtime login resolution.

Production uses the separate `ADMIN_LOGIN_USERNAME`, `ADMIN_EMAIL` and
`ADMIN_DISPLAY_NAME` mapping. Configure those non-secret values in the
deployed API so the login username resolves to the production artist. The
production password must be supplied out-of-band only to the one-time admin
bootstrap; do not add it to this file, `.env.example`, the repository or the
Flutter bundle. Never run `npm run db:seed` against the production database.

## Checks

```bash
npm run format
npm run build
npx prisma migrate status
npm run test:e2e -- --runInBand --watchman=false health.e2e-spec.ts
```

The application uses Prisma 6.19.0 with an explicit local shadow database so
the `inkslot` application role does not need persistent database-creation
privileges.
