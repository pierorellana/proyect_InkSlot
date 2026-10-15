# InkSlot Bootstrap Implementation Plan

> For agentic workers: use the repository's task-by-task execution loop. Each task ends with its own test/check and focused commit.

**Goal:** Create the first independently verifiable InkSlot increment: a three-root local workspace with a Flutter Web shell, a NestJS health API, and a native local PostgreSQL connection through Prisma.

**Architecture:** app/ contains a minimal Provider/GoRouter Flutter shell. api/ contains a versioned NestJS REST shell with global validation and an injectable Prisma client. PostgreSQL runs as a locally installed service; no Docker or Compose files are created.

**Tech Stack:** Flutter Web, Dart, Provider, GoRouter, package:http, flutter_svg, intl, NestJS, TypeScript strict mode, Prisma, PostgreSQL, Jest, Supertest.

## Global Constraints

- The workspace root contains only app/, api/, and context/ as project directories.
- Frontend is Flutter Web + Provider; do not add Riverpod or Bloc.
- Backend is NestJS + TypeScript; do not add a second server framework.
- PostgreSQL is local; do not create Dockerfiles, Compose files, or container scripts.
- Prisma is the ORM; future PostgreSQL-specific constraints are written in SQL migrations.
- context/references/InkSlot_Prototipo.html, context/references/InkSlot_Prototipo.zip, and context/references/InkSlot_Documentacion_Tecnica.pdf remain local and ignored by Git.
- The bootstrap shell must not claim that booking, authentication, Calendar, or persistence features already exist.
- Run formatters and tests before each commit; never commit .env, generated builds, or secrets.

## Scope Boundary

This plan covers only the bootstrap increment. Later plans will independently deliver: visual foundation/assets; Prisma domain schema/auth; availability; requests/tokens; public booking; transactional confirmation; Google Calendar/outbox; and admin appointments/quality/CI.

The bootstrap is complete when a developer can start native PostgreSQL, run the API health check against it, run the Flutter Web shell, and execute both test suites.

---

### Task 1: Document local development

**Files:**
- Create: context/local-development.md
- Modify: .gitignore

**Interfaces:**
- Produces: exact local setup commands for all later plans.
- Consumes: the approved no-Docker PostgreSQL decision.

- [ ] Step 1: Create context/local-development.md.

~~~markdown
# InkSlot local development

## Required local tools

- Flutter SDK with Web/Chrome support.
- Dart SDK supplied by Flutter.
- Node.js and npm.
- PostgreSQL server and psql client.

Docker is not part of this project.

## PostgreSQL

Start the locally installed PostgreSQL service. From a PostgreSQL administrator connection, create the application role:

~~~sql
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'inkslot') THEN
    CREATE ROLE inkslot LOGIN PASSWORD 'inkslot';
  END IF;
END
$$;
~~~

Create the database once:

~~~bash
createdb -O inkslot inkslot_dev
~~~

If the database already exists, keep it. The application connection string lives in api/.env and is never committed.

## API

~~~bash
cd api
cp .env.example .env
npm install
npx prisma migrate dev
npm run start:dev
~~~

Health endpoint: http://localhost:3000/v1/health

## Flutter Web

~~~bash
cd app
flutter pub get
flutter test
flutter run -d chrome --web-port 8080
~~~

Shell URL: http://localhost:8080
~~~

- [ ] Step 2: Add these entries to .gitignore while retaining the existing reference exclusions.

~~~gitignore
api/.env
api/node_modules/
api/dist/
api/coverage/
app/.dart_tool/
app/build/
app/.flutter-plugins
app/.flutter-plugins-dependencies
~~~

- [ ] Step 3: Verify the policy is documented.

Run: rg -n "docker|compose|Docker|Compose" context/local-development.md .gitignore

Expected: only the deliberate sentence "Docker is not part of this project." appears in the documentation; no container file is added.

- [ ] Step 4: Commit.

~~~bash
git add context/local-development.md .gitignore
git commit -m "docs(context): define local development contract"
~~~

---

### Task 2: Scaffold the Flutter Web shell

**Files:**
- Create: app/ with the Flutter Web scaffold.
- Modify: app/pubspec.yaml
- Create: app/lib/app.dart
- Create: app/lib/main.dart
- Create: app/lib/core/router/app_router.dart
- Create: app/lib/core/theme/inkslot_theme.dart
- Create: app/lib/features/home/presentation/home_page.dart
- Create: app/test/smoke_test.dart

