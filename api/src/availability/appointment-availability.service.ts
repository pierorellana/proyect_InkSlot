import {
  ConflictException,
  Injectable,
  ServiceUnavailableException,
} from '@nestjs/common';
import { type BookingRequest, AppointmentStatus } from '@prisma/client';
import { DateTime, IANAZone } from 'luxon';

import { CalendarService } from '../calendar/calendar.service';
import { PrismaService } from '../database/prisma.service';
import {
  AvailabilityEngine,
  AvailabilityInputError,
  type AvailabilityRequest,
  type AvailabilityWindow,
} from './availability.engine';

const safeError = (code: string, message: string) => ({
  error: { code, message },
});

const slotUnavailable = (): ConflictException =>
  new ConflictException(
    safeError(
      'SLOT_UNAVAILABLE',
      'El horario seleccionado ya no está disponible',
    ),
  );

const availabilityNotConfigured = (): ServiceUnavailableException =>
  new ServiceUnavailableException(
    safeError(
      'AVAILABILITY_NOT_CONFIGURED',
      'La disponibilidad aún no está configurada',
    ),
  );

export type AppointmentAvailabilityRequest = Pick<
  BookingRequest,
  'minDate' | 'maxDate' | 'allowedWeekdays' | 'allowedWindows'
>;

export type AppointmentAvailabilityInput = {
  artistId: string;
  appointmentId: string;
  startAt: Date;
  durationMinutes: number;
  request: AppointmentAvailabilityRequest;
};

export type AppointmentAvailabilityResult = {
  startAt: Date;
  endAt: Date;
  timezone: string;
};

const activeAppointmentStatuses = [
  AppointmentStatus.CONFIRMED,
  AppointmentStatus.COMPLETED,
  AppointmentStatus.NO_SHOW,
] as const;

@Injectable()
export class AppointmentAvailabilityService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly calendar: CalendarService,
    private readonly engine: AvailabilityEngine,
  ) {}

  async assertAvailable(
    input: AppointmentAvailabilityInput,
  ): Promise<AppointmentAvailabilityResult> {
    this.validateCandidate(input);

    const settings = await this.prisma.studioSettings.findUnique({
      where: { artistId: input.artistId },
    });
    if (!settings || !IANAZone.isValidZone(settings.timezone)) {
      throw availabilityNotConfigured();
    }

    const localStart = DateTime.fromJSDate(input.startAt, {
      zone: settings.timezone,
    });
    const date = localStart.toISODate();
    if (!localStart.isValid || !date) {
      throw availabilityNotConfigured();
    }

    const dayStart = localStart.startOf('day');
    const timeMin = dayStart.toUTC().toJSDate();
    const timeMax = dayStart.plus({ days: 1 }).toUTC().toJSDate();
    const endAt = new Date(
      input.startAt.getTime() + input.durationMinutes * 60_000,
    );

    const [weeklyRows, blockRows, appointmentRows] = await Promise.all([
      this.prisma.weeklyAvailability.findMany({
        where: { artistId: input.artistId },
        orderBy: [{ weekday: 'asc' }, { startLocal: 'asc' }],
      }),
      this.prisma.availabilityBlock.findMany({
        where: {
          artistId: input.artistId,
          startAt: { lt: timeMax },
          endAt: { gt: timeMin },
        },
      }),
      this.prisma.appointment.findMany({
        where: {
          artistId: input.artistId,
          id: { not: input.appointmentId },
          startAt: { lt: timeMax },
          endAt: { gt: timeMin },
          status: { in: [...activeAppointmentStatuses] },
        },
        select: { startAt: true, endAt: true },
      }),
    ]);

    const externalBusy = await this.calendar.queryBusy(input.artistId, {
      timeMin,
      timeMax,
      timeZone: settings.timezone,
    });

    const request = this.toAvailabilityRequest(input.request);
    let availability;
    try {
      availability = this.engine.calculate({
        timezone: settings.timezone,
        fromDate: date,
        toDate: date,
        now: new Date(),
        durationMinutes: input.durationMinutes,
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
        internalBusy: appointmentRows,
        externalBusy,
        calendarVerifiable: true,
        request,
      });
    } catch (error) {
      if (error instanceof AvailabilityInputError) {
        throw availabilityNotConfigured();
      }
      throw error;
    }

    const startIso = input.startAt.toISOString();
    const endIso = endAt.toISOString();
    const exactSlot = availability.days
      .flatMap((day) => day.slots)
      .find((slot) => slot.startAt === startIso && slot.endAt === endIso);

    if (!exactSlot) {
      throw slotUnavailable();
    }

    return {
      startAt: input.startAt,
      endAt,
      timezone: availability.timezone,
    };
  }

  private validateCandidate(input: AppointmentAvailabilityInput): void {
    if (
      !(input.startAt instanceof Date) ||
      !Number.isFinite(input.startAt.getTime()) ||
      !Number.isInteger(input.durationMinutes) ||
      input.durationMinutes <= 0
    ) {
      throw slotUnavailable();
    }
  }

  private toAvailabilityRequest(
    request: AppointmentAvailabilityRequest,
  ): AvailabilityRequest {
    return {
      minDate: this.toDateOnly(request.minDate),
      maxDate: this.toDateOnly(request.maxDate),
      allowedWeekdays: this.toAllowedWeekdays(request.allowedWeekdays),
      allowedWindows: this.toAllowedWindows(request.allowedWindows),
    };
  }

  private toDateOnly(value: Date | null): string | undefined {
    if (!value) return undefined;
    const date = DateTime.fromJSDate(value, { zone: 'utc' });
    if (!date.isValid || !date.toISODate()) {
      throw slotUnavailable();
    }
    return date.toISODate() as string;
  }

  private toAllowedWeekdays(value: unknown): number[] | undefined {
    if (value === null || value === undefined) return undefined;
    if (
      !Array.isArray(value) ||
      value.some(
        (weekday) =>
          !Number.isInteger(weekday) ||
          (weekday as number) < 0 ||
          (weekday as number) > 6,
      )
    ) {
      throw slotUnavailable();
    }
    return value as number[];
  }

  private toAllowedWindows(
    value: unknown,
  ): Array<{ startLocal: string; endLocal: string }> | undefined {
    if (value === null || value === undefined) return undefined;
    if (
      !Array.isArray(value) ||
      value.some(
        (window) =>
          !window ||
          typeof window !== 'object' ||
          typeof (window as { startLocal?: unknown }).startLocal !== 'string' ||
          typeof (window as { endLocal?: unknown }).endLocal !== 'string',
      )
    ) {
      throw slotUnavailable();
    }
    return value.map((window) => ({
      startLocal: (window as { startLocal: string }).startLocal,
      endLocal: (window as { endLocal: string }).endLocal,
    }));
  }

  private timeToClock(time: Date): string {
    return DateTime.fromJSDate(time, { zone: 'utc' }).toFormat('HH:mm');
  }
}
