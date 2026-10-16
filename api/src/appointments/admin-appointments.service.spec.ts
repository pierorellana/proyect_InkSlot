import {
  BadRequestException,
  HttpException,
  ValidationPipe,
} from '@nestjs/common';
import { AppointmentStatus, SyncStatus } from '@prisma/client';

import { AppointmentAvailabilityService } from '../availability/appointment-availability.service';
import { PrismaService } from '../database/prisma.service';
import {
  AppointmentActionDto,
  ListAdminAppointmentsDto,
  RescheduleAdminAppointmentDto,
} from './admin-appointments.dto';
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
  const transaction = {
    $queryRaw: jest.fn(),
    appointment: {
      findFirst: jest.fn(),
      update: jest.fn(),
    },
    auditLog: {
      create: jest.fn(),
    },
    outboxEvent: {
      create: jest.fn(),
    },
  };
  const prisma = {
    appointment: {
      findMany: jest.fn(),
      findFirst: jest.fn(),
    },
    auditLog: {
      findMany: jest.fn(),
    },
    $transaction: jest.fn(),
  };
  const availability = {
    assertAvailable: jest.fn(),
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
    transaction.$queryRaw.mockResolvedValue([]);
    transaction.appointment.findFirst.mockResolvedValue({
      id: appointmentId,
      status: AppointmentStatus.CONFIRMED,
      version: 1,
      startAt,
      endAt,
    });
    transaction.appointment.update.mockResolvedValue({});
    transaction.auditLog.create.mockResolvedValue({});
    transaction.outboxEvent.create.mockResolvedValue({});
    prisma.$transaction.mockImplementation((operation) => operation(transaction));
    availability.assertAvailable.mockResolvedValue({
      startAt: new Date('2026-11-05T15:00:00.000Z'),
      endAt: new Date('2026-11-05T16:30:00.000Z'),
      timezone: 'America/Guayaquil',
    });
    service = new AdminAppointmentsService(
      prisma as unknown as PrismaService,
      availability as unknown as AppointmentAvailabilityService,
    );
  });

  afterEach(() => {
    jest.restoreAllMocks();
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

  it('reschedules with derived endAt, preflight, audit and update outbox', async () => {
    const nextStart = new Date('2026-11-05T15:00:00.000Z');
    const candidate = {
      id: appointmentId,
      artistId,
      startAt,
      endAt,
      status: AppointmentStatus.CONFIRMED,
      version: 1,
      request: {
        durationMinutes: 90,
        minDate: null,
        maxDate: null,
        allowedWeekdays: null,
        allowedWindows: null,
      },
    };
    prisma.appointment.findFirst
      .mockResolvedValueOnce(candidate)
      .mockResolvedValueOnce(detailRow());

    await service.reschedule(artistId, appointmentId, {
      startAt: nextStart.toISOString(),
      version: 1,
    });

    expect(availability.assertAvailable).toHaveBeenCalledWith({
      artistId,
      appointmentId,
      startAt: nextStart,
      durationMinutes: 90,
      request: {
        minDate: null,
        maxDate: null,
        allowedWeekdays: null,
        allowedWindows: null,
      },
    });
    expect(transaction.appointment.update).toHaveBeenCalledWith({
      where: { id: appointmentId },
      data: {
        startAt: nextStart,
        endAt: new Date('2026-11-05T16:30:00.000Z'),
        version: { increment: 1 },
        syncStatus: SyncStatus.PENDING,
      },
    });
    expect(transaction.auditLog.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        actorType: 'ADMIN',
        actorId: artistId,
        entityType: 'appointment',
        entityId: appointmentId,
        action: 'rescheduled',
        changes: {
          from: {
            startAt: startAt.toISOString(),
            endAt: endAt.toISOString(),
          },
          to: {
            startAt: nextStart.toISOString(),
            endAt: '2026-11-05T16:30:00.000Z',
          },
        },
      }),
    });
    expect(transaction.outboxEvent.create).toHaveBeenCalledWith({
      data: {
        aggregateId: appointmentId,
        type: 'appointment.calendar.update',
        payload: { appointmentId, operation: 'update' },
      },
    });
    expect(prisma.$transaction).toHaveBeenCalledWith(expect.any(Function), {
      isolationLevel: 'Serializable',
    });
  });

  it('treats an identical reschedule as a no-op without preflight or writes', async () => {
    const candidate = {
      id: appointmentId,
      artistId,
      startAt,
      endAt,
      status: AppointmentStatus.CONFIRMED,
      version: 1,
      request: {
        durationMinutes: 90,
        minDate: null,
        maxDate: null,
        allowedWeekdays: null,
        allowedWindows: null,
      },
    };
    prisma.appointment.findFirst.mockResolvedValueOnce(candidate);

    await service.reschedule(artistId, appointmentId, {
      startAt: startAt.toISOString(),
      version: 99,
    });

    expect(availability.assertAvailable).not.toHaveBeenCalled();
    expect(prisma.$transaction).not.toHaveBeenCalled();
    expect(transaction.appointment.update).not.toHaveBeenCalled();
    expect(transaction.auditLog.create).not.toHaveBeenCalled();
    expect(transaction.outboxEvent.create).not.toHaveBeenCalled();
  });

  it('cancels with pending sync and delete outbox even without a local Calendar event', async () => {
    await service.cancel(artistId, appointmentId, { version: 1 });

    expect(transaction.appointment.update).toHaveBeenCalledWith({
      where: { id: appointmentId },
      data: {
        status: AppointmentStatus.CANCELLED,
        version: { increment: 1 },
        syncStatus: SyncStatus.PENDING,
      },
    });
    expect(transaction.auditLog.create).toHaveBeenCalledWith({
      data: expect.objectContaining({ action: 'cancelled' }),
    });
    expect(transaction.outboxEvent.create).toHaveBeenCalledWith({
      data: {
        aggregateId: appointmentId,
        type: 'appointment.calendar.delete',
        payload: { appointmentId, operation: 'delete' },
      },
    });
  });

  it.each([
    [AppointmentStatus.COMPLETED, 'complete'],
    [AppointmentStatus.NO_SHOW, 'noShow'],
  ] as const)('transitions to %s without a Calendar outbox', async (target, method) => {
    await service[method](artistId, appointmentId, { version: 1 });

    expect(transaction.appointment.update).toHaveBeenCalledWith({
      where: { id: appointmentId },
      data: {
        status: target,
        version: { increment: 1 },
      },
    });
    expect(transaction.auditLog.create).toHaveBeenCalledWith({
      data: expect.objectContaining({ action: target.toLowerCase() }),
    });
    expect(transaction.outboxEvent.create).not.toHaveBeenCalled();
  });

  it('makes repeated target actions idempotent without audit or outbox duplication', async () => {
    transaction.appointment.findFirst.mockResolvedValue({
      id: appointmentId,
      status: AppointmentStatus.CANCELLED,
      version: 3,
    });

    await service.cancel(artistId, appointmentId, { version: 1 });

    expect(transaction.appointment.update).not.toHaveBeenCalled();
    expect(transaction.auditLog.create).not.toHaveBeenCalled();
    expect(transaction.outboxEvent.create).not.toHaveBeenCalled();
  });

  it('rejects stale versions and invalid state transitions safely', async () => {
    transaction.appointment.findFirst.mockResolvedValue({
      id: appointmentId,
      status: AppointmentStatus.CONFIRMED,
      version: 2,
    });
    await expectCode(
      service.complete(artistId, appointmentId, { version: 1 }),
      'APPOINTMENT_VERSION_CONFLICT',
      409,
    );
    expect(transaction.appointment.update).not.toHaveBeenCalled();

    transaction.appointment.findFirst.mockResolvedValue({
      id: appointmentId,
      status: AppointmentStatus.COMPLETED,
      version: 2,
    });
    await expectCode(
      service.cancel(artistId, appointmentId, { version: 2 }),
      'APPOINTMENT_STATE_CONFLICT',
      409,
    );
  });

  it.each(['P2034', '40001', '40P01'] as const)(
    'retries Serializable transaction conflicts (%s)',
    async (code) => {
      prisma.$transaction
        .mockRejectedValueOnce({ code })
        .mockImplementationOnce((operation) => operation(transaction));

      await service.complete(artistId, appointmentId, { version: 1 });

      expect(prisma.$transaction).toHaveBeenCalledTimes(2);
      expect(transaction.appointment.update).toHaveBeenCalledTimes(1);
    },
  );

  it('maps PostgreSQL exclusion conflicts to SLOT_UNAVAILABLE', async () => {
    prisma.$transaction.mockRejectedValue({ code: '23P01' });

    await expectCode(
      service.complete(artistId, appointmentId, { version: 1 }),
      'SLOT_UNAVAILABLE',
      409,
    );
    expect(transaction.appointment.update).not.toHaveBeenCalled();
  });

  it('does not mutate an appointment owned by another artist', async () => {
    transaction.appointment.findFirst.mockResolvedValue(null);

    await expectCode(
      service.cancel('99999999-9999-4999-8999-999999999999', appointmentId, {
        version: 1,
      }),
      'NOT_FOUND',
      404,
    );
    expect(transaction.appointment.update).not.toHaveBeenCalled();
  });

  it('validates action DTOs and UTC reschedule input strictly', async () => {
    const pipe = new ValidationPipe({
      transform: true,
      whitelist: true,
      forbidNonWhitelisted: true,
    });

    await expect(
      pipe.transform(
        { startAt: '2026-11-05T15:00:00Z', version: 1 },
        { type: 'body', metatype: RescheduleAdminAppointmentDto },
      ),
    ).rejects.toBeInstanceOf(BadRequestException);
    await expect(
      pipe.transform(
        { version: 0, extra: true },
        { type: 'body', metatype: AppointmentActionDto },
      ),
    ).rejects.toBeInstanceOf(BadRequestException);
  });
});
