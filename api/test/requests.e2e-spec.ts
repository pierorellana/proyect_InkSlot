import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import * as argon2 from 'argon2';
import { BookingRequestStatus } from '@prisma/client';
import request from 'supertest';

import { AppModule } from '../src/app.module';
import { hashBookingToken } from '../src/requests/booking-token';
import { PrismaService } from '../src/database/prisma.service';

type CreateResponse = {
  request: {
    id: string;
    client: {
      id: string;
      name: string;
      email: string | null;
      phone: string | null;
    };
    status: string;
  };
  link: { path: string; expiresAt: string };
};

type ListResponse = {
  items: Array<Record<string, unknown>>;
  nextCursor: string | null;
};

type PublicResponse = {
  status: 'pending' | 'booked';
  artist: { displayName: string };
  durationMinutes: number;
  timezone: string;
  restrictions: Record<string, unknown>;
  expiresAt: string;
};

type HttpResponse = {
  body: { error?: { code?: string; message?: string } };
  status: number;
};

type LifecycleResponse = {
  request?: { status?: string };
  status?: string;
};

describe('booking request lifecycle', () => {
  let app: INestApplication;
  let prisma: PrismaService;
  let artistId: string;
  let otherArtistId: string;
  let cookies: string[];
  let otherCookies: string[];
  let existingClientId: string;
  let foreignClientId: string;

  const password = 'local-test-password';
  const suffix = Date.now();
  const email = `requests-${suffix}@example.test`;
  const otherEmail = `requests-other-${suffix}@example.test`;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

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
    const [artist, otherArtist] = await Promise.all([
      prisma.artist.create({
        data: {
          email,
          passwordHash: await argon2.hash(password, { type: argon2.argon2id }),
          displayName: 'Requests Test Artist',
        },
      }),
      prisma.artist.create({
        data: {
          email: otherEmail,
          passwordHash: await argon2.hash(password, { type: argon2.argon2id }),
          displayName: 'Other Requests Artist',
        },
      }),
    ]);
    artistId = artist.id;
    otherArtistId = otherArtist.id;

    await prisma.studioSettings.create({
      data: {
        artistId,
        timezone: 'America/Guayaquil',
        slotStepMinutes: 30,
        bufferMinutes: 15,
        minimumNoticeHours: 24,
        horizonDays: 60,
      },
    });

    const [client, foreignClient] = await Promise.all([
      prisma.client.create({
        data: {
          artistId,
          name: 'Existing Request Client',
          email: 'existing@example.test',
        },
      }),
      prisma.client.create({
        data: {
          artistId: otherArtistId,
          name: 'Foreign Request Client',
          email: 'foreign@example.test',
        },
      }),
    ]);
    existingClientId = client.id;
    foreignClientId = foreignClient.id;

    const login = await request(app.getHttpServer())
      .post('/v1/auth/login')
      .send({ email, password })
      .expect(200);
    cookies = login.headers['set-cookie'] as string[];

    const otherLogin = await request(app.getHttpServer())
      .post('/v1/auth/login')
      .send({ email: otherEmail, password })
      .expect(200);
    otherCookies = otherLogin.headers['set-cookie'] as string[];
  });

  afterAll(async () => {
    await cleanupArtist(artistId);
    await cleanupArtist(otherArtistId);
    await app.close();
  });

  async function cleanupArtist(id: string): Promise<void> {
    const requests = await prisma.bookingRequest.findMany({
      where: { artistId: id },
      select: { id: true },
    });
    const requestIds = requests.map((item) => item.id);

    await prisma.bookingToken.deleteMany({
      where: { request: { artistId: id } },
    });
    await prisma.auditLog.deleteMany({
      where: {
        OR: [
          { actorId: id },
          ...(requestIds.length > 0 ? [{ entityId: { in: requestIds } }] : []),
        ],
      },
    });
    await prisma.bookingRequest.deleteMany({ where: { artistId: id } });
    await prisma.client.deleteMany({ where: { artistId: id } });
    await prisma.weeklyAvailability.deleteMany({ where: { artistId: id } });
    await prisma.availabilityBlock.deleteMany({ where: { artistId: id } });
    await prisma.studioSettings.deleteMany({ where: { artistId: id } });
    await prisma.adminSession.deleteMany({ where: { artistId: id } });
    await prisma.calendarOAuthState.deleteMany({ where: { artistId: id } });
    await prisma.calendarConnection.deleteMany({ where: { artistId: id } });
    await prisma.artist.delete({ where: { id } });
  }

  function errorCode(response: HttpResponse): string | undefined {
    return response.body.error?.code;
  }

  function tokenFromPath(path: string): string {
    const token = path.split('/').at(-1);
    if (!token) throw new Error(`Missing token in path: ${path}`);
    return token;
  }

  async function createInline(
    sessionCookies = cookies,
    overrides: Record<string, unknown> = {},
  ): Promise<{ response: CreateResponse; token: string }> {
    const result = await request(app.getHttpServer())
      .post('/v1/admin/booking-requests')
      .set('Cookie', sessionCookies)
      .send({
        client: {
          name: `Inline Client ${Date.now()}`,
          email: 'inline@example.test',
          phone: '+593999999999',
        },
        depositVerified: true,
        durationMinutes: 180,
        minDate: '2026-10-20',
        maxDate: '2026-11-30',
        allowedWeekdays: [1, 3, 5],
        allowedWindows: [{ startLocal: '10:00', endLocal: '18:00' }],
        ...overrides,
      })
      .expect(201);

    const response = result.body as CreateResponse;
    return { response, token: tokenFromPath(response.link.path) };
  }

  it('rejects administrative booking request access without a session', async () => {
    await request(app.getHttpServer())
      .get('/v1/admin/booking-requests')
      .expect(401);
  });

  it('creates inline clients and persists only the token hash', async () => {
    const { response, token } = await createInline();
    const persisted = await prisma.bookingToken.findFirstOrThrow({
      where: { requestId: response.request.id },
    });

    expect(response.request).toMatchObject({
      client: { email: 'inline@example.test', phone: '+593999999999' },
      status: 'pending',
    });
    expect(response.request.client.name.startsWith('Inline Client')).toBe(true);
    expect(response.link.path).toMatch(/^\/r\/[A-Za-z0-9_-]+$/);
    expect(persisted.tokenHash).toBe(hashBookingToken(token));
    expect(persisted.tokenHash).not.toBe(token);
    expect(JSON.stringify(persisted)).not.toContain(token);
  });

  it('creates a request for an existing scoped client and rejects a foreign client', async () => {
    const existing = await request(app.getHttpServer())
      .post('/v1/admin/booking-requests')
      .set('Cookie', cookies)
      .send({
        clientId: existingClientId,
        depositVerified: true,
        durationMinutes: 90,
      })
      .expect(201);
    expect((existing.body as CreateResponse).request.client.id).toBe(
      existingClientId,
    );

    const foreign = (await request(app.getHttpServer())
      .post('/v1/admin/booking-requests')
      .set('Cookie', cookies)
      .send({
        clientId: foreignClientId,
        depositVerified: true,
        durationMinutes: 90,
      })) as unknown as HttpResponse;
    expect(foreign.status).toBe(404);
    expect(errorCode(foreign)).toBe('NOT_FOUND');
  });

  it('isolates list and detail by artist and does not expose raw tokens', async () => {
    const { response, token } = await createInline();
    const list = await request(app.getHttpServer())
      .get('/v1/admin/booking-requests')
      .set('Cookie', cookies)
      .expect(200);
    const listBody = list.body as ListResponse;
    const detail = await request(app.getHttpServer())
      .get(`/v1/admin/booking-requests/${response.request.id}`)
      .set('Cookie', cookies)
      .expect(200);

    expect(listBody.items.some((item) => item.id === response.request.id)).toBe(
      true,
    );
    expect(listBody.nextCursor).toBeNull();
    expect(JSON.stringify(list.body)).not.toContain(token);
    expect(JSON.stringify(list.body)).not.toContain(hashBookingToken(token));
    expect(JSON.stringify(detail.body)).not.toContain(token);
    expect(JSON.stringify(detail.body)).not.toContain(hashBookingToken(token));
    expect(detail.body).toHaveProperty('currentLink.status', 'active');

    const foreignDetail = (await request(app.getHttpServer())
      .get(`/v1/admin/booking-requests/${response.request.id}`)
      .set('Cookie', otherCookies)) as unknown as HttpResponse;
    expect(foreignDetail.status).toBe(404);
    expect(errorCode(foreignDetail)).toBe('NOT_FOUND');
  });

  it('rotates tokens on renew and revokes the previous public link', async () => {
    const created = await createInline();
    const renewed = await request(app.getHttpServer())
      .post(`/v1/admin/booking-requests/${created.response.request.id}/renew`)
      .set('Cookie', cookies)
      .send({ tokenTtlHours: 24 })
      .expect(201);
    const renewedBody = renewed.body as CreateResponse;
    const newToken = tokenFromPath(renewedBody.link.path);

    const oldPublic = (await request(app.getHttpServer()).get(
      `/v1/public/reservations/${created.token}`,
    )) as unknown as HttpResponse;
    expect(oldPublic.status).toBe(410);
    expect(errorCode(oldPublic)).toBe('TOKEN_REVOKED');

    const newPublic = await request(app.getHttpServer())
      .get(`/v1/public/reservations/${newToken}`)
      .expect(200);
    expect((newPublic.body as PublicResponse).status).toBe('pending');

    const tokenRows = await prisma.bookingToken.findMany({
      where: { requestId: created.response.request.id },
      orderBy: { createdAt: 'asc' },
    });
    expect(tokenRows).toHaveLength(2);
    expect(tokenRows[0].revokedAt).not.toBeNull();
    expect(tokenRows[1].tokenHash).toBe(hashBookingToken(newToken));
  });

  it('supports idempotent revoke and close transitions', async () => {
    const revoked = await createInline();
    const firstRevoke = await request(app.getHttpServer())
      .post(`/v1/admin/booking-requests/${revoked.response.request.id}/revoke`)
      .set('Cookie', cookies)
      .expect(201);
    const secondRevoke = await request(app.getHttpServer())
      .post(`/v1/admin/booking-requests/${revoked.response.request.id}/revoke`)
      .set('Cookie', cookies)
      .expect(201);
    const firstRevokeBody = firstRevoke.body as LifecycleResponse;
    const secondRevokeBody = secondRevoke.body as LifecycleResponse;
    expect(firstRevokeBody.request?.status ?? firstRevokeBody.status).toBe(
      'cancelled',
    );
    expect(secondRevokeBody.request?.status ?? secondRevokeBody.status).toBe(
      'cancelled',
    );

    const revokedPublic = (await request(app.getHttpServer()).get(
      `/v1/public/reservations/${revoked.token}`,
    )) as unknown as HttpResponse;
    expect(revokedPublic.status).toBe(410);
    expect(errorCode(revokedPublic)).toBe('TOKEN_REVOKED');

    const closed = await createInline();
    const firstClose = await request(app.getHttpServer())
      .post(`/v1/admin/booking-requests/${closed.response.request.id}/close`)
      .set('Cookie', cookies)
      .expect(201);
    const secondClose = await request(app.getHttpServer())
      .post(`/v1/admin/booking-requests/${closed.response.request.id}/close`)
      .set('Cookie', cookies)
      .expect(201);
    const firstCloseBody = firstClose.body as LifecycleResponse;
    const secondCloseBody = secondClose.body as LifecycleResponse;
    expect(firstCloseBody.request?.status ?? firstCloseBody.status).toBe(
      'closed',
    );
    expect(secondCloseBody.request?.status ?? secondCloseBody.status).toBe(
      'closed',
    );
  });

  it('returns a safe booked projection and rejects booked lifecycle conflicts', async () => {
    const booked = await createInline();
    await prisma.bookingRequest.update({
      where: { id: booked.response.request.id },
      data: { status: BookingRequestStatus.BOOKED },
    });

    const publicResponse = await request(app.getHttpServer())
      .get(`/v1/public/reservations/${booked.token}`)
      .expect(200);
    const body = publicResponse.body as PublicResponse;
    expect(body.status).toBe('booked');
    expect(JSON.stringify(body)).not.toContain(booked.response.request.id);
    expect(JSON.stringify(body)).not.toContain(booked.token);
    expect(JSON.stringify(body)).not.toContain(hashBookingToken(booked.token));

    for (const action of ['renew', 'revoke', 'close']) {
      const result = (await request(app.getHttpServer())
        .post(
          `/v1/admin/booking-requests/${booked.response.request.id}/${action}`,
        )
        .set('Cookie', cookies)
        .send(action === 'renew' ? {} : undefined)) as unknown as HttpResponse;
      expect(result.status).toBe(409);
      expect(errorCode(result)).toBe('ALREADY_BOOKED');
    }
  });

  it('returns the specified public token states and requires StudioSettings', async () => {
    const pending = await createInline();
    const pendingPublic = await request(app.getHttpServer())
      .get(`/v1/public/reservations/${pending.token}`)
      .expect(200);
    const publicBody = pendingPublic.body as PublicResponse;
    expect(publicBody).toMatchObject({
      status: 'pending',
      artist: { displayName: 'Requests Test Artist' },
      durationMinutes: 180,
      timezone: 'America/Guayaquil',
    });
    expect(publicBody.restrictions).toEqual({
      minDate: '2026-10-20',
      maxDate: '2026-11-30',
      allowedWeekdays: [1, 3, 5],
      allowedWindows: [{ startLocal: '10:00', endLocal: '18:00' }],
    });
    expect(JSON.stringify(publicBody)).not.toContain(
      pending.response.request.id,
    );
    expect(JSON.stringify(publicBody)).not.toContain(pending.token);
    expect(JSON.stringify(publicBody)).not.toContain(
      hashBookingToken(pending.token),
    );
    expect(JSON.stringify(publicBody)).not.toContain('inline@example.test');
    expect(JSON.stringify(publicBody)).not.toContain('deposit');

    const unknown = (await request(app.getHttpServer()).get(
      '/v1/public/reservations/not-a-real-token',
    )) as unknown as HttpResponse;
    expect(unknown.status).toBe(404);
    expect(errorCode(unknown)).toBe('TOKEN_NOT_FOUND');

    const expired = await createInline();
    await prisma.bookingToken.updateMany({
      where: { requestId: expired.response.request.id },
      data: { expiresAt: new Date('2000-01-01T00:00:00.000Z') },
    });
    const expiredPublic = (await request(app.getHttpServer()).get(
      `/v1/public/reservations/${expired.token}`,
    )) as unknown as HttpResponse;
    expect(expiredPublic.status).toBe(410);
    expect(errorCode(expiredPublic)).toBe('TOKEN_EXPIRED');
    expect(
      (
        await prisma.bookingRequest.findUniqueOrThrow({
          where: { id: expired.response.request.id },
        })
      ).status,
    ).toBe(BookingRequestStatus.EXPIRED);

    const withoutSettings = await createInline(otherCookies);
    const missingSettings = (await request(app.getHttpServer()).get(
      `/v1/public/reservations/${withoutSettings.token}`,
    )) as unknown as HttpResponse;
    expect(missingSettings.status).toBe(503);
    expect(errorCode(missingSettings)).toBe('SERVICE_UNAVAILABLE');
  });
});
