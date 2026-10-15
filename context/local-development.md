# InkSlot local development

## Required local tools

- FVM 2.4.1 or compatible, with Flutter 3.47.5 selected for this project.
- Flutter SDK 3.47.5 with Web/Chrome support, managed through FVM.
- Dart SDK 3.13.4 supplied by Flutter 3.47.5.
- Node.js and npm.
- PostgreSQL server and `psql` client.

Docker is not part of this project.

## PostgreSQL

Start the locally installed PostgreSQL service. From a PostgreSQL administrator connection, create the application role:

```sql
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'inkslot') THEN
    CREATE ROLE inkslot LOGIN PASSWORD 'inkslot';
  END IF;
END
$$;
```

Create the database once:

```bash
createdb -O inkslot inkslot_dev
```

If the database already exists, keep it. The application connection string lives in `api/.env` and is never committed.

## API

```bash
cd api
cp .env.example .env
npm install
npx prisma migrate dev
npm run start:dev
```

Health endpoint: http://localhost:3000/v1/health

## Flutter Web

```bash
cd app
fvm use 3.47.5
fvm flutter pub get
fvm flutter test
fvm flutter run -d chrome --web-port 8080
```

Shell URL: http://localhost:8080
