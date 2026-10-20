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

## Production admin bootstrap

The first production administrator is provisioned once with the dedicated CLI.
Run it from the API service working directory connected to the production
database; do not invoke it as part of `start:prod` or a normal deploy.

1. In the Render service environment, keep these non-secret variables
   configured persistently:

   ```text
   ADMIN_LOGIN_USERNAME
   ADMIN_EMAIL
   ADMIN_DISPLAY_NAME
   ```

2. Add `ADMIN_PASSWORD` and `ADMIN_BOOTSTRAP_CONFIRM` temporarily through the
   Render environment/secrets UI. Do not place either value in this README,
   `.env.example`, the repository, shell history or a Flutter build.

3. Run the command without putting secrets in the command line:

   ```bash
   npm run db:bootstrap-admin
   ```

   The command validates the complete production configuration, hashes the
   password with Argon2id and performs an idempotent artist upsert. It does not
   create demo clients, requests, tokens, appointments or availability rows.

4. After the command succeeds, verify the production login and then remove
   `ADMIN_PASSWORD` and `ADMIN_BOOTSTRAP_CONFIRM` from Render immediately.
   Keep only the three non-secret mapping variables so `dodo` continues to
   resolve to the provisioned artist.

5. Never use `npm run db:seed` against Neon or any other production database.
   That command is reserved for the local development/QA fixture.

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
