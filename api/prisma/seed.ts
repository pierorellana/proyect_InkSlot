import * as argon2 from 'argon2';
import { BookingRequestStatus, Prisma, PrismaClient } from '@prisma/client';

import { hashBookingToken } from '../src/requests/booking-token';

const prisma = new PrismaClient();

const DEMO_TOKEN = 'demo-token';
const DEMO_ARTIST_EMAIL =
  process.env.DEMO_ARTIST_EMAIL?.trim().toLowerCase() ||
  'demo@inkslot.local';
const DEMO_LOGIN_USERNAME =
  process.env.DEMO_LOGIN_USERNAME?.trim().toLowerCase() || 'dodo';
const DEMO_PASSWORD = process.env.DEMO_PASSWORD || '1234';
const DEMO_PAYMENT_REFERENCE = 'demo-local-seed';
const DEMO_ARTIST_NAME = 'Dodogio';
const DEMO_CLIENT_EMAIL = 'cliente-demo@inkslot.local';
const DEMO_CLIENT_NAME = 'Cliente Demo';
const DEMO_EXPIRES_AT = new Date('2099-12-31T23:59:59.000Z');
const DEMO_ALLOWED_WEEKDAYS = [1, 2, 3, 4, 5, 6];

const clock = (hour: number, minute: number): Date =>
  new Date(Date.UTC(1970, 0, 1, hour, minute));

async function resetDemoAppointment(
  transaction: Prisma.TransactionClient,
  requestId: string,
): Promise<void> {
  const appointment = await transaction.appointment.findUnique({
    where: { requestId },
    select: { id: true },
  });

  if (!appointment) return;

  await transaction.outboxEvent.deleteMany({
    where: { aggregateId: appointment.id },
  });
  await transaction.auditLog.deleteMany({
    where: { entityId: appointment.id },
  });
  await transaction.appointment.delete({
    where: { id: appointment.id },
  });
}

async function seed(): Promise<void> {
  const demoPasswordHash = await argon2.hash(DEMO_PASSWORD, {
    type: argon2.argon2id,
  });
  const now = new Date();
  const tokenHash = hashBookingToken(DEMO_TOKEN);

  const result = await prisma.$transaction(async (transaction) => {
    const artist = await transaction.artist.upsert({
      where: { email: DEMO_ARTIST_EMAIL },
      create: {
        email: DEMO_ARTIST_EMAIL,
        passwordHash: demoPasswordHash,
        displayName: DEMO_ARTIST_NAME,
        active: true,
      },
      update: {
        passwordHash: demoPasswordHash,
        displayName: DEMO_ARTIST_NAME,
        active: true,
      },
    });

    await transaction.studioSettings.upsert({
      where: { artistId: artist.id },
      create: {
        artistId: artist.id,
        timezone: 'America/Guayaquil',
        slotStepMinutes: 30,
        bufferMinutes: 0,
        minimumNoticeHours: 0,
        horizonDays: 60,
      },
      update: {
        timezone: 'America/Guayaquil',
        slotStepMinutes: 30,
        bufferMinutes: 0,
        minimumNoticeHours: 0,
        horizonDays: 60,
      },
    });

    await transaction.weeklyAvailability.deleteMany({
      where: { artistId: artist.id },
    });
    await transaction.weeklyAvailability.createMany({
      data: DEMO_ALLOWED_WEEKDAYS.map((weekday) => ({
        artistId: artist.id,
        weekday: Number(weekday),
        startLocal: clock(10, 0),
        endLocal: clock(18, 0),
      })),
    });
    await transaction.availabilityBlock.deleteMany({
      where: { artistId: artist.id },
    });

    const existingClient = await transaction.client.findFirst({
      where: {
        artistId: artist.id,
        email: DEMO_CLIENT_EMAIL,
      },
      orderBy: { createdAt: 'asc' },
    });
    const client = existingClient
      ? await transaction.client.update({
          where: { id: existingClient.id },
          data: {
            name: DEMO_CLIENT_NAME,
            phone: null,
            contactChannel: 'email',
            contactValue: DEMO_CLIENT_EMAIL,
          },
        })
      : await transaction.client.create({
          data: {
            artistId: artist.id,
            name: DEMO_CLIENT_NAME,
            email: DEMO_CLIENT_EMAIL,
            contactChannel: 'email',
            contactValue: DEMO_CLIENT_EMAIL,
          },
        });

    const existingRequest = await transaction.bookingRequest.findFirst({
      where: {
        artistId: artist.id,
        clientId: client.id,
        paymentReference: DEMO_PAYMENT_REFERENCE,
      },
      orderBy: { createdAt: 'asc' },
    });

    if (existingRequest) {
      await resetDemoAppointment(transaction, existingRequest.id);
    }

    const request = existingRequest
      ? await transaction.bookingRequest.update({
          where: { id: existingRequest.id },
          data: {
            paymentReference: DEMO_PAYMENT_REFERENCE,
            depositVerifiedAt: now,
            depositVerifiedBy: artist.id,
            durationMinutes: 60,
            status: BookingRequestStatus.PENDING,
            minDate: null,
            maxDate: null,
            allowedWeekdays: DEMO_ALLOWED_WEEKDAYS,
            allowedWindows: Prisma.JsonNull,
            version: 1,
          },
        })
      : await transaction.bookingRequest.create({
          data: {
            artistId: artist.id,
            clientId: client.id,
            paymentReference: DEMO_PAYMENT_REFERENCE,
            depositVerifiedAt: now,
            depositVerifiedBy: artist.id,
            durationMinutes: 60,
            status: BookingRequestStatus.PENDING,
            allowedWeekdays: DEMO_ALLOWED_WEEKDAYS,
          },
        });

    await transaction.bookingToken.deleteMany({
      where: {
        OR: [{ requestId: request.id }, { tokenHash }],
      },
    });
    await transaction.bookingToken.create({
      data: {
        requestId: request.id,
        tokenHash,
        expiresAt: DEMO_EXPIRES_AT,
        revokedAt: null,
        consumedAt: null,
        createdAt: now,
      },
    });

    return {
      artistId: artist.id,
      clientId: client.id,
      requestId: request.id,
    };
  });

  console.log(
    JSON.stringify({
      seeded: true,
      token: DEMO_TOKEN,
      artistEmail: DEMO_ARTIST_EMAIL,
      loginUsername: DEMO_LOGIN_USERNAME,
      ...result,
    }),
  );
}

seed()
  .catch((error: unknown) => {
    console.error('Local demo seed failed', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