**Interfaces:**
- Produces: InkSlotApp and AppRouter.create().
- Consumes: Flutter Web and Task 1's local commands.

- [ ] Step 1: Generate Web only and add packages.

~~~bash
flutter create --platforms=web --project-name inkslot_app app
cd app
flutter pub add provider go_router http flutter_svg intl
rm test/widget_test.dart
~~~

Expected: app/web exists and no mobile platform directory is generated.

- [ ] Step 2: Write app/test/smoke_test.dart before implementation.

~~~dart
import 'package:flutter_test/flutter_test.dart';
import 'package:inkslot_app/app.dart';

void main() {
  testWidgets('renders the InkSlot shell', (tester) async {
    await tester.pumpWidget(const InkSlotApp());
    expect(find.text('InkSlot'), findsOneWidget);
    expect(find.text('Bootstrap local'), findsOneWidget);
  });
}
~~~

Run: flutter test test/smoke_test.dart

Expected: FAIL because InkSlotApp is not defined.

- [ ] Step 3: Create app/lib/core/theme/inkslot_theme.dart.

~~~dart
import 'package:flutter/material.dart';

abstract final class InkSlotColors {
  static const ink = Color(0xFF0A0A0B);
  static const deep = Color(0xFF050505);
  static const surface = Color(0xFF131315);
  static const bone = Color(0xFFEEE9E0);
  static const ash = Color(0xFF9B968E);
  static const copper = Color(0xFFC87939);
}

ThemeData buildInkSlotTheme() => ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: InkSlotColors.deep,
      colorScheme: const ColorScheme.dark(
        surface: InkSlotColors.surface,
        primary: InkSlotColors.copper,
        onPrimary: InkSlotColors.ink,
        onSurface: InkSlotColors.bone,
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          color: InkSlotColors.bone,
          fontSize: 40,
          height: 1,
        ),
        bodyLarge: TextStyle(color: InkSlotColors.bone, fontSize: 16),
        bodyMedium: TextStyle(color: InkSlotColors.ash, fontSize: 15),
      ),
    );
~~~

- [ ] Step 4: Create the page and router.

app/lib/features/home/presentation/home_page.dart:

~~~dart
import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('InkSlot',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 12),
                const Text('Bootstrap local'),
              ],
            ),
          ),
        ),
      );
}
~~~

app/lib/core/router/app_router.dart:

~~~dart
import 'package:go_router/go_router.dart';

import '../../features/home/presentation/home_page.dart';

abstract final class AppRouter {
  static GoRouter create() => GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(path: '/', builder: (_, __) => const HomePage()),
          GoRoute(path: '/r/:token', builder: (_, __) => const HomePage()),
          GoRoute(path: '/admin/login', builder: (_, __) => const HomePage()),
        ],
      );
}
~~~

- [ ] Step 5: Create app/lib/app.dart and replace app/lib/main.dart.

app/lib/app.dart:

~~~dart
import 'package:flutter/material.dart';

import 'core/router/app_router.dart';
import 'core/theme/inkslot_theme.dart';

class InkSlotApp extends StatelessWidget {
  const InkSlotApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: 'InkSlot',
        theme: buildInkSlotTheme(),
        routerConfig: AppRouter.create(),
      );
}
~~~

app/lib/main.dart:

~~~dart
import 'package:flutter/widgets.dart';

import 'app.dart';

void main() => runApp(const InkSlotApp());
~~~

- [ ] Step 6: Format, test, and commit.

~~~bash
dart format lib test
flutter test test/smoke_test.dart
git add app
git commit -m "feat(app): add Flutter Web shell with Provider-ready routing"
~~~

Expected: formatting and one smoke test pass.

---

### Task 3: Scaffold the NestJS versioned API

**Files:**
- Create: api/ with the NestJS CLI.
- Modify: api/src/main.ts
- Modify: api/src/app.module.ts
- Create: api/src/health/health.module.ts
- Create: api/src/health/health.controller.ts
- Create: api/test/health.e2e-spec.ts

**Interfaces:**
- Produces: GET /v1/health returning { status: "ok", service: "inkslot-api" }.
- Consumes: no database or external provider.

- [ ] Step 1: Generate the project and install foundation packages.

