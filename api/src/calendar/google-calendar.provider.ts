import { Injectable } from '@nestjs/common';
import { google, calendar_v3 } from 'googleapis';

import type { CalendarConfig } from './calendar.config';
import {
  CalendarProviderError,
  type CalendarBusyInterval,
  type CalendarBusyQuery,
  type CalendarEventInput,
  type CalendarEventResult,
  type CalendarProvider,
  type CalendarSummary,
  type CalendarTokens,
} from './calendar.provider';

@Injectable()
export class GoogleCalendarProvider implements CalendarProvider {
  constructor(private readonly config: CalendarConfig) {}

  authorizationUrl(input: { state: string }): string {
    const oauth = this.createClient();

    return oauth.generateAuthUrl({
      access_type: 'offline',
      include_granted_scopes: true,
      prompt: 'consent',
      scope: this.config.scopes,
      state: input.state,
    });
  }

  async exchangeCode(code: string): Promise<CalendarTokens> {
    try {
      const { tokens } = await this.createClient().getToken(code);
      if (!tokens.refresh_token) {
        throw new CalendarProviderError(
          'CALENDAR_UNAVAILABLE',
          'Google no devolvió un refresh token',
        );
      }

      return { refreshToken: tokens.refresh_token };
    } catch (error) {
      if (error instanceof CalendarProviderError) {
        throw error;
      }
      throw new CalendarProviderError(
        'CALENDAR_UNAVAILABLE',
        'No fue posible completar la autorización de Google',
      );
    }
  }

  async listCalendars(refreshToken: string): Promise<CalendarSummary[]> {
    try {
      const client = this.createClient();
      client.setCredentials({ refresh_token: refreshToken });
      const calendar = google.calendar({
        version: 'v3',
        auth: client,
      });
      const response = await calendar.calendarList.list({
        minAccessRole: 'writer',
        showDeleted: false,
      });

      return (response.data.items ?? [])
        .filter(
          (
            item,
          ): item is calendar_v3.Schema$CalendarListEntry & { id: string } =>
            typeof item.id === 'string' && item.id.length > 0,
        )
        .map((item) => ({
          id: item.id,
          name: item.summary ?? item.id,
        }));
    } catch {
      throw new CalendarProviderError(
        'CALENDAR_UNAVAILABLE',
        'No fue posible consultar los calendarios de Google',
      );
    }
  }

  async freeBusy(input: CalendarBusyQuery): Promise<CalendarBusyInterval[]> {
    try {
      const client = this.createClient();
      client.setCredentials({ refresh_token: input.refreshToken });
      const calendar = google.calendar({ version: 'v3', auth: client });
      const response = await calendar.freebusy.query({
        requestBody: {
          timeMin: input.timeMin.toISOString(),
          timeMax: input.timeMax.toISOString(),
          timeZone: input.timeZone,
          items: [{ id: input.calendarId }],
        },
      });
      const calendarData = response.data.calendars?.[input.calendarId];
      if (!calendarData || (calendarData.errors?.length ?? 0) > 0) {
        throw new CalendarProviderError(
          'CALENDAR_UNAVAILABLE',
          'No fue posible consultar la disponibilidad de Google',
        );
      }

      return (calendarData.busy ?? [])
        .map((busy) => {
          const startAt = new Date(busy.start ?? '');
          const endAt = new Date(busy.end ?? '');
          if (
            !busy.start ||
            !busy.end ||
            !Number.isFinite(startAt.getTime()) ||
            !Number.isFinite(endAt.getTime()) ||
            startAt.getTime() >= endAt.getTime()
          ) {
            throw new CalendarProviderError(
              'CALENDAR_UNAVAILABLE',
              'Google devolvió un intervalo de disponibilidad inválido',
            );
          }
          return { startAt, endAt };
        })
        .sort(
          (left, right) => left.startAt.getTime() - right.startAt.getTime(),
        );
    } catch (error) {
      if (error instanceof CalendarProviderError) {
        throw error;
      }
      const status = this.googleHttpStatus(error);
      if (status === 401 || status === 403) {
        throw new CalendarProviderError(
          'CALENDAR_REAUTH_REQUIRED',
          'La conexión de Google requiere autorización nuevamente',
        );
      }
      throw new CalendarProviderError(
        'CALENDAR_UNAVAILABLE',
        'No fue posible consultar la disponibilidad de Google',
      );
    }
  }

  async createEvent(input: CalendarEventInput): Promise<CalendarEventResult> {
    try {
      const client = this.createClient();
      client.setCredentials({ refresh_token: input.refreshToken });
      const calendar = google.calendar({ version: 'v3', auth: client });
      const response = await calendar.events.insert({
        calendarId: input.calendarId,
        sendUpdates: 'none',
        requestBody: {
          id: input.eventId,
          summary: input.summary,
          description: input.description,
          start: {
            dateTime: input.startAt.toISOString(),
            timeZone: input.timeZone,
          },
          end: {
            dateTime: input.endAt.toISOString(),
            timeZone: input.timeZone,
          },
        },
      });
      const externalEventId = response.data.id;
      if (!externalEventId) {
        throw new CalendarProviderError(
          'CALENDAR_UNAVAILABLE',
          'Google no devolvió el identificador del evento',
        );
      }
      return {
        externalEventId,
        etag: response.data.etag ?? null,
      };
    } catch (error) {
      if (error instanceof CalendarProviderError) {
        throw error;
      }
      throw this.toEventError(error);
    }
  }

