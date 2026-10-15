import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import * as argon2 from 'argon2';
import request from 'supertest';

import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/database/prisma.service';

type AuthResponse = {
  user: { id: string; name: string; role: 'admin' };
};

type AuthErrorResponse = {
  error: { code: string; message: string };
};

describe('admin authentication', () => {
  let app: INestApplication;
  let prisma: PrismaService;
  let artistId: string;
  const email = `auth-${Date.now()}@example.test`;
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
        displayName: 'Auth Test Artist',
      },
    });
    artistId = artist.id;
  });

  afterAll(async () => {
    await prisma.adminSession.deleteMany({ where: { artistId } });
    await prisma.artist.delete({ where: { id: artistId } });
    await app.close();
  });

  it('logs in with Argon2id and returns an HttpOnly session cookie', async () => {
    const response = await request(app.getHttpServer())
      .post('/v1/auth/login')
      .send({ email, password })
      .expect(200);
    const responseBody = response.body as AuthResponse;

    expect(responseBody).toEqual({
      user: { id: artistId, name: 'Auth Test Artist', role: 'admin' },
    });
    expect(responseBody.user).not.toHaveProperty('passwordHash');
    expect(response.headers['set-cookie']).toEqual(
      expect.arrayContaining([
        expect.stringMatching(
          /^inkslot_session=[^;]+; Max-Age=604800; Path=\/; Expires=[^;]+; HttpOnly; SameSite=Lax$/,
        ),
      ]),
    );
  });

  it('returns the same generic error for unknown and incorrect credentials', async () => {
    const incorrect = await request(app.getHttpServer())
      .post('/v1/auth/login')
      .send({ email, password: 'wrong-password' })
      .expect(401);
    const unknown = await request(app.getHttpServer())
      .post('/v1/auth/login')
      .send({ email: 'missing@example.test', password })
      .expect(401);
    const incorrectBody = incorrect.body as AuthErrorResponse;
    const unknownBody = unknown.body as AuthErrorResponse;

    expect(incorrectBody.error).toEqual({
      code: 'AUTH_INVALID',
      message: 'Credenciales inválidas',
    });
    expect(unknownBody.error).toEqual(incorrectBody.error);

    await prisma.artist.update({
      where: { id: artistId },
      data: { active: false },
    });
    const inactive = await request(app.getHttpServer())
      .post('/v1/auth/login')
      .send({ email, password })
      .expect(401);
    const inactiveBody = inactive.body as AuthErrorResponse;
    await prisma.artist.update({
      where: { id: artistId },
      data: { active: true },
    });

    expect(inactiveBody.error).toEqual(incorrectBody.error);
  });

  it('authenticates me, revokes logout, and rejects an expired session', async () => {
    const login = await request(app.getHttpServer())
      .post('/v1/auth/login')
      .send({ email, password })
      .expect(200);
    const cookies = login.headers['set-cookie'] as string[];

    await request(app.getHttpServer())
      .get('/v1/auth/me')
      .set('Cookie', cookies)
      .expect(200)
      .expect({
        user: { id: artistId, name: 'Auth Test Artist', role: 'admin' },
      });

    await request(app.getHttpServer())
      .post('/v1/auth/logout')
      .set('Cookie', cookies)
      .expect(204);

    await request(app.getHttpServer())
      .get('/v1/auth/me')
      .set('Cookie', cookies)
      .expect(401);

    const expiredLogin = await request(app.getHttpServer())
      .post('/v1/auth/login')
      .send({ email, password })
      .expect(200);
    const expiredCookies = expiredLogin.headers['set-cookie'] as string[];
    const session = await prisma.adminSession.findFirstOrThrow({
      where: { artistId, revokedAt: null },
      orderBy: { createdAt: 'desc' },
    });
    await prisma.adminSession.update({
      where: { id: session.id },
      data: { expiresAt: new Date('2000-01-01T00:00:00Z') },
    });

    await request(app.getHttpServer())
      .get('/v1/auth/me')
      .set('Cookie', expiredCookies)
      .expect(401);
  });
});
