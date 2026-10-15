import { ServiceUnavailableException } from '@nestjs/common';
import {
  CalendarConnectionStatus,
  type CalendarConnection,
  type Prisma,
} from '@prisma/client';

import { PrismaService } from '../database/prisma.service';
import type { CalendarConfig } from './calendar.config';
import { CalendarCrypto } from './calendar.crypto';
import {
  CalendarProviderError,
  type CalendarProvider,
  type CalendarProviderErrorCode,
} from './calendar.provider';
import {
  CalendarService,
  type CalendarBusyQueryInput,
} from './calendar.service';
import { CalendarStateService } from './calendar.state.service';

describe('CalendarService.queryBusy', () => {
  const artistId = 'artist-id';
  const connection: CalendarConnection = {
    id: 'connection-id',
    artistId,
    calendarId: 'inkslot-id',
    calendarName: 'InkSlot',
    encryptedRefreshToken: 'test-encrypted-token',
    status: CalendarConnectionStatus.CONNECTED,
    connectedAt: new Date('2026-10-15T00:00:00Z'),
    updatedAt: new Date('2026-10-15T00:00:00Z'),
  };
  const refreshToken = 'test-refresh-token';
  const rawDetail = 'private upstream diagnostic';
  const prisma = {
    calendarConnection: {
      findUnique: jest.fn<
        Promise<CalendarConnection | null>,
        [Prisma.CalendarConnectionFindUniqueArgs]
      >(),
      updateMany: jest.fn<
        Promise<Prisma.BatchPayload>,
        [Prisma.CalendarConnectionUpdateManyArgs]
      >(),
    },
  };
  const state: jest.Mocked<Pick<CalendarStateService, 'create' | 'consume'>> = {
    create: jest.fn(),
    consume: jest.fn(),
  };
  const crypto: jest.Mocked<Pick<CalendarCrypto, 'decrypt'>> = {
    decrypt: jest.fn(),
  };
  const provider = {
    authorizationUrl: jest.fn(),
    exchangeCode: jest.fn(),
    listCalendars: jest.fn(),
    freeBusy: jest.fn<
      ReturnType<CalendarProvider['freeBusy']>,
      Parameters<CalendarProvider['freeBusy']>
    >(),
    revoke: jest.fn(),
  } satisfies jest.Mocked<CalendarProvider>;
  let input: CalendarBusyQueryInput;
  let config: CalendarConfig;
  let service: CalendarService;

  beforeEach(() => {
    jest.resetAllMocks();
    input = {
      timeMin: new Date('2026-10-23T00:00:00Z'),
      timeMax: new Date('2026-10-24T00:00:00Z'),
      timeZone: 'America/Guayaquil',
    };
    config = { configured: true, calendarName: 'InkSlot', scopes: [] };
    prisma.calendarConnection.findUnique.mockResolvedValue(connection);
    prisma.calendarConnection.updateMany.mockResolvedValue({ count: 1 });
    crypto.decrypt.mockReturnValue(refreshToken);
    provider.freeBusy.mockResolvedValue([]);
    service = new CalendarService(
      prisma as unknown as PrismaService,
      state as unknown as CalendarStateService,
      crypto as unknown as CalendarCrypto,
      provider,
      config,
    );
  });

  async function expectUnavailable(
    queryInput: CalendarBusyQueryInput = input,
    code = 'CALENDAR_UNAVAILABLE',
  ): Promise<void> {
    const error: unknown = await service
      .queryBusy(artistId, queryInput)
      .catch((failure: unknown) => failure);
    expect(error).toBeInstanceOf(ServiceUnavailableException);
    if (!(error instanceof ServiceUnavailableException)) {
      throw new Error('Expected a ServiceUnavailableException');
    }
    expect(error.getStatus()).toBe(503);
    expect(error.getResponse()).toEqual({
      error: {
        code,
        message:
          code === 'CALENDAR_NOT_CONFIGURED'
            ? 'La integración de Calendar no está configurada'
            : 'No fue posible verificar la disponibilidad del calendario',
      },
    });
    const serialized = JSON.stringify(error);
    expect(serialized).not.toContain(rawDetail);
    expect(serialized).not.toContain(refreshToken);
    expect(serialized).not.toContain(connection.encryptedRefreshToken);
  }

  it('decrypts the stored token and queries the selected connected calendar', async () => {
    const intervals = [
      {
        startAt: new Date('2026-10-23T15:00:00Z'),
        endAt: new Date('2026-10-23T18:00:00Z'),
      },
    ];
    provider.freeBusy.mockResolvedValue(intervals);

    await expect(service.queryBusy(artistId, input)).resolves.toEqual(
      intervals,
    );
    expect(prisma.calendarConnection.findUnique).toHaveBeenCalledWith({
      where: { artistId },
    });
    expect(crypto.decrypt).toHaveBeenCalledWith(
      connection.encryptedRefreshToken,
    );
    expect(provider.freeBusy).toHaveBeenCalledTimes(1);
    expect(provider.freeBusy).toHaveBeenCalledWith({
      refreshToken,
      calendarId: connection.calendarId,
      ...input,
    });
    expect(prisma.calendarConnection.updateMany).not.toHaveBeenCalled();
  });

  it('returns an empty list only after a successful provider query', async () => {
    await expect(service.queryBusy(artistId, input)).resolves.toEqual([]);
    expect(provider.freeBusy).toHaveBeenCalledTimes(1);
  });

  it('fails closed when the connection is absent', async () => {
    prisma.calendarConnection.findUnique.mockResolvedValue(null);

    await expectUnavailable();
    expect(crypto.decrypt).not.toHaveBeenCalled();
    expect(provider.freeBusy).not.toHaveBeenCalled();
    expect(prisma.calendarConnection.updateMany).not.toHaveBeenCalled();
  });

  it.each([
    CalendarConnectionStatus.DISCONNECTED,
    CalendarConnectionStatus.ERROR,
    CalendarConnectionStatus.NEEDS_RECONNECT,
  ])('fails closed for a connection with status %s', async (status) => {
    prisma.calendarConnection.findUnique.mockResolvedValue({
      ...connection,
      status,
    });

    await expectUnavailable();
    expect(crypto.decrypt).not.toHaveBeenCalled();
    expect(provider.freeBusy).not.toHaveBeenCalled();
    expect(prisma.calendarConnection.updateMany).not.toHaveBeenCalled();
  });

  it.each<[string, Partial<CalendarBusyQueryInput>]>([
    ['invalid start date', { timeMin: new Date('invalid') }],
    ['invalid end date', { timeMax: new Date('invalid') }],
    ['non-Date start', { timeMin: '2026-10-23' as unknown as Date }],
    ['missing end', { timeMax: undefined }],
    ['null start', { timeMin: null as unknown as Date }],
    ['equal bounds', { timeMax: new Date('2026-10-23T00:00:00Z') }],
    ['inverted range', { timeMax: new Date('2026-10-22T00:00:00Z') }],
    ['unknown zone', { timeZone: 'America/Unknown' }],
    ['empty zone', { timeZone: '' }],
    ['fixed offset zone', { timeZone: 'UTC-5' }],
    ['positive numeric offset', { timeZone: '+05:00' }],
    ['negative numeric offset', { timeZone: '-05:00' }],
    ['local zone alias', { timeZone: 'system' }],
    ['missing zone', { timeZone: undefined }],
    ['non-string zone', { timeZone: 5 as unknown as string }],
  ])('rejects %s before loading a connection', async (_label, overrides) => {
    await expectUnavailable({ ...input, ...overrides });
    expect(prisma.calendarConnection.findUnique).not.toHaveBeenCalled();
    expect(crypto.decrypt).not.toHaveBeenCalled();
    expect(provider.freeBusy).not.toHaveBeenCalled();
  });

  it('preserves the existing unconfigured integration error', async () => {
    config.configured = false;

    await expectUnavailable(input, 'CALENDAR_NOT_CONFIGURED');
    expect(prisma.calendarConnection.findUnique).not.toHaveBeenCalled();
    expect(provider.freeBusy).not.toHaveBeenCalled();
  });

  it.each<CalendarProviderErrorCode>([
    'CALENDAR_UNAVAILABLE',
    'CALENDAR_NOT_CONFIGURED',
    'OAUTH_ACCESS_DENIED',
  ])('maps provider error %s to safe unavailability', async (code) => {
    provider.freeBusy.mockRejectedValue(
      new CalendarProviderError(code, `${rawDetail} ${refreshToken}`),
    );

    await expectUnavailable();
    expect(prisma.calendarConnection.updateMany).not.toHaveBeenCalled();
  });

  it('marks reauthorization as NEEDS_RECONNECT before returning unavailability', async () => {
    provider.freeBusy.mockRejectedValue(
      new CalendarProviderError(
        'CALENDAR_REAUTH_REQUIRED',
        `${rawDetail} ${refreshToken}`,
      ),
    );
    const markNeedsReconnect = jest.spyOn(service, 'markNeedsReconnect');
    let transitionFinished = false;
    prisma.calendarConnection.updateMany.mockImplementation(async () => {
      await Promise.resolve();
      transitionFinished = true;
      return { count: 1 };
    });

    await expectUnavailable();
    expect(markNeedsReconnect).toHaveBeenCalledWith(artistId);
    expect(prisma.calendarConnection.updateMany).toHaveBeenCalledTimes(1);
    expect(prisma.calendarConnection.updateMany).toHaveBeenCalledWith({
      where: { artistId },
      data: { status: CalendarConnectionStatus.NEEDS_RECONNECT },
    });
    expect(transitionFinished).toBe(true);
  });

  it('safely maps a failure while persisting the reconnect transition', async () => {
    provider.freeBusy.mockRejectedValue(
      new CalendarProviderError('CALENDAR_REAUTH_REQUIRED', rawDetail),
    );
    prisma.calendarConnection.updateMany.mockRejectedValue(
      new Error(rawDetail),
    );

    await expectUnavailable();
    expect(prisma.calendarConnection.updateMany).toHaveBeenCalledTimes(1);
  });

  it('maps decryption failure without querying the provider or changing status', async () => {
    crypto.decrypt.mockImplementation(() => {
      throw new Error(`${rawDetail} ${connection.encryptedRefreshToken}`);
    });

    await expectUnavailable();
    expect(provider.freeBusy).not.toHaveBeenCalled();
    expect(prisma.calendarConnection.updateMany).not.toHaveBeenCalled();
  });

  it('maps an unexpected connection lookup failure safely', async () => {
    prisma.calendarConnection.findUnique.mockRejectedValue(
      new Error(rawDetail),
    );

    await expectUnavailable();
    expect(crypto.decrypt).not.toHaveBeenCalled();
    expect(provider.freeBusy).not.toHaveBeenCalled();
  });

  it.each([
    new Error(`${rawDetail} ${refreshToken}`),
    new ServiceUnavailableException(rawDetail),
    { message: rawDetail },
  ])('maps unexpected provider failures safely (case %#)', async (error) => {
    provider.freeBusy.mockRejectedValue(error);

    await expectUnavailable();
    expect(prisma.calendarConnection.updateMany).not.toHaveBeenCalled();
  });
});
