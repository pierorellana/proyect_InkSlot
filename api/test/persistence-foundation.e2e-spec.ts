import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import {
  AppointmentStatus,
  BookingRequestStatus,
  PrismaClient,
  SyncStatus,
} from '@prisma/client';

import { PrismaModule } from '../src/database/prisma.module';
import { PrismaService } from '../src/database/prisma.service';

describe('persistence foundation', () => {
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

  it('persists the agenda and public-request foundation with UTC fields', async () => {
    const email = `persistence-${Date.now()}@example.test`;
    const artist = await prisma.artist.create({
      data: {
        email,
        displayName: 'InkSlot Test Artist',
        passwordHash: 'argon2id-placeholder',
      },
    });

    try {
      const settings = await prisma.studioSettings.create({
        data: {
          artistId: artist.id,
          timezone: 'America/Guayaquil',
          slotStepMinutes: 30,
          bufferMinutes: 15,
          minimumNoticeHours: 24,
          horizonDays: 60,
        },
      });
      const weeklyAvailability = await prisma.weeklyAvailability.create({
        data: {
          artistId: artist.id,
          weekday: 2,
          startLocal: new Date('1970-01-01T10:00:00Z'),
          endLocal: new Date('1970-01-01T20:00:00Z'),
        },
      });
      const client = await prisma.client.create({
        data: { name: 'Cliente de prueba', phone: '+593000000000' },
      });
      const request = await prisma.bookingRequest.create({
        data: {
          artistId: artist.id,
          clientId: client.id,
          depositVerifiedAt: new Date('2026-10-15T15:00:00Z'),
          depositVerifiedBy: artist.id,
          durationMinutes: 180,
          status: BookingRequestStatus.PENDING,
          minDate: new Date('2026-10-20T00:00:00Z'),
          maxDate: new Date('2026-11-30T00:00:00Z'),
          allowedWeekdays: [2, 3, 4, 5, 6],
        },
      });
      const token = await prisma.bookingToken.create({
        data: {
          requestId: request.id,
          tokenHash: `hash-${'a'.repeat(60)}`,
          expiresAt: new Date('2026-10-17T15:00:00Z'),
        },
      });

      expect(settings.timezone).toBe('America/Guayaquil');
      expect(weeklyAvailability.weekday).toBe(2);
      expect(request.status).toBe(BookingRequestStatus.PENDING);
      expect(token.tokenHash).toContain('hash-');
    } finally {
      await prisma.bookingToken.deleteMany({
        where: { request: { artistId: artist.id } },
      });
      await prisma.bookingRequest.deleteMany({
        where: { artistId: artist.id },
      });
      await prisma.client.deleteMany({ where: { name: 'Cliente de prueba' } });
      await prisma.weeklyAvailability.deleteMany({
        where: { artistId: artist.id },
      });
      await prisma.studioSettings.deleteMany({
        where: { artistId: artist.id },
      });
      await prisma.artist.delete({ where: { id: artist.id } });
    }
  });

  it('rejects an overlapping active appointment at the database boundary', async () => {
    const email = `exclusion-${Date.now()}@example.test`;
    const artist = await prisma.artist.create({
      data: {
        email,
        displayName: 'Exclusion Test Artist',
        passwordHash: 'argon2id-placeholder',
      },
    });
    const client = await prisma.client.create({
      data: { name: 'Exclusion Client' },
    });

    try {
      const firstRequest = await prisma.bookingRequest.create({
        data: {
          artistId: artist.id,
          clientId: client.id,
          durationMinutes: 180,
          status: BookingRequestStatus.PENDING,
        },
      });
      const secondRequest = await prisma.bookingRequest.create({
        data: {
          artistId: artist.id,
          clientId: client.id,
          durationMinutes: 180,
          status: BookingRequestStatus.PENDING,
        },
      });
      const startAt = new Date('2026-10-23T15:00:00Z');
      const endAt = new Date('2026-10-23T18:00:00Z');

      await prisma.appointment.create({
        data: {
          requestId: firstRequest.id,
          artistId: artist.id,
          startAt,
          endAt,
          status: AppointmentStatus.CONFIRMED,
          syncStatus: SyncStatus.PENDING,
        },
      });

      await expect(
        prisma.appointment.create({
          data: {
            requestId: secondRequest.id,
            artistId: artist.id,
            startAt,
            endAt,
            status: AppointmentStatus.CONFIRMED,
            syncStatus: SyncStatus.PENDING,
          },
        }),
      ).rejects.toThrow();

      await prisma.appointment.updateMany({
        where: { artistId: artist.id },
        data: { status: AppointmentStatus.CANCELLED },
      });
      await expect(
        prisma.appointment.create({
          data: {
            requestId: secondRequest.id,
            artistId: artist.id,
            startAt,
            endAt,
            status: AppointmentStatus.CONFIRMED,
            syncStatus: SyncStatus.PENDING,
          },
        }),
      ).resolves.toBeDefined();
    } finally {
      await prisma.appointment.deleteMany({ where: { artistId: artist.id } });
      await prisma.bookingRequest.deleteMany({
        where: { artistId: artist.id },
      });
      await prisma.client.delete({ where: { id: client.id } });
      await prisma.artist.delete({ where: { id: artist.id } });
    }
  });
});
