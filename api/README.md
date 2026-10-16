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
configuration only; production credentials must be provisioned separately.

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
