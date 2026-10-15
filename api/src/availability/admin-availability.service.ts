import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { DateTime } from 'luxon';

import { PrismaService } from '../database/prisma.service';
import { UpdateAdminAvailabilityDto } from './admin-availability.dto';

export type AdminAvailabilityResponse = {
  timezone: string;
  slotStepMinutes: number;
  bufferMinutes: number;
  minimumNoticeHours: number;
  horizonDays: number;
  weeklyWindows: Array<{
    weekday: number;
    startLocal: string;
    endLocal: string;
  }>;
};

@Injectable()
export class AdminAvailabilityService {
  constructor(private readonly prisma: PrismaService) {}

  async get(artistId: string): Promise<AdminAvailabilityResponse> {
    const settings = await this.prisma.studioSettings.findUnique({
      where: { artistId },
      include: {
        artist: { select: { id: true } },
      },
    });
    if (!settings) {
      throw new NotFoundException({
        error: {
          code: 'AVAILABILITY_NOT_CONFIGURED',
          message: 'La disponibilidad aún no está configurada',
        },
      });
    }

    const weeklyWindows = await this.prisma.weeklyAvailability.findMany({
      where: { artistId },
      orderBy: [{ weekday: 'asc' }, { startLocal: 'asc' }],
    });

    return {
      timezone: settings.timezone,
      slotStepMinutes: settings.slotStepMinutes,
      bufferMinutes: settings.bufferMinutes,
      minimumNoticeHours: settings.minimumNoticeHours,
      horizonDays: settings.horizonDays,
      weeklyWindows: weeklyWindows.map((window) => ({
        weekday: window.weekday,
        startLocal: this.timeToClock(window.startLocal),
        endLocal: this.timeToClock(window.endLocal),
      })),
    };
  }

  async update(
    artistId: string,
    dto: UpdateAdminAvailabilityDto,
  ): Promise<AdminAvailabilityResponse> {
    this.validateDto(dto);

    await this.prisma.$transaction(async (transaction) => {
      await transaction.studioSettings.upsert({
        where: { artistId },
        create: {
          artistId,
          timezone: dto.timezone,
          slotStepMinutes: dto.slotStepMinutes,
          bufferMinutes: dto.bufferMinutes,
          minimumNoticeHours: dto.minimumNoticeHours,
          horizonDays: dto.horizonDays,
        },
        update: {
          timezone: dto.timezone,
          slotStepMinutes: dto.slotStepMinutes,
          bufferMinutes: dto.bufferMinutes,
          minimumNoticeHours: dto.minimumNoticeHours,
          horizonDays: dto.horizonDays,
        },
      });
      await transaction.weeklyAvailability.deleteMany({ where: { artistId } });
      if (dto.weeklyWindows.length > 0) {
        await transaction.weeklyAvailability.createMany({
          data: dto.weeklyWindows.map((window) => ({
            artistId,
            weekday: window.weekday,
            startLocal: this.clockToTime(window.startLocal),
            endLocal: this.clockToTime(window.endLocal),
          })),
        });
      }
    });

    return {
      timezone: dto.timezone,
      slotStepMinutes: dto.slotStepMinutes,
      bufferMinutes: dto.bufferMinutes,
      minimumNoticeHours: dto.minimumNoticeHours,
      horizonDays: dto.horizonDays,
      weeklyWindows: dto.weeklyWindows,
    };
  }

  private validateDto(dto: UpdateAdminAvailabilityDto): void {
    if (!DateTime.now().setZone(dto.timezone).isValid) {
      throw new BadRequestException({
        error: {
          code: 'INVALID_TIMEZONE',
          message: 'La zona horaria no es válida',
        },
      });
    }
    if (
      dto.weeklyWindows.some((window) => window.startLocal >= window.endLocal)
    ) {
      throw new BadRequestException({
        error: {
          code: 'INVALID_AVAILABILITY_WINDOW',
          message: 'Las franjas deben tener inicio anterior al fin',
        },
      });
    }
  }

  private clockToTime(clock: string): Date {
    const [hour, minute] = clock.split(':').map(Number);
    return new Date(Date.UTC(1970, 0, 1, hour, minute));
  }

  private timeToClock(time: Date): string {
    return DateTime.fromJSDate(time, { zone: 'utc' }).toFormat('HH:mm');
  }
}