  async updateEvent(input: CalendarEventInput): Promise<CalendarEventResult> {
    try {
      const client = this.createClient();
      client.setCredentials({ refresh_token: input.refreshToken });
      const calendar = google.calendar({ version: 'v3', auth: client });
      const response = await calendar.events.update({
        calendarId: input.calendarId,
        eventId: input.eventId,
        sendUpdates: 'none',
        requestBody: {
          summary: input.summary,
          description: input.description,
          start: {
            dateTime: input.startAt.toISOString(),
            timeZone: input.timeZone,
          },
          end: {
            dateTime: input.endAt.toISOString(),
            timeZone: input.timeZone,
          },
        },
      });
      const externalEventId = response.data.id;
      if (!externalEventId) {
        throw new CalendarProviderError(
          'CALENDAR_UNAVAILABLE',
          'Google no devolvió el identificador del evento',
        );
      }
      return {
        externalEventId,
        etag: response.data.etag ?? null,
      };
    } catch (error) {
      if (error instanceof CalendarProviderError) {
        throw error;
      }
      throw this.toEventError(error);
    }
  }

  async deleteEvent(input: {
    refreshToken: string;
    calendarId: string;
    eventId: string;
  }): Promise<void> {
    try {
      const client = this.createClient();
      client.setCredentials({ refresh_token: input.refreshToken });
      const calendar = google.calendar({ version: 'v3', auth: client });
      await calendar.events.delete({
        calendarId: input.calendarId,
        eventId: input.eventId,
        sendUpdates: 'none',
      });
    } catch (error) {
      if (this.googleHttpStatus(error) === 404) {
        return;
      }
      if (error instanceof CalendarProviderError) {
        throw error;
      }
      throw this.toEventError(error);
    }
  }

  async getEvent(input: {
    refreshToken: string;
    calendarId: string;
    eventId: string;
  }): Promise<CalendarEventResult | null> {
    try {
      const client = this.createClient();
      client.setCredentials({ refresh_token: input.refreshToken });
      const calendar = google.calendar({ version: 'v3', auth: client });
      const response = await calendar.events.get({
        calendarId: input.calendarId,
        eventId: input.eventId,
      });
      const externalEventId = response.data.id;
      if (!externalEventId) {
        throw new CalendarProviderError(
          'CALENDAR_UNAVAILABLE',
          'Google no devolvió el identificador del evento',
        );
      }
      return {
        externalEventId,
        etag: response.data.etag ?? null,
      };
    } catch (error) {
      const status = this.googleHttpStatus(error);
      if (status === 404) {
        return null;
      }
      if (error instanceof CalendarProviderError) {
        throw error;
      }
      throw this.toEventError(error);
    }
  }

  async revoke(refreshToken: string): Promise<void> {
    try {
      await this.createClient().revokeToken(refreshToken);
    } catch {
      throw new CalendarProviderError(
        'CALENDAR_UNAVAILABLE',
        'No fue posible revocar la conexión de Google',
      );
    }
  }

  private googleHttpStatus(error: unknown): number | undefined {
    if (typeof error !== 'object' || error === null) {
      return undefined;
    }
    if (
      'response' in error &&
      typeof error.response === 'object' &&
      error.response !== null &&
      'status' in error.response &&
      typeof error.response.status === 'number'
    ) {
      return error.response.status;
    }
    if ('code' in error && typeof error.code === 'number') {
      return error.code;
    }
    return undefined;
  }

  private toEventError(error: unknown): CalendarProviderError {
    const status = this.googleHttpStatus(error);
    if (status === 401 || status === 403) {
      return new CalendarProviderError(
        'CALENDAR_REAUTH_REQUIRED',
        'La conexión de Google requiere autorización nuevamente',
      );
    }
    if (status === 409) {
      return new CalendarProviderError(
        'CALENDAR_EVENT_EXISTS',
        'El evento de Calendar ya existe',
      );
    }
    if (status === 404) {
      return new CalendarProviderError(
        'CALENDAR_EVENT_NOT_FOUND',
        'El evento de Calendar no existe',
      );
    }
    return new CalendarProviderError(
      'CALENDAR_UNAVAILABLE',
      'No fue posible sincronizar el evento con Google Calendar',
    );
  }

  private createClient(): InstanceType<typeof google.auth.OAuth2> {
    if (
      !this.config.configured ||
      !this.config.clientId ||
      !this.config.clientSecret ||
      !this.config.redirectUri
    ) {
      throw new CalendarProviderError(
        'CALENDAR_NOT_CONFIGURED',
        'La integración de Calendar no está configurada',
      );
    }

    return new google.auth.OAuth2(
      this.config.clientId,
      this.config.clientSecret,
      this.config.redirectUri,
    );
  }
}
