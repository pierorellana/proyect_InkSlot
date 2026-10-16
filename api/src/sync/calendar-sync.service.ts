import { Injectable } from '@nestjs/common';
import { CalendarConnectionStatus } from '@prisma/client';
import { createHash } from 'node:crypto';

import { PrismaService } from '../database/prisma.service';
import { CalendarProviderError } from '../calendar/calendar.provider';
import { CalendarService } from '../calendar/calendar.service';
import {
  OUTBOX_CREATE_EVENT,
  type ClaimedOutboxEvent,
  type SyncFailure,
} from './sync.constants';

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

type CreateAppointmentPayload = {
  appointmentId: string;
  operation: 'create';
};

type AppointmentForSync = {
  id: string;
  artistId: string;
  startAt: Date;
  endAt: Date;
  calendarEvent: {
    calendarId: string;
    externalEventId: string;
    etag: string | null;
  } | null;
  request: {
    durationMinutes: number;
    client: { name: string };
  };
  artist: {
    studioSettings: { timezone: string } | null;
    calendarConnection: {
      calendarId: string;
      status: CalendarConnectionStatus;
    } | null;
  };
};

export type CalendarSyncSuccess = {
  appointmentId: string;
  calendarId: string;
  externalEventId: string;
  etag: string | null;
};

export class CalendarSyncError extends Error {
  constructor(public readonly failure: SyncFailure) {
    super(failure.message);
    this.name = 'CalendarSyncError';
  }
}

@Injectable()
export class CalendarSyncService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly calendar: CalendarService,
  ) {}

  async process(event: ClaimedOutboxEvent): Promise<CalendarSyncSuccess> {
    const payload = this.parsePayload(event);
    const appointment = await this.prisma.appointment.findUnique({
      where: { id: payload.appointmentId },
      select: {
        id: true,
        artistId: true,
        startAt: true,
        endAt: true,
        calendarEvent: {
          select: {
            calendarId: true,
            externalEventId: true,
            etag: true,
          },
        },
        request: {
          select: {
            durationMinutes: true,
            client: { select: { name: true } },
          },
        },
        artist: {
          select: {
            studioSettings: { select: { timezone: true } },
            calendarConnection: {
              select: { calendarId: true, status: true },
            },
          },
        },
      },
    });

    if (!appointment) {
      throw this.failure(
        'APPOINTMENT_NOT_FOUND',
        'La reserva no existe',
        false,
      );
    }

    if (appointment.calendarEvent) {
      return {
        appointmentId: appointment.id,
        calendarId: appointment.calendarEvent.calendarId,
        externalEventId: appointment.calendarEvent.externalEventId,
        etag: appointment.calendarEvent.etag,
      };
    }

    const connection = appointment.artist.calendarConnection;
    const timezone = appointment.artist.studioSettings?.timezone;
    if (
      !connection ||
      connection.status !== CalendarConnectionStatus.CONNECTED ||
      !timezone
    ) {
      throw this.failure(
        'CALENDAR_UNAVAILABLE',
        'La conexión de Calendar no está disponible',
        false,
      );
    }

    const eventId = this.deterministicEventId(appointment.id);
    const input = {
      calendarId: connection.calendarId,
      eventId,
      summary: `InkSlot — ${appointment.request.client.name}`,
      description: `Reserva InkSlot · ${appointment.request.durationMinutes} min`,
      startAt: appointment.startAt,
      endAt: appointment.endAt,
      timeZone: timezone,
    };

    try {
      const result = await this.calendar.createEvent(
        appointment.artistId,
        input,
      );
      return this.success(appointment.id, connection.calendarId, result);
    } catch (error) {
      if (
        error instanceof CalendarProviderError &&
        error.code === 'CALENDAR_EVENT_EXISTS'
      ) {
        return this.recoverExistingEvent(
          appointment.id,
          appointment.artistId,
          connection.calendarId,
          eventId,
        );
      }

      throw this.toSyncError(error);
    }
  }

  deterministicEventId(appointmentId: string): string {
    return createHash('sha256')
      .update(`inkslot:appointment:${appointmentId}`)
      .digest('hex');
  }

  private async recoverExistingEvent(
    appointmentId: string,
    artistId: string,
    calendarId: string,
    eventId: string,
  ): Promise<CalendarSyncSuccess> {
    try {
      const result = await this.calendar.getEvent(artistId, eventId);
      if (result) return this.success(appointmentId, calendarId, result);

      throw this.failure(
        'CALENDAR_UNAVAILABLE',
        'No fue posible recuperar el evento de Calendar',
        true,
      );
    } catch (error) {
      if (error instanceof CalendarSyncError) throw error;
      throw this.toSyncError(error);
    }
  }

  private parsePayload(event: ClaimedOutboxEvent): CreateAppointmentPayload {
    if (event.type !== OUTBOX_CREATE_EVENT || !this.isRecord(event.payload)) {
      throw this.invalidPayload();
    }

    const keys = Object.keys(event.payload).sort();
    if (
      keys.length !== 2 ||
      keys[0] !== 'appointmentId' ||
      keys[1] !== 'operation' ||
      typeof event.payload.appointmentId !== 'string' ||
      !UUID_PATTERN.test(event.payload.appointmentId) ||
      event.payload.operation !== 'create'
    ) {
      throw this.invalidPayload();
    }

    return {
      appointmentId: event.payload.appointmentId,
      operation: 'create',
    };
  }

  private success(
    appointmentId: string,
    calendarId: string,
    result: { externalEventId: string; etag: string | null },
  ): CalendarSyncSuccess {
    return {
      appointmentId,
      calendarId,
      externalEventId: result.externalEventId,
      etag: result.etag,
    };
  }

  private toSyncError(error: unknown): CalendarSyncError {
    if (error instanceof CalendarSyncError) return error;

    if (error instanceof CalendarProviderError) {
      if (error.code === 'CALENDAR_REAUTH_REQUIRED') {
        return this.failure(
          'CALENDAR_REAUTH_REQUIRED',
          'La conexión de Google requiere autorización nuevamente',
          false,
        );
      }

      return this.failure(
        'CALENDAR_UNAVAILABLE',
        'No fue posible sincronizar el evento con Google Calendar',
        true,
      );
    }

    return this.failure(
      'CALENDAR_UNAVAILABLE',
      'No fue posible sincronizar el evento con Google Calendar',
      true,
    );
  }

  private invalidPayload(): CalendarSyncError {
    return this.failure(
      'OUTBOX_PAYLOAD_INVALID',
      'El evento de sincronización no tiene un payload válido',
      false,
    );
  }

  private failure(
    code: SyncFailure['code'],
    message: string,
    retryable: boolean,
  ): CalendarSyncError {
    return new CalendarSyncError({ code, message, retryable });
  }

  private isRecord(value: unknown): value is Record<string, unknown> {
    return typeof value === 'object' && value !== null && !Array.isArray(value);
  }
}
