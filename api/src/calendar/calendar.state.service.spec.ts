import { BadRequestException } from '@nestjs/common';

import { PrismaService } from '../database/prisma.service';
import { CalendarStateService } from './calendar.state.service';

describe('CalendarStateService', () => {
  it('stores only a hash and consumes a state once', async () => {
    const create = jest.fn().mockResolvedValue({});
    const findFirst = jest.fn().mockResolvedValue({
      id: 'state-id',
      artistId: 'artist-id',
    });
    const updateMany = jest.fn().mockResolvedValue({ count: 1 });
    const service = new CalendarStateService({
      calendarOAuthState: { create, findFirst, updateMany },
    } as unknown as PrismaService);

    const created = await service.create('artist-id');
    const consumed = await service.consume(created.state);

    expect(created.state).toHaveLength(43);
    expect(create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        artistId: 'artist-id',
        stateHash: expect.not.stringMatching(created.state),
        expiresAt: expect.any(Date),
      }),
    });
    expect(findFirst).toHaveBeenCalledWith({
      where: expect.objectContaining({
        consumedAt: null,
        expiresAt: { gt: expect.any(Date) },
      }),
      select: { id: true, artistId: true },
    });
    expect(updateMany).toHaveBeenCalledWith({
      where: expect.objectContaining({
        id: 'state-id',
        consumedAt: null,
        expiresAt: { gt: expect.any(Date) },
      }),
      data: { consumedAt: expect.any(Date) },
    });
    expect(consumed).toEqual({ artistId: 'artist-id' });
  });

  it('rejects an unknown, expired, or replayed state', async () => {
    const service = new CalendarStateService({
      calendarOAuthState: {
        findFirst: jest.fn().mockResolvedValue(null),
        updateMany: jest.fn(),
      },
    } as unknown as PrismaService);

    await expect(service.consume('invalid-state')).rejects.toEqual(
      expect.any(BadRequestException),
    );
  });

  it('rejects a state lost in a concurrent consume race', async () => {
    const service = new CalendarStateService({
      calendarOAuthState: {
        findFirst: jest.fn().mockResolvedValue({
          id: 'state-id',
          artistId: 'artist-id',
        }),
        updateMany: jest.fn().mockResolvedValue({ count: 0 }),
      },
    } as unknown as PrismaService);

    await expect(service.consume('race-state')).rejects.toEqual(
      expect.any(BadRequestException),
    );
  });
});
