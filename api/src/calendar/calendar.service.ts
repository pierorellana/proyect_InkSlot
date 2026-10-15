import {
  BadRequestException,
  ConflictException,
  Inject,
  Injectable,
  ServiceUnavailableException,
} from '@nestjs/common';
import { CalendarConnectionStatus } from '@prisma/client';
import { IANAZone } from 'luxon';

import { PrismaService } from '../database/prisma.service';
import { CALENDAR_CONFIG, CALENDAR_PROVIDER } from './calendar.constants';
import type { CalendarConfig } from './calendar.config';
import { CalendarCrypto } from './calendar.crypto';
import {
  CalendarProviderError,
  type CalendarBusyInterval,
  type CalendarProvider,
} from './calendar.provider';
import { CalendarStateService } from './calendar.state.service';

export type CalendarStatusResponse = {
  status: 'connected' | 'disconnected' | 'error' | 'needs_reconnect';
  calendarId?: string;
  calendarName?: string | null;
  connectedAt?: string | null;
  updatedAt?: string;
};

export type CalendarConnectResponse = {
  authorizationUrl: string;
  expiresAt: string;
};

export type CalendarBusyQueryInput = {
  timeMin: Date;
  timeMax: Date;
  timeZone: string;
};

const safeError = (code: string, message: string) => ({
  error: { code, message },
});

