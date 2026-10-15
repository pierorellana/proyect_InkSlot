import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import {
  CalendarConnectionStatus,
  PrismaClient,
} from '@prisma/client';

import { PrismaModule } from '../src/database/prisma.module';
import { PrismaService } from '../src/database/prisma.service';

describe('calendar persistence', () => {
  let app: INestApplication;
  let prisma: PrismaClient;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [PrismaModule],
    }).compile();

    app = moduleRef.createNestApplication();
    await app.init();
    prisma = app.get(PrismaService);
  });

  afterAll(async () => app.close());

  it('persists calendar connection metadata and one-time oauth state', async () => {
    const artist = await prisma.artist.create({
      data: {
        email: `calendar-persistence-${Date.now()}@example.test`,
        displayName: 'Calendar Persistence Artist',
        passwordHash: 'argon2id-placeholder',
      },
    });

    let stateId = '';

    try {
      const state = await prisma.calendarOAuthState.create({
        data: {
          artistId: artist.id,
          stateHash: `hash-${'a'.repeat(60)}`,
          expiresAt: new Date(Date.now() + 600_000),
        },
      });
      stateId = state.id;

      const connection = await prisma.calendarConnection.create({
        data: {
          artistId: artist.id,
          calendarId: 'inkslot-calendar-id',
          calendarName: 'InkSlot',
          encryptedRefreshToken: 'v1:iv:tag:ciphertext',
          status: CalendarConnectionStatus.CONNECTED,
          connectedAt: new Date(),
        },
      });

      const consumed = await prisma.calendarOAuthState.update({
        where: { id: state.id },
        data: { consumedAt: new Date() },
      });

      expect(connection).toMatchObject({
        calendarId: 'inkslot-calendar-id',
        calendarName: 'InkSlot',
        status: CalendarConnectionStatus.CONNECTED,
      });
      expect(consumed.consumedAt).toBeInstanceOf(Date);
    } finally {
      await prisma.artist.delete({ where: { id: artist.id } });
    }

    expect(
      await prisma.calendarOAuthState.findUnique({ where: { id: stateId } }),
    ).toBeNull();
  });
});
