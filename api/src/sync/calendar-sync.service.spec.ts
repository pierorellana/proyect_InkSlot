import { AppointmentStatus, CalendarConnectionStatus } from '@prisma/client';
import { createHash } from 'node:crypto';

import { CalendarProviderError } from '../calendar/calendar.provider';
import { CalendarService } from '../calendar/calendar.service';
import { PrismaService } from '../database/prisma.service';
import {
  CalendarSyncError,
  CalendarSyncService,
} from './calendar-sync.service';
import { OUTBOX_CREATE_EVENT, type ClaimedOutboxEvent } from './sync.constants';

describe('CalendarSyncService', () => {
  const appointmentId = '44444444-4444-4444-8444-444444444444';
  const artistId = '11111111-1111-4111-8111-111111111111';
  const calendarId = 'inkslot-calendar';
  const startAt = new Date('2026-10-23T15:00:00.000Z');
  const endAt = new Date('2026-10-23T17:00:00.000Z');
  const event: ClaimedOutboxEvent = {
    id: '55555555-5555-4555-8555-555555555555',
    aggregateId: appointmentId,
    type: OUTBOX_CREATE_EVENT,
    payload: { appointmentId, operation: 'create' },
    attempts: 1,
  };
  const appointment = {
    id: appointmentId,
    artistId,
    status: AppointmentStatus.CONFIRMED,
    startAt,
    endAt,
    calendarEvent: null,
    request: {
      durationMinutes: 120,
      client: { name: 'Ana Client' },
    },
    artist: {
      studioSettings: { timezone: 'America/Guayaquil' },
      calendarConnection: {
        calendarId,
        status: CalendarConnectionStatus.CONNECTED,
      },
    },
  };
  const prisma = {
    appointment: { findUnique: jest.fn() },
  };
  const calendar = {
    createEvent: jest.fn(),
    updateEvent: jest.fn(),
    deleteEvent: jest.fn(),
    getEvent: jest.fn(),
  };
  let service: CalendarSyncService;

  beforeEach(() => {
    jest.resetAllMocks();
    prisma.appointment.findUnique.mockResolvedValue(appointment);
    calendar.createEvent.mockResolvedValue({
      externalEventId: 'google-event-id',
      etag: 'etag-1',
    });
    service = new CalendarSyncService(
      prisma as unknown as PrismaService,
      calendar as unknown as CalendarService,
    );
  });

  function expectSyncError(
    error: unknown,
    code: string,
    retryable: boolean,
  ): asserts error is CalendarSyncError {
    expect(error).toBeInstanceOf(CalendarSyncError);
    if (!(error instanceof CalendarSyncError)) {
      throw new Error('Expected CalendarSyncError');
    }
    expect(error.failure).toEqual(expect.objectContaining({ code, retryable }));
  }

  it('rejects a payload that is not the exact create shape', async () => {
    const invalidEvents: ClaimedOutboxEvent[] = [
      { ...event, type: 'other.event' },
      { ...event, payload: { appointmentId, operation: 'update' } },
      {
        ...event,
        payload: { appointmentId, operation: 'create', extra: 'nope' },
      },
      {
        ...event,
        payload: { appointmentId: 'not-a-uuid', operation: 'create' },
      },
    ];

    for (const invalidEvent of invalidEvents) {
      const error = await service
        .process(invalidEvent)
        .catch((failure: unknown) => failure);
      expectSyncError(error, 'OUTBOX_PAYLOAD_INVALID', false);
    }

    expect(prisma.appointment.findUnique).not.toHaveBeenCalled();
  });

  it('derives a stable lowercase hexadecimal event id', () => {
    const expected = createHash('sha256')
      .update(`inkslot:appointment:${appointmentId}`)
      .digest('hex');

    expect(service.deterministicEventId(appointmentId)).toBe(expected);
    expect(service.deterministicEventId(appointmentId)).toBe(expected);
    expect(expected).toMatch(/^[0-9a-f]{64}$/);
  });

  it('creates a safe Google Calendar projection and returns its result', async () => {
    await expect(service.process(event)).resolves.toEqual({
      operation: 'create',
      appointmentId,
      calendarId,
      externalEventId: 'google-event-id',
      etag: 'etag-1',
    });

    expect(prisma.appointment.findUnique).toHaveBeenCalledWith({
      where: { id: appointmentId },
      select: expect.objectContaining({
        request: expect.any(Object),
        artist: expect.any(Object),
        calendarEvent: expect.any(Object),
      }),
    });
    expect(calendar.createEvent).toHaveBeenCalledWith(artistId, {
      calendarId,
      eventId: service.deterministicEventId(appointmentId),
      summary: 'InkSlot — Ana Client',
      description: 'Reserva InkSlot · 120 min',
      startAt,
      endAt,
      timeZone: 'America/Guayaquil',
    });
    expect(JSON.stringify(calendar.createEvent.mock.calls[0])).not.toContain(
      'email',
    );
    expect(calendar.getEvent).not.toHaveBeenCalled();
  });

  it('short-circuits when the local CalendarEvent already exists', async () => {
    prisma.appointment.findUnique.mockResolvedValue({
      ...appointment,
      calendarEvent: {
        calendarId,
        externalEventId: 'existing-google-event',
        etag: 'existing-etag',
      },
    });

    await expect(service.process(event)).resolves.toEqual({
      operation: 'create',
      appointmentId,
      calendarId,
      externalEventId: 'existing-google-event',
      etag: 'existing-etag',
    });
    expect(calendar.createEvent).not.toHaveBeenCalled();
    expect(calendar.getEvent).not.toHaveBeenCalled();
  });

  it('recovers a provider conflict with the same deterministic event id', async () => {
    calendar.createEvent.mockRejectedValue(
      new CalendarProviderError(
        'CALENDAR_EVENT_EXISTS',
        'private provider detail',
      ),
    );
    calendar.getEvent.mockResolvedValue({
      externalEventId: service.deterministicEventId(appointmentId),
      etag: 'recovered-etag',
    });

    await expect(service.process(event)).resolves.toEqual({
      operation: 'create',
      appointmentId,
      calendarId,
      externalEventId: service.deterministicEventId(appointmentId),
      etag: 'recovered-etag',
    });
    expect(calendar.getEvent).toHaveBeenCalledWith(
      artistId,
      service.deterministicEventId(appointmentId),
    );
  });

  it('maps reauthentication to a terminal safe failure', async () => {
    calendar.createEvent.mockRejectedValue(
      new CalendarProviderError(
        'CALENDAR_REAUTH_REQUIRED',
        'private provider detail',
      ),
    );

    const error = await service
      .process(event)
      .catch((failure: unknown) => failure);

    expectSyncError(error, 'CALENDAR_REAUTH_REQUIRED', false);
    expect(error.failure.message).not.toContain('private provider detail');
  });

  it('maps provider unavailability to a retryable safe failure', async () => {
    calendar.createEvent.mockRejectedValue(
      new CalendarProviderError(
        'CALENDAR_UNAVAILABLE',
        'private provider detail',
      ),
    );

    const error = await service
      .process(event)
      .catch((failure: unknown) => failure);

    expectSyncError(error, 'CALENDAR_UNAVAILABLE', true);
    expect(error.failure.message).not.toContain('private provider detail');
  });

  it('updates the existing deterministic event projection', async () => {
    const updateEvent = {
      ...event,
      id: '77777777-7777-4777-8777-777777777777',
      type: 'appointment.calendar.update',
      payload: { appointmentId, operation: 'update' },
    } as ClaimedOutboxEvent;
    calendar.updateEvent.mockResolvedValue({
      externalEventId: service.deterministicEventId(appointmentId),
      etag: 'updated-etag',
    });

    await expect(service.process(updateEvent)).resolves.toEqual({
      operation: 'update',
      appointmentId,
      calendarId,
      externalEventId: service.deterministicEventId(appointmentId),
      etag: 'updated-etag',
    });
    expect(calendar.updateEvent).toHaveBeenCalledWith(
      artistId,
      expect.objectContaining({
        eventId: service.deterministicEventId(appointmentId),
        startAt,
        endAt,
      }),
    );
    expect(calendar.createEvent).not.toHaveBeenCalled();
  });

  it('recreates an update when the external deterministic event is absent', async () => {
    const updateEvent = {
      ...event,
      id: '77777777-7777-4777-8777-777777777777',
      type: 'appointment.calendar.update',
      payload: { appointmentId, operation: 'update' },
    } as ClaimedOutboxEvent;
    calendar.updateEvent.mockRejectedValue(
      new CalendarProviderError(
        'CALENDAR_EVENT_NOT_FOUND',
        'provider detail',
      ),
    );
    calendar.createEvent.mockResolvedValue({
      externalEventId: service.deterministicEventId(appointmentId),
      etag: 'recreated-etag',
    });

    await expect(service.process(updateEvent)).resolves.toEqual(
      expect.objectContaining({ operation: 'update', etag: 'recreated-etag' }),
    );
    expect(calendar.createEvent).toHaveBeenCalledWith(
      artistId,
      expect.objectContaining({
        eventId: service.deterministicEventId(appointmentId),
      }),
    );
  });

  it('deletes the deterministic event even when no local CalendarEvent is present', async () => {
    const deleteEvent = {
      ...event,
      id: '88888888-8888-4888-8888-888888888888',
      type: 'appointment.calendar.delete',
      payload: { appointmentId, operation: 'delete' },
    } as ClaimedOutboxEvent;
    prisma.appointment.findUnique.mockResolvedValue({
      ...appointment,
      status: AppointmentStatus.CANCELLED,
    });

    await expect(service.process(deleteEvent)).resolves.toEqual({
      operation: 'delete',
      effect: 'deleted',
      appointmentId,
    });
    expect(calendar.deleteEvent).toHaveBeenCalledWith(
      artistId,
      service.deterministicEventId(appointmentId),
    );
  });

  it('completes a create as a no-op after the appointment was cancelled', async () => {
    prisma.appointment.findUnique.mockResolvedValue({
      ...appointment,
      status: AppointmentStatus.CANCELLED,
    });

    await expect(service.process(event)).resolves.toEqual({
      operation: 'create',
      effect: 'noop',
      appointmentId,
    });
    expect(calendar.createEvent).not.toHaveBeenCalled();
  });

  it('fails closed when the appointment or connection is unavailable', async () => {
    prisma.appointment.findUnique.mockResolvedValueOnce(null);
    let error = await service
      .process(event)
      .catch((failure: unknown) => failure);
    expectSyncError(error, 'APPOINTMENT_NOT_FOUND', false);

    prisma.appointment.findUnique.mockResolvedValueOnce({
      ...appointment,
      artist: { ...appointment.artist, calendarConnection: null },
    });
    error = await service.process(event).catch((failure: unknown) => failure);
    expectSyncError(error, 'CALENDAR_UNAVAILABLE', false);
  });
});
