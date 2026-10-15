import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';

import { PrismaService } from '../database/prisma.service';
import { CreateAvailabilityBlockDto } from './admin-blocks.dto';

type AvailabilityBlockResponse = {
  id: string;
  startAt: string;
  endAt: string;
  reason: string | null;
};

@Injectable()
export class AdminBlocksService {
  constructor(private readonly prisma: PrismaService) {}

  async list(artistId: string): Promise<AvailabilityBlockResponse[]> {
    const blocks = await this.prisma.availabilityBlock.findMany({
      where: { artistId },
      orderBy: { startAt: 'asc' },
    });
    return blocks.map((block) => this.toResponse(block));
  }

  async create(
    artistId: string,
    dto: CreateAvailabilityBlockDto,
  ): Promise<AvailabilityBlockResponse> {
    const startAt = new Date(dto.startAt);
    const endAt = new Date(dto.endAt);
    if (startAt.getTime() >= endAt.getTime()) {
      throw new BadRequestException({
        error: {
          code: 'INVALID_AVAILABILITY_BLOCK',
          message: 'El inicio debe ser anterior al fin',
        },
      });
    }

    const block = await this.prisma.availabilityBlock.create({
      data: {
        artistId,
        startAt,
        endAt,
        reason: dto.reason,
      },
    });
    return this.toResponse(block);
  }

  async remove(artistId: string, id: string): Promise<void> {
    const block = await this.prisma.availabilityBlock.findFirst({
      where: { id, artistId },
      select: { id: true },
    });
    if (!block) {
      throw new NotFoundException({
        error: { code: 'NOT_FOUND', message: 'Bloqueo no encontrado' },
      });
    }
    await this.prisma.availabilityBlock.delete({ where: { id: block.id } });
  }

  private toResponse(block: {
    id: string;
    startAt: Date;
    endAt: Date;
    reason: string | null;
  }): AvailabilityBlockResponse {
    return {
      id: block.id,
      startAt: block.startAt.toISOString(),
      endAt: block.endAt.toISOString(),
      reason: block.reason,
    };
  }
}
