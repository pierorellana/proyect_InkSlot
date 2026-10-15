import { BadRequestException, Injectable } from '@nestjs/common';
import { createHash, randomBytes } from 'node:crypto';

import { PrismaService } from '../database/prisma.service';
import { CALENDAR_OAUTH_STATE_TTL_MS } from './calendar.constants';

const invalidState = (): BadRequestException =>
  new BadRequestException({
    error: {
      code: 'OAUTH_STATE_INVALID',
      message: 'El estado de autorización no es válido o expiró',
    },
  });

@Injectable()
export class CalendarStateService {
  constructor(private readonly prisma: PrismaService) {}

  async create(artistId: string): Promise<{ state: string; expiresAt: Date }> {
    const state = randomBytes(32).toString('base64url');
    const expiresAt = new Date(Date.now() + CALENDAR_OAUTH_STATE_TTL_MS);

    await this.prisma.calendarOAuthState.create({
      data: {
        artistId,
        stateHash: this.hash(state),
        expiresAt,
      },
    });

    return { state, expiresAt };
  }

  async consume(state: string): Promise<{ artistId: string }> {
    const now = new Date();
    const record = await this.prisma.calendarOAuthState.findFirst({
      where: {
        stateHash: this.hash(state),
        consumedAt: null,
        expiresAt: { gt: now },
      },
      select: { id: true, artistId: true },
    });

    if (!record) {
      throw invalidState();
    }

    const consumed = await this.prisma.calendarOAuthState.updateMany({
      where: {
        id: record.id,
        consumedAt: null,
        expiresAt: { gt: now },
      },
      data: { consumedAt: now },
    });

    if (consumed.count !== 1) {
      throw invalidState();
    }

    return { artistId: record.artistId };
  }

  private hash(value: string): string {
    return createHash('sha256').update(value).digest('hex');
  }
}
