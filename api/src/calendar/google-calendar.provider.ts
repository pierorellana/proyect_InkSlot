import { Injectable } from '@nestjs/common';
import { google, calendar_v3 } from 'googleapis';

import type { CalendarConfig } from './calendar.config';
import {
  CalendarProviderError,
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