~~~bash
npx @nestjs/cli new api --package-manager npm --skip-git --strict
cd api
npm install @nestjs/config @nestjs/swagger @nestjs/throttler class-validator class-transformer
npm install -D prettier
~~~

If the installed CLI rejects --strict, preserve its generated configuration and set strict: true in api/tsconfig.json.

- [ ] Step 2: Write api/test/health.e2e-spec.ts.

~~~typescript
import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';

import { AppModule } from '../src/app.module';

describe('GET /v1/health', () => {
  let app: INestApplication;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();
    app = moduleRef.createNestApplication();
    app.setGlobalPrefix('v1');
    app.useGlobalPipes(new ValidationPipe({
      transform: true,
      whitelist: true,
      forbidNonWhitelisted: true,
    }));
    await app.init();
  });

  afterAll(async () => app.close());

  it('returns a stable service health payload', async () => {
    await request(app.getHttpServer())
      .get('/v1/health')
      .expect(200)
      .expect({ status: 'ok', service: 'inkslot-api' });
  });
});
~~~

Run: npm run test:e2e -- --runInBand health.e2e-spec.ts

Expected: FAIL because the health module does not exist.

- [ ] Step 3: Create api/src/health/health.controller.ts and health.module.ts.

~~~typescript
// health.controller.ts
import { Controller, Get } from '@nestjs/common';

@Controller('health')
export class HealthController {
  @Get()
  getHealth() {
    return { status: 'ok', service: 'inkslot-api' } as const;
  }
}

// health.module.ts
import { Module } from '@nestjs/common';
import { HealthController } from './health.controller';

@Module({ controllers: [HealthController] })
export class HealthModule {}
~~~

- [ ] Step 4: Replace api/src/app.module.ts and api/src/main.ts.

~~~typescript
// app.module.ts
import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { ThrottlerModule } from '@nestjs/throttler';
import { HealthModule } from './health/health.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    ThrottlerModule.forRoot([{ ttl: 60_000, limit: 100 }]),
    HealthModule,
  ],
})
export class AppModule {}

// main.ts
import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.setGlobalPrefix('v1');
  app.enableCors({ origin: true, credentials: true });
  app.useGlobalPipes(new ValidationPipe({
    transform: true,
    whitelist: true,
    forbidNonWhitelisted: true,
  }));
  await app.listen(process.env.PORT ?? 3000);
}

void bootstrap();
~~~

- [ ] Step 5: Build, test, and commit.

~~~bash
npm run build
npm run test:e2e -- --runInBand health.e2e-spec.ts
git add api
git commit -m "feat(api): add versioned NestJS health endpoint"
~~~

Expected: build and one e2e test pass.

---

### Task 4: Connect Prisma to local PostgreSQL

**Files:**
- Create: api/.env.example
- Create: api/prisma/schema.prisma
- Create: api/src/database/prisma.service.ts
- Create: api/src/database/prisma.module.ts
- Modify: api/src/app.module.ts
- Modify: api/src/health/health.controller.ts
- Modify: api/test/health.e2e-spec.ts

**Interfaces:**
- Produces: injectable PrismaService and health response with database: "ok".
- Consumes: local DATABASE_URL and database inkslot_dev.

- [ ] Step 1: Create api/.env.example and copy it locally.

~~~dotenv
NODE_ENV=development
PORT=3000
DATABASE_URL="postgresql://inkslot:inkslot@127.0.0.1:5432/inkslot_dev?schema=public"
~~~

Run: cp api/.env.example api/.env

- [ ] Step 2: Create api/prisma/schema.prisma.

~~~prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model Artist {
  id          String   @id @default(uuid()) @db.Uuid
  email       String   @unique @db.VarChar(320)
  displayName String   @map("display_name") @db.VarChar(120)
  active      Boolean  @default(true)
  createdAt   DateTime @default(now()) @map("created_at") @db.Timestamptz(6)
  updatedAt   DateTime @updatedAt @map("updated_at") @db.Timestamptz(6)
  @@map("artists")
}
~~~

- [ ] Step 3: Install Prisma and generate the client.

~~~bash
cd api
npm install @prisma/client
npm install -D prisma
npx prisma generate
~~~

Expected: Prisma Client generation uses the same major version as the Prisma CLI.

- [ ] Step 4: Change the health test expected payload and verify the red state.

Change the test expectation to:

