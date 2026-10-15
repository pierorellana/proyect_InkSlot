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
createdb -O inkslot inkslot_shadow
```

If either database already exists, keep it. `inkslot_shadow` is used only by Prisma's local migration checks; the application role does not receive persistent `CREATEDB` privileges. The application connection strings live in `api/.env` and are never committed.

## API

```bash
cd api
cp .env.example .env
npm install
npx prisma migrate dev
npm run start:dev
```

Health endpoint: http://localhost:3000/v1/health

## Google Calendar local

La integración usa el flujo OAuth del backend. Flutter no recibe el client secret ni el refresh token.

En Google Cloud deben estar habilitados Google Calendar API, OAuth consent screen, un usuario de prueba cuando la audiencia sea `External`, un cliente OAuth de tipo Web y este redirect URI exacto:

```text
http://localhost:3000/v1/admin/calendar/callback
```

En `api/.env` deben existir los valores reales, sin subirlos a Git:

```env
GOOGLE_CLIENT_ID=
GOOGLE_CLIENT_SECRET=
GOOGLE_REDIRECT_URI=http://localhost:3000/v1/admin/calendar/callback
GOOGLE_CALENDAR_NAME=InkSlot
GOOGLE_CALENDAR_SCOPES=https://www.googleapis.com/auth/calendar.freebusy,https://www.googleapis.com/auth/calendar.events,https://www.googleapis.com/auth/calendar.calendarlist.readonly
GOOGLE_TOKEN_ENCRYPTION_KEY=
CALENDAR_TIMEZONE=America/Guayaquil
```

La clave `GOOGLE_TOKEN_ENCRYPTION_KEY` debe decodificar a 32 bytes. Para generarla localmente:

```bash
openssl rand -base64 32
```

### Verificar la conexión

1. Inicia el API con `npm run start:dev`.
2. Inicia sesión con el administrador local y conserva la cookie `inkslot_session`.
3. Llama `GET /v1/admin/calendar/connect` usando esa cookie.
4. Abre `authorizationUrl` en el mismo navegador y autoriza el usuario de prueba.
5. El callback devuelve JSON seguro; no devuelve tokens.
6. Comprueba `GET /v1/admin/calendar/status` con la cookie administrativa.

La conexión se activa solamente si Google devuelve exactamente un calendario cuyo nombre sea `InkSlot`. Si falta o hay más de uno, la API devuelve `CALENDAR_SELECTION_REQUIRED`. `freeBusy`, creación de eventos y outbox todavía pertenecen a las siguientes rebanadas SDD.

## Flutter Web

```bash
cd app
fvm use 3.47.5
fvm flutter pub get
fvm flutter test
fvm flutter run -d chrome --web-port 8080
```

Shell URL: http://localhost:8080
