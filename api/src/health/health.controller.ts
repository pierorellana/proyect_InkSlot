import { Controller, Get, ServiceUnavailableException } from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';

@Controller('health')
export class HealthController {
  constructor(private readonly prisma: PrismaService) {}

  @Get()
  async getHealth() {
    try {
      await this.prisma.$queryRawUnsafe('SELECT 1');
      return { status: 'ok', service: 'inkslot-api', database: 'ok' } as const;
    } catch {
      throw new ServiceUnavailableException({
        status: 'error',
        service: 'inkslot-api',
        database: 'unavailable',
      });
    }
  }
}
