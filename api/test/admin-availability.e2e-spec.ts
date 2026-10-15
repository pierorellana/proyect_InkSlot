import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import * as argon2 from 'argon2';
import request from 'supertest';

import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/database/prisma.service';

type AvailabilityResponse = {
  timezone: string;
  slotStepMinutes: number;
  bufferMinutes: number;
  minimumNoticeHours: number;
  horizonDays: number;
  weeklyWindows: Array<{
    weekday: number;
    startLocal: string;
    endLocal: string;
  }>;
};

describe('admin availability configuration', () => {
  let app: INestApplication;
  let prisma: PrismaService;
  let artistId: string;
  let cookies: string[];
  const email = `availability-${Date.now()}@example.test`;
  const password = 'local-test-password';

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
    const artist = await prisma.artist.create({
      data: {
        email,
        passwordHash: await argon2.hash(password, { type: argon2.argon2id }),
        displayName: 'Availability Test Artist',
      },
    });
    artistId = artist.id;

    const login = await request(app.getHttpServer())
      .post('/v1/auth/login')
      .send({ email, password })
      .expect(200);
    cookies = login.headers['set-cookie'] as string[];
  });

  afterAll(async () => {
    await prisma.artist.delete({ where: { id: artistId } });
    await app.close();
  });

  it('rejects access without an administrative session', async () => {
    await request(app.getHttpServer())
      .get('/v1/admin/availability')
      .expect(401);
  });

  it('round-trips settings and weekly windows for the authenticated artist', async () => {
    const payload = {
      timezone: 'America/Guayaquil',
      slotStepMinutes: 30,
      bufferMinutes: 15,
      minimumNoticeHours: 24,
      horizonDays: 60,
      weeklyWindows: [
        { weekday: 2, startLocal: '10:00', endLocal: '13:30' },
        { weekday: 2, startLocal: '14:30', endLocal: '20:00' },
        { weekday: 6, startLocal: '11:00', endLocal: '16:00' },
      ],
    };

    const update = await request(app.getHttpServer())
      .put('/v1/admin/availability')
      .set('Cookie', cookies)
      .send(payload)
      .expect(200);
    const updateBody = update.body as AvailabilityResponse;

    expect(updateBody).toEqual(payload);

    const read = await request(app.getHttpServer())
      .get('/v1/admin/availability')
      .set('Cookie', cookies)
      .expect(200);
    const readBody = read.body as AvailabilityResponse;

    expect(readBody).toEqual(payload);
    expect(await prisma.weeklyAvailability.count({ where: { artistId } })).toBe(
      3,
    );
  });

  it('rejects invalid windows and scheduling parameters', async () => {
    await request(app.getHttpServer())
      .put('/v1/admin/availability')
      .set('Cookie', cookies)
      .send({
        timezone: 'America/Guayaquil',
        slotStepMinutes: 0,
        bufferMinutes: 15,
        minimumNoticeHours: 24,
        horizonDays: 60,
        weeklyWindows: [{ weekday: 7, startLocal: '14:30', endLocal: '10:00' }],
      })
      .expect(400);
  });
});