@Injectable()
export class CalendarService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly state: CalendarStateService,
    private readonly crypto: CalendarCrypto,
    @Inject(CALENDAR_PROVIDER)
    private readonly provider: CalendarProvider,
    @Inject(CALENDAR_CONFIG)
    private readonly config: CalendarConfig,
  ) {}

  async queryBusy(
    artistId: string,
    input: CalendarBusyQueryInput,
  ): Promise<CalendarBusyInterval[]> {
    this.requireConfigured();

    try {
      if (
        !input ||
        !(input.timeMin instanceof Date) ||
        !(input.timeMax instanceof Date) ||
        !Number.isFinite(input.timeMin.getTime()) ||
        !Number.isFinite(input.timeMax.getTime()) ||
        input.timeMin.getTime() >= input.timeMax.getTime() ||
        typeof input.timeZone !== 'string' ||
        /^[+-]/.test(input.timeZone) ||
        !IANAZone.isValidZone(input.timeZone)
      ) {
        throw new Error('Invalid calendar busy query');
      }

      const connection = await this.prisma.calendarConnection.findUnique({
        where: { artistId },
      });
      if (
        !connection ||
        connection.status !== CalendarConnectionStatus.CONNECTED
      ) {
        throw new Error('Calendar connection unavailable');
      }

      const refreshToken = this.crypto.decrypt(
        connection.encryptedRefreshToken,
      );
      try {
        return await this.provider.freeBusy({
          refreshToken,
          calendarId: connection.calendarId,
          timeMin: input.timeMin,
          timeMax: input.timeMax,
          timeZone: input.timeZone,
        });
      } catch (error) {
        if (
          error instanceof CalendarProviderError &&
          error.code === 'CALENDAR_REAUTH_REQUIRED'
        ) {
          await this.markNeedsReconnect(artistId);
        }
        throw error;
      }
    } catch {
      throw new ServiceUnavailableException(
        safeError(
          'CALENDAR_UNAVAILABLE',
          'No fue posible verificar la disponibilidad del calendario',
        ),
      );
    }
  }

  async status(artistId: string): Promise<CalendarStatusResponse> {
    const connection = await this.prisma.calendarConnection.findUnique({
      where: { artistId },
    });

    if (!connection) {
      return { status: 'disconnected' };
    }

    return {
      status: this.toApiStatus(connection.status),
      calendarId: connection.calendarId,
      calendarName: connection.calendarName,
      connectedAt: connection.connectedAt?.toISOString() ?? null,
      updatedAt: connection.updatedAt.toISOString(),
    };
  }

  async connect(artistId: string): Promise<CalendarConnectResponse> {
    this.requireConfigured();

    try {
      const state = await this.state.create(artistId);
      return {
        authorizationUrl: this.provider.authorizationUrl({
          state: state.state,
        }),
        expiresAt: state.expiresAt.toISOString(),
      };
    } catch (error) {
      throw this.toHttpException(error);
    }
  }

  async callback(input: {
    code?: string;
    state?: string;
    error?: string;
  }): Promise<{ status: 'connected'; calendarName: string }> {
    this.requireConfigured();

    if (input.error) {
      throw new BadRequestException(
        safeError(
          'OAUTH_ACCESS_DENIED',
          'La autorización de Google fue cancelada',
        ),
      );
    }
    if (!input.code || !input.state) {
      throw new BadRequestException(
        safeError(
          'OAUTH_CALLBACK_INVALID',
          'La respuesta de autorización está incompleta',
        ),
      );
    }

    const { artistId } = await this.state.consume(input.state);

    try {
      const tokens = await this.provider.exchangeCode(input.code);
      const calendars = await this.provider.listCalendars(tokens.refreshToken);
      const matches = calendars.filter(
        (calendar) => calendar.name === this.config.calendarName,
      );

      if (matches.length !== 1) {
        throw new ConflictException(
          safeError(
            'CALENDAR_SELECTION_REQUIRED',
            'No existe una selección única para el calendario configurado',
          ),
        );
      }

      await this.prisma.calendarConnection.upsert({
        where: { artistId },
        create: {
          artistId,
          calendarId: matches[0].id,
          calendarName: matches[0].name,
          encryptedRefreshToken: this.crypto.encrypt(tokens.refreshToken),
          status: CalendarConnectionStatus.CONNECTED,
          connectedAt: new Date(),
        },
        update: {
          calendarId: matches[0].id,
          calendarName: matches[0].name,
          encryptedRefreshToken: this.crypto.encrypt(tokens.refreshToken),
          status: CalendarConnectionStatus.CONNECTED,
          connectedAt: new Date(),
        },
      });

      return { status: 'connected', calendarName: matches[0].name };
    } catch (error) {
      throw this.toHttpException(error);
    }
  }

  async disconnect(artistId: string): Promise<void> {
    const connection = await this.prisma.calendarConnection.findUnique({
      where: { artistId },
    });
    if (!connection) return;

    try {
      await this.provider.revoke(
        this.crypto.decrypt(connection.encryptedRefreshToken),
      );
    } catch {
      // The local encrypted token is still removed below so the admin can reconnect.
    } finally {
      await this.prisma.calendarConnection.delete({
        where: { artistId },
      });
    }
  }

  reconnect(artistId: string): Promise<CalendarConnectResponse> {
    return this.connect(artistId);
  }

  async markNeedsReconnect(artistId: string): Promise<void> {
    await this.prisma.calendarConnection.updateMany({
      where: { artistId },
      data: { status: CalendarConnectionStatus.NEEDS_RECONNECT },
    });
  }

  private requireConfigured(): void {
    if (!this.config.configured) {
      throw new ServiceUnavailableException(
        safeError(
          'CALENDAR_NOT_CONFIGURED',
          'La integración de Calendar no está configurada',
        ),
      );
    }
  }

  private toApiStatus(
    status: CalendarConnectionStatus,
  ): CalendarStatusResponse['status'] {
    return status.toLowerCase() as CalendarStatusResponse['status'];
  }

  private toHttpException(error: unknown): Error {
    if (error instanceof CalendarProviderError) {
      if (error.code === 'OAUTH_ACCESS_DENIED') {
        return new BadRequestException(
          safeError(
            'OAUTH_ACCESS_DENIED',
            'La autorización de Google fue cancelada',
          ),
        );
      }
      return new ServiceUnavailableException(
        safeError(error.code, error.message),
      );
    }
    if (
      error instanceof BadRequestException ||
      error instanceof ConflictException ||
      error instanceof ServiceUnavailableException
    ) {
      return error;
    }
    return new ServiceUnavailableException(
      safeError(
        'CALENDAR_UNAVAILABLE',
        'No fue posible completar la operación de Calendar',
      ),
    );
  }
}