~~~typescript
.expect({ status: 'ok', service: 'inkslot-api', database: 'ok' });
~~~

Run: npm run test:e2e -- --runInBand health.e2e-spec.ts

Expected: FAIL because the controller does not query PostgreSQL.

- [ ] Step 5: Create the Prisma service and module.

~~~typescript
// prisma.service.ts
import { Injectable, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit, OnModuleDestroy {
  async onModuleInit() { await this.$connect(); }
  async onModuleDestroy() { await this.$disconnect(); }
}

// prisma.module.ts
import { Global, Module } from '@nestjs/common';
import { PrismaService } from './prisma.service';

@Global()
@Module({ providers: [PrismaService], exports: [PrismaService] })
export class PrismaModule {}
~~~

- [ ] Step 6: Inject Prisma into health and register the global module.

api/src/health/health.controller.ts:

~~~typescript
import { Controller, Get, ServiceUnavailableException } from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';

@Controller('health')
export class HealthController {
  constructor(private readonly prisma: PrismaService) {}

  @Get()
  async getHealth() {
    try {
      await this.prisma.$queryRawUnsafe('SELECT 1');
      return { status: 'ok', service: 'inkslot-api', database: 'ok' } as const;
    } catch {
      throw new ServiceUnavailableException({
        status: 'error',
        service: 'inkslot-api',
        database: 'unavailable',
      });
    }
  }
}
~~~

Add PrismaModule to the imports array in api/src/app.module.ts before HealthModule:

~~~typescript
import { PrismaModule } from './database/prisma.module';

imports: [
  ConfigModule.forRoot({ isGlobal: true }),
  ThrottlerModule.forRoot([{ ttl: 60_000, limit: 100 }]),
  PrismaModule,
  HealthModule,
],
~~~

- [ ] Step 7: Start PostgreSQL, migrate, test, and verify the endpoint.

~~~bash
npx prisma migrate dev --name bootstrap_artist
npx prisma migrate status
npm run build
npm run test:e2e -- --runInBand health.e2e-spec.ts
curl -sS http://localhost:3000/v1/health
~~~

Expected JSON: {"status":"ok","service":"inkslot-api","database":"ok"}

- [ ] Step 8: Commit the database connection.

~~~bash
git add api/.env.example api/prisma api/src api/test
git commit -m "feat(api): connect NestJS health check to local PostgreSQL"
~~~

---

### Task 5: Verify the complete local bootstrap

**Files:**
- Modify: context/local-development.md only if a verified command differs.
- Test: app/test/smoke_test.dart
- Test: api/test/health.e2e-spec.ts

**Interfaces:**
- Produces: reproducible startup and a clean Git boundary.
- Consumes: Tasks 1–4.

- [ ] Step 1: Verify roots.

Run: find . -maxdepth 1 -type d -print | sort

Expected project roots: ., .git, app, api, context. No Docker or Compose artifact exists.

- [ ] Step 2: Run frontend checks.

~~~bash
cd app
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build web
~~~

Expected: all commands pass; app/build/web/ remains ignored.

- [ ] Step 3: Run backend checks.

~~~bash
cd api
npx prisma migrate status
npm run build
npm run test:e2e -- --runInBand
~~~

Expected: migrations are current, build passes, and the health suite passes.

- [ ] Step 4: Verify ignored boundaries.

Run: git status --short --ignored

Expected: .env, prototype references, PDF, node_modules, and build artifacts are ignored and not staged.

- [ ] Step 5: Commit a documentation correction only if verification changed a command.

~~~bash
git add context/local-development.md
git commit -m "docs(context): align local bootstrap commands"
~~~

Do not create an empty commit when no correction was required.

## Plan Self-Review

- Spec coverage: local workspace, local PostgreSQL policy, Flutter shell, NestJS shell, Prisma connection, validation foundation, and bootstrap verification are covered. Auth, availability, requests, booking, Calendar, visual fidelity, accessibility, E2E, and CI are separate follow-up plans.
- Placeholder scan: no step depends on an unspecified file name, unbounded task, Docker service, or unapproved product behavior.
- Type consistency: InkSlotApp, AppRouter.create(), HealthModule, HealthController, PrismaModule, and PrismaService are defined before their consumers. The health test payload matches the final controller payload.
- Local-only check: .env.example is tracked, .env is ignored, PostgreSQL is native, and no container artifact is introduced.
