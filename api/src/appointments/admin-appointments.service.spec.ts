import {
  BadRequestException,
  HttpException,
  ValidationPipe,
} from '@nestjs/common';
import { AppointmentStatus, SyncStatus } from '@prisma/client';

import { PrismaService } from '../database/prisma.service';
import { ListAdminAppointmentsDto } from './admin-appointments.dto';
import {
  decodeAppointmentCursor,
  encodeAppointmentCursor,
} from './appointment-cursor';
import { AdminAppointmentsService } from './admin-appointments.service';

describe('AdminAppointmentsService queries', () => {
  const artistId = '11111111-1111-4111-8111-111111111111';
  const otherArtistId = '99999999-9999-4999-8999-999999999999';
  const appointmentId = '22222222-2222-4222-8222-222222222222';
  const startAt = new Date('2026-11-03T15:00:00.000Z');
  const endAt = new Date('2026-11-03T16:30:00.000Z');
  const client = {
    name: 'Cliente',
    email: 'client@example.test',
    phone: '+593000000000',
    contactChannel: 'whatsapp',
    contactValue: '+593000000000',
  };
  const listRow = () => ({
    id: appointmentId,
    status: AppointmentStatus.CONFIRMED,
    syncStatus: SyncStatus.PENDING,
    startAt,
    endAt,
    version: 1,
    request: { durationMinutes: 90, client: { name: client.name } },
  });
  const detailRow = () => ({
    ...listRow(),
    request: { durationMinutes: 90, client },
    calendarEvent: {
      id: '33333333-3333-4333-8333-333333333333',
      calendarId: 'primary',
      externalEventId: 'inkslot-appointment-222',
      etag: 'etag-1',
      lastSyncedAt: new Date('2026-11-01T10:00:00.000Z'),
    },
  });
  const prisma = {
    appointment: {
      findMany: jest.fn(),
      findFirst: jest.fn(),
    },
    auditLog: {
      findMany: jest.fn(),
    },
  };
  let service: AdminAppointmentsService;

  beforeEach(() => {
    jest.resetAllMocks();
    prisma.appointment.findMany.mockResolvedValue([listRow()]);
    prisma.appointment.findFirst.mockResolvedValue(detailRow());
    prisma.auditLog.findMany.mockResolvedValue([
      {
        action: 'rescheduled',
        createdAt: new Date('2026-11-01T09:00:00.000Z'),
        changes: {
          from: { startAt: '2026-11-02T15:00:00.000Z' },
          to: { startAt: startAt.toISOString() },
          private: 'must not be exposed',
        },
      },
    ]);
    service = new AdminAppointmentsService(
      prisma as unknown as PrismaService,
    );
  });

  async function expectCode(
    operation: Promise<unknown>,
    code: string,
    status: number,
  ): Promise<void> {
    const error: unknown = await operation.catch((failure: unknown) => failure);
    expect(error).toBeInstanceOf(HttpException);
    if (!(error instanceof HttpException)) throw new Error('Expected HTTP error');
    expect(error.getStatus()).toBe(status);
    expect(error.getResponse()).toEqual(
      expect.objectContaining({
        error: expect.objectContaining({ code }),
      }),
    );
  }

  it('lists appointments scoped to the artist with the safe projection and order', async () => {
    const result = await service.list(artistId, {});

    expect(prisma.appointment.findMany).toHaveBeenCalledWith({
      where: { artistId },
      orderBy: [{ startAt: 'asc' }, { id: 'asc' }],
      take: 21,
      select: expect.any(Object),
    });
    expect(result).toEqual({
      items: [
        {
          id: appointmentId,
          status: 'confirmed',
          syncStatus: 'pending',
          startAt: startAt.toISOString(),
          endAt: endAt.toISOString(),
          version: 1,
          client: { name: 'Cliente' },
          durationMinutes: 90,
        },
      ],
      nextCursor: null,
    });
    expect(JSON.stringify(result)).not.toContain('example.test');
  });

  it('applies status filters and a forward startAt/id cursor', async () => {
    const cursor = encodeAppointmentCursor({ startAt, id: appointmentId });

    await service.list(artistId, { status: 'completed', cursor });

    expect(prisma.appointment.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          artistId,
          status: AppointmentStatus.COMPLETED,
          OR: [
            { startAt: { gt: startAt } },
            { startAt, id: { gt: appointmentId } },
          ],
        },
      }),
    );
  });

  it('returns a cursor only when there is a twenty-first row', async () => {
    const rows = Array.from({ length: 21 }, (_, index) => ({
      ...listRow(),
      id: `22222222-2222-4222-8222-${String(index).padStart(12, '0')}`,
      startAt: new Date(startAt.getTime() + index * 60_000),
    }));
    prisma.appointment.findMany.mockResolvedValue(rows);

    const result = await service.list(artistId, {});

    expect(result.items).toHaveLength(20);
    expect(result.nextCursor).not.toBeNull();
    expect(decodeAppointmentCursor(result.nextCursor!)).toEqual({
      startAt: rows[19].startAt,
      id: rows[19].id,
    });
  });

  it('returns an owned detail with contact, active Calendar projection and sanitized audit', async () => {
    const result = await service.detail(artistId, appointmentId);

    expect(prisma.appointment.findFirst).toHaveBeenCalledWith(
      expect.objectContaining({ where: { id: appointmentId, artistId } }),
    );
    expect(prisma.auditLog.findMany).toHaveBeenCalledWith({
      where: {
        entityType: 'appointment',
        entityId: appointmentId,
        actorType: 'ADMIN',
        actorId: artistId,
      },
      orderBy: { createdAt: 'asc' },
      select: { action: true, createdAt: true, changes: true },
    });
    expect(result).toEqual({
      id: appointmentId,
      status: 'confirmed',
      syncStatus: 'pending',
      startAt: startAt.toISOString(),
      endAt: endAt.toISOString(),
      version: 1,
      client,
      durationMinutes: 90,
      calendarEvent: {
        id: '33333333-3333-4333-8333-333333333333',
        calendarId: 'primary',
        externalEventId: 'inkslot-appointment-222',
        etag: 'etag-1',
        lastSyncedAt: '2026-11-01T10:00:00.000Z',
      },
      audit: [
        {
          action: 'rescheduled',
          createdAt: '2026-11-01T09:00:00.000Z',
          changes: {
            from: { startAt: '2026-11-02T15:00:00.000Z' },
            to: { startAt: startAt.toISOString() },
          },
        },
      ],
    });
  });

  it('maps missing or cross-artist appointments to safe 404', async () => {
    prisma.appointment.findFirst.mockResolvedValue(null);

    await expectCode(
      service.detail(otherArtistId, appointmentId),
      'NOT_FOUND',
      404,
    );
    await expectCode(
      service.detail(artistId, 'not-an-id'),
      'NOT_FOUND',
      404,
    );
  });

  it('rejects invalid cursors and hides database failures', async () => {
    await expectCode(
      service.list(artistId, { cursor: 'not-a-cursor' }),
      'BAD_REQUEST',
      400,
    );

    prisma.appointment.findMany.mockRejectedValue(
      new Error('private database detail'),
    );
    await expectCode(service.list(artistId, {}), 'SERVICE_UNAVAILABLE', 503);
  });

  it('validates query DTOs through the strict global-pipe contract', async () => {
    const pipe = new ValidationPipe({
      transform: true,
      whitelist: true,
      forbidNonWhitelisted: true,
    });

    await expect(
      pipe.transform(
        { status: 'confirmed', cursor: 'opaque', unexpected: true },
        { type: 'query', metatype: ListAdminAppointmentsDto },
      ),
    ).rejects.toBeInstanceOf(BadRequestException);
    await expect(
      pipe.transform(
        { status: 'not-valid' },
        { type: 'query', metatype: ListAdminAppointmentsDto },
      ),
    ).rejects.toBeInstanceOf(BadRequestException);
  });
});
