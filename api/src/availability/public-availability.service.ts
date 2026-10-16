import {
  BadRequestException,
  HttpException,
  Injectable,
  ServiceUnavailableException,
} from '@nestjs/common';
import { AppointmentStatus } from '@prisma/client';
import { DateTime, IANAZone } from 'luxon';

import { CalendarService } from '../calendar/calendar.service';
import { PrismaService } from '../database/prisma.service';
import { BookingRequestsService } from '../requests/requests.service';
import {
  AvailabilityEngine,
  AvailabilityInputError,
  type AvailabilityResult,
  type AvailabilityWindow,
} from './availability.engine';
import {
  DATE_ONLY_PATTERN,
  PublicAvailabilityQueryDto,
} from './public-availability.dto';

const MAX_RANGE_DAYS = 31;

const safeError = (code: string, message: string) => ({
  error: { code, message },
});

const badRequest = (message: string): BadRequestException =>
  new BadRequestException(safeError('BAD_REQUEST', message));

const availabilityNotConfigured = (): ServiceUnavailableException =>
  new ServiceUnavailableException(
    safeError(
      'AVAILABILITY_NOT_CONFIGURED',
      'La disponibilidad aún no está configurada',
    ),
  );

@Injectable()
export class PublicAvailabilityService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly requests: BookingRequestsService,
    private readonly calendar: CalendarService,
    private readonly engine: AvailabilityEngine,
  ) {}

  async get(
    token: string,
    query: PublicAvailabilityQueryDto,
  ): Promise<AvailabilityResult> {
    this.validateQuery(query);
    const context = await this.requests.resolvePublicAvailabilityContext(token);
    const from = DateTime.fromISO(query.from, {
      zone: context.timezone,
    }).startOf('day');
    const to = DateTime.fromISO(query.to, {
      zone: context.timezone,
    }).startOf('day');
    if (
      !from.isValid ||
      !to.isValid ||
      !IANAZone.isValidZone(context.timezone)
    ) {
      throw availabilityNotConfigured();
    }

    const timeMin = from.toUTC().toJSDate();
    const timeMax = to.plus({ days: 1 }).toUTC().toJSDate();
    const settings = await this.prisma.studioSettings.findUnique({
      where: { artistId: context.artistId },
    });
    if (!settings) throw availabilityNotConfigured();

    const [weeklyRows, blockRows, appointmentRows] = await Promise.all([
      this.prisma.weeklyAvailability.findMany({
        where: { artistId: context.artistId },
        orderBy: [{ weekday: 'asc' }, { startLocal: 'asc' }],
      }),
      this.prisma.availabilityBlock.findMany({
        where: {
          artistId: context.artistId,
          startAt: { lt: timeMax },
          endAt: { gt: timeMin },
        },
      }),
      this.prisma.appointment.findMany({
        where: {
          artistId: context.artistId,
          startAt: { lt: timeMax },
          endAt: { gt: timeMin },
          status: {
            in: [
              AppointmentStatus.CONFIRMED,
              AppointmentStatus.COMPLETED,
              AppointmentStatus.NO_SHOW,
            ],
          },
        },
      }),
    ]);

    const externalBusy = await this.calendar.queryBusy(context.artistId, {
      timeMin,
      timeMax,
      timeZone: context.timezone,
    });

    try {
      return this.engine.calculate({
        timezone: settings.timezone,
        fromDate: query.from,
        toDate: query.to,
        now: new Date(),
        durationMinutes: context.durationMinutes,
        slotStepMinutes: settings.slotStepMinutes,
        minimumNoticeHours: settings.minimumNoticeHours,
        horizonDays: settings.horizonDays,
        bufferMinutes: settings.bufferMinutes,
        weeklyWindows: weeklyRows.map<AvailabilityWindow>((window) => ({
          weekday: window.weekday,
          startLocal: this.timeToClock(window.startLocal),
          endLocal: this.timeToClock(window.endLocal),
        })),
        internalBlocks: blockRows.map((block) => ({
          startAt: block.startAt,
          endAt: block.endAt,
        })),
        internalBusy: appointmentRows.map((appointment) => ({
          startAt: appointment.startAt,
          endAt: appointment.endAt,
        })),
        externalBusy,
        calendarVerifiable: true,
        request: {
          minDate: context.minDate ?? undefined,
          maxDate: context.maxDate ?? undefined,
          allowedWeekdays: context.allowedWeekdays ?? undefined,
          allowedWindows: context.allowedWindows ?? undefined,
        },
      });
    } catch (error) {
      if (error instanceof HttpException) throw error;
      if (error instanceof AvailabilityInputError) {
        throw availabilityNotConfigured();
      }
      throw error;
    }
  }

  private validateQuery(query: PublicAvailabilityQueryDto): void {
    if (
      typeof query.from !== 'string' ||
      typeof query.to !== 'string' ||
      !DATE_ONLY_PATTERN.test(query.from) ||
      !DATE_ONLY_PATTERN.test(query.to)
    ) {
      throw badRequest('El rango de fechas debe usar YYYY-MM-DD');
    }

    const from = this.parseDateOnly(query.from);
    const to = this.parseDateOnly(query.to);
    if (!from || !to) {
      throw badRequest('Las fechas no son válidas');
    }
    if (from.getTime() > to.getTime()) {
      throw badRequest('La fecha inicial debe ser anterior o igual a la final');
    }

    const rangeDays =
      Math.floor((to.getTime() - from.getTime()) / 86_400_000) + 1;
    if (rangeDays > MAX_RANGE_DAYS) {
      throw badRequest('El rango no puede superar 31 días');
    }
  }

  private parseDateOnly(value: string): Date | null {
    const [year, month, day] = value.split('-').map(Number);
    const date = new Date(Date.UTC(year, month - 1, day));
    if (
      date.getUTCFullYear() !== year ||
      date.getUTCMonth() !== month - 1 ||
      date.getUTCDate() !== day
    ) {
      return null;
    }
    return date;
  }

  private timeToClock(time: Date): string {
    return DateTime.fromJSDate(time, { zone: 'utc' }).toFormat('HH:mm');
  }
}
