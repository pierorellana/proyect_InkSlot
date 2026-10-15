import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { CalendarConnectionStatus } from '@prisma/client';
import * as argon2 from 'argon2';
import request from 'supertest';

import { AppModule } from '../src/app.module';
import {
  CALENDAR_CONFIG,
  CALENDAR_PROVIDER,
} from '../src/calendar/calendar.constants';
import type { CalendarConfig } from '../src/calendar/calendar.config';
import { CalendarCrypto } from '../src/calendar/calendar.crypto';
import type { CalendarProvider } from '../src/calendar/calendar.provider';
import { PrismaService } from '../src/database/prisma.service';

jest.setTimeout(15_000);

describe('admin calendar connection', () => {
  let app: INestApplication;
  let prisma: PrismaService;
  let artistId: string;
  let cookies: string[];

  const fakeProvider = {
    authorizationUrl: jest.fn(
      ({ state }: { state: string }) =>
        `https://accounts.google.test/auth?state=${encodeURIComponent(state)}`,
    ),
    exchangeCode: jest.fn().mockResolvedValue({
      refreshToken: 'refresh-token-secret',
    }),
    listCalendars: jest
      .fn()
      .mockResolvedValue([{ id: 'inkslot-id', name: 'InkSlot' }]),
    revoke: jest.fn().mockResolvedValue(undefined),
  } as jest.Mocked<CalendarProvider>;

  const fakeCrypto = {
    encrypt: jest.fn((value: string) => `encrypted:${value}`),
    decrypt: jest.fn(() => 'refresh-token-secret'),
  };

  const fakeConfig: CalendarConfig = {
    configured: true,
    clientId: 'client-id',
    clientSecret: 'client-secret',
    redirectUri: 'http://localhost:3000/v1/admin/calendar/callback',
    calendarName: 'InkSlot',
    scopes: ['scope-a'],
    tokenEncryptionKey: Buffer.alloc(32),
  };

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    })
      .overrideProvider(CALENDAR_CONFIG)
      .useValue(fakeConfig)
      .overrideProvider(CALENDAR_PROVIDER)
      .useValue(fakeProvider)
      .overrideProvider(CalendarCrypto)
      .useValue(fakeCrypto)
      .compile();

    app = moduleRef.createNestApplication();
    app.setGlobalPrefix('v1');
    app.useGlobalPipes(
      new ValidationPipe({
        transform: true,
        whitelist: true,
        forbidNonWhitelisted: true,
      }),
    );
    await app.init();

    prisma = app.get(PrismaService);
    const artist = await prisma.artist.create({
      data: {
        email: `calendar-${Date.now()}@example.test`,
        passwordHash: await argon2.hash('local-test-password', {
          type: argon2.argon2id,
        }),
        displayName: 'Calendar Test Artist',
      },
    });
    artistId = artist.id;

    const seededLogin = await request(app.getHttpServer())
      .post('/v1/auth/login')
      .send({ email: artist.email, password: 'local-test-password' });
    if (seededLogin.status !== 200) {
      throw new Error('Calendar test setup could not create an admin session');
    }
    cookies = seededLogin.headers['set-cookie'] as string[];
  });

  beforeEach(async () => {
    await prisma.calendarConnection.deleteMany({ where: { artistId } });
    await prisma.calendarOAuthState.deleteMany({ where: { artistId } });
    fakeProvider.exchangeCode.mockResolvedValue({
      refreshToken: 'refresh-token-secret',
    });
    fakeProvider.listCalendars.mockResolvedValue([
      { id: 'inkslot-id', name: 'InkSlot' },
    ]);
    fakeProvider.revoke.mockResolvedValue(undefined);
    fakeCrypto.encrypt.mockImplementation(
      (value: string) => `encrypted:${value}`,
    );
    fakeCrypto.decrypt.mockReturnValue('refresh-token-secret');
  });

  afterAll(async () => {
    await prisma.artist.delete({ where: { id: artistId } });
    await app.close();
  });

  it('returns 401 without an admin session', async () => {
    await request(app.getHttpServer())
      .get('/v1/admin/calendar/status')
      .expect(401);
  });

  it('returns disconnected for an authenticated artist without a connection', async () => {
    await request(app.getHttpServer())
      .get('/v1/admin/calendar/status')
      .set('Cookie', cookies)
      .expect(200)
      .expect({ status: 'disconnected' });
  });

  it('creates state, completes the callback, and persists only encrypted token data', async () => {
    const connect = await request(app.getHttpServer())
      .get('/v1/admin/calendar/connect')
      .set('Cookie', cookies)
      .expect(200);
    const connectBody = connect.body as {
      authorizationUrl: string;
      expiresAt: string;
    };
    const state = new URL(connectBody.authorizationUrl).searchParams.get(
      'state',
    );

    expect(state).toBeTruthy();
    expect(connectBody.expiresAt).toEqual(expect.any(String));

    const callback = await request(app.getHttpServer())
      .get('/v1/admin/calendar/callback')
      .query({ code: 'authorization-code', state })
      .expect(200);

    expect(callback.body).toEqual({
      status: 'connected',
      calendarName: 'InkSlot',
    });
    expect(callback.text).not.toContain('refresh-token-secret');
    expect(fakeProvider.exchangeCode).toHaveBeenCalledWith(
      'authorization-code',
    );

    const connection = await prisma.calendarConnection.findUnique({
      where: { artistId },
    });
    expect(connection).toMatchObject({
      calendarId: 'inkslot-id',
      calendarName: 'InkSlot',
      encryptedRefreshToken: 'encrypted:refresh-token-secret',
      status: CalendarConnectionStatus.CONNECTED,
    });
  });

  it('rejects an invalid or replayed OAuth state', async () => {
    await request(app.getHttpServer())
      .get('/v1/admin/calendar/callback')
      .query({ code: 'authorization-code', state: 'invalid-state' })
      .expect(400)
      .expect({
        error: {
          code: 'OAUTH_STATE_INVALID',
          message: 'El estado de autorización no es válido o expiró',
        },
      });

    const connect = await request(app.getHttpServer())
      .get('/v1/admin/calendar/connect')
      .set('Cookie', cookies)
      .expect(200);
    const state = new URL(connect.body.authorizationUrl).searchParams.get(
      'state',
    );

    await request(app.getHttpServer())
      .get('/v1/admin/calendar/callback')
      .query({ code: 'authorization-code', state })
      .expect(200);
    await request(app.getHttpServer())
      .get('/v1/admin/calendar/callback')
      .query({ code: 'authorization-code', state })
      .expect(400);
  });

  it('does not connect when InkSlot is missing or ambiguous', async () => {
    fakeProvider.listCalendars.mockResolvedValue([
      { id: 'primary', name: 'Primary' },
    ]);
    const missingConnect = await request(app.getHttpServer())
      .get('/v1/admin/calendar/connect')
      .set('Cookie', cookies)
      .expect(200);
    const missingState = new URL(
      missingConnect.body.authorizationUrl,
    ).searchParams.get('state');
    await request(app.getHttpServer())
      .get('/v1/admin/calendar/callback')
      .query({ code: 'authorization-code', state: missingState })
      .expect(409);

    fakeProvider.listCalendars.mockResolvedValue([
      { id: 'inkslot-a', name: 'InkSlot' },
      { id: 'inkslot-b', name: 'InkSlot' },
    ]);
    const ambiguousConnect = await request(app.getHttpServer())
      .get('/v1/admin/calendar/connect')
      .set('Cookie', cookies)
      .expect(200);
    const ambiguousState = new URL(
      ambiguousConnect.body.authorizationUrl,
    ).searchParams.get('state');
    await request(app.getHttpServer())
      .get('/v1/admin/calendar/callback')
      .query({ code: 'authorization-code', state: ambiguousState })
      .expect(409);

    expect(
      await prisma.calendarConnection.findUnique({ where: { artistId } }),
    ).toBeNull();
  });

  it('reports needs_reconnect and disconnects locally without appointments', async () => {
    await prisma.calendarConnection.create({
      data: {
        artistId,
        calendarId: 'inkslot-id',
        calendarName: 'InkSlot',
        encryptedRefreshToken: 'encrypted:refresh-token-secret',
        status: CalendarConnectionStatus.NEEDS_RECONNECT,
      },
    });

    const status = await request(app.getHttpServer())
      .get('/v1/admin/calendar/status')
      .set('Cookie', cookies)
      .expect(200);
    expect(status.body).toEqual({
      status: 'needs_reconnect',
      calendarId: 'inkslot-id',
      calendarName: 'InkSlot',
      connectedAt: null,
      updatedAt: expect.any(String),
    });

    await request(app.getHttpServer())
      .post('/v1/admin/calendar/disconnect')
      .set('Cookie', cookies)
      .expect(204);

    expect(
      await prisma.calendarConnection.findUnique({ where: { artistId } }),
    ).toBeNull();
  });
});
