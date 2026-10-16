import { Injectable } from '@nestjs/common';
import {
  AppointmentStatus,
  CalendarConnectionStatus,
} from '@prisma/client';
import { createHash } from 'node:crypto';

import { CalendarProviderError } from '../calendar/calendar.provider';
import { CalendarService } from '../calendar/calendar.service';
import { PrismaService } from '../database/prisma.service';
import {
  OUTBOX_CREATE_EVENT,
  OUTBOX_DELETE_EVENT,
  OUTBOX_UPDATE_EVENT,
  type CalendarOutboxOperation,
  type CalendarSyncSuccess,
  type ClaimedOutboxEvent,
  type SyncFailure,
} from './sync.constants';

export type { CalendarSyncSuccess } from './sync.constants';

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

type CalendarAppointmentPayload = {
  appointmentId: string;
  operation: CalendarOutboxOperation;
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
        status: true,
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

    if (
      payload.operation === 'create' &&
      appointment.status !== AppointmentStatus.CONFIRMED
    ) {
      return {
        operation: 'create',
        effect: 'noop',
        appointmentId: appointment.id,
      };
    }

    if (payload.operation === 'create' && appointment.calendarEvent) {
      return {
        operation: 'create',
        appointmentId: appointment.id,
        calendarId: appointment.calendarEvent.calendarId,
        externalEventId: appointment.calendarEvent.externalEventId,
        etag: appointment.calendarEvent.etag,
      };
    }

    const connection = appointment.artist.calendarConnection;
    if (
      !connection ||
      connection.status !== CalendarConnectionStatus.CONNECTED
    ) {
      throw this.failure(
        'CALENDAR_UNAVAILABLE',
        'La conexión de Calendar no está disponible',
        false,
      );
    }

    const eventId = this.deterministicEventId(appointment.id);

    if (payload.operation === 'delete') {
      try {
        await this.calendar.deleteEvent(appointment.artistId, eventId);
        return {
          operation: 'delete',
          effect: 'deleted',
          appointmentId: appointment.id,
        };
      } catch (error) {
        throw this.toSyncError(error);
      }
    }

    const timezone = appointment.artist.studioSettings?.timezone;
    if (!timezone) {
      throw this.failure(
        'CALENDAR_UNAVAILABLE',
        'La conexión de Calendar no está disponible',
        false,
      );
    }

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
      const result =
        payload.operation === 'create'
          ? await this.calendar.createEvent(appointment.artistId, input)
          : await this.calendar.updateEvent(appointment.artistId, input);
      return this.success(
        payload.operation,
        appointment.id,
        connection.calendarId,
        result,
      );
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
          payload.operation,
        );
      }

      if (
        payload.operation === 'update' &&
        error instanceof CalendarProviderError &&
        error.code === 'CALENDAR_EVENT_NOT_FOUND'
      ) {
        try {
          const recreated = await this.calendar.createEvent(
            appointment.artistId,
            input,
          );
          return this.success(
            'update',
            appointment.id,
            connection.calendarId,
            recreated,
          );
        } catch (recreateError) {
          if (
            recreateError instanceof CalendarProviderError &&
            recreateError.code === 'CALENDAR_EVENT_EXISTS'
          ) {
            return this.recoverExistingEvent(
              appointment.id,
              appointment.artistId,
              connection.calendarId,
              eventId,
              'update',
            );
          }
          throw this.toSyncError(recreateError);
        }
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
    operation: 'create' | 'update',
  ): Promise<CalendarSyncSuccess> {
    try {
      const result = await this.calendar.getEvent(artistId, eventId);
      if (result) {
        return this.success(operation, appointmentId, calendarId, result);
      }

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

  private parsePayload(event: ClaimedOutboxEvent): CalendarAppointmentPayload {
    const operationByType: Record<string, CalendarOutboxOperation | undefined> =
      {
        [OUTBOX_CREATE_EVENT]: 'create',
        [OUTBOX_UPDATE_EVENT]: 'update',
        [OUTBOX_DELETE_EVENT]: 'delete',
      };
    const expectedOperation = operationByType[event.type];

    if (
      !expectedOperation ||
      !this.isRecord(event.payload) ||
      Object.keys(event.payload).sort().join(',') !==
        'appointmentId,operation' ||
      typeof event.payload.appointmentId !== 'string' ||
      !UUID_PATTERN.test(event.payload.appointmentId) ||
      event.payload.operation !== expectedOperation
    ) {
      throw this.invalidPayload();
    }

    return {
      appointmentId: event.payload.appointmentId,
      operation: expectedOperation,
    };
  }

  private success(
    operation: 'create' | 'update',
    appointmentId: string,
    calendarId: string,
    result: { externalEventId: string; etag: string | null },
  ): CalendarSyncSuccess {
    return {
      operation,
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
