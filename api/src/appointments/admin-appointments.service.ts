import {
  BadRequestException,
  ConflictException,
  HttpException,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { AppointmentStatus, Prisma, SyncStatus } from '@prisma/client';

import {
  AppointmentAvailabilityService,
} from '../availability/appointment-availability.service';
import { PrismaService } from '../database/prisma.service';
import {
  OUTBOX_DELETE_EVENT,
  OUTBOX_UPDATE_EVENT,
} from '../sync/sync.constants';
import {
  decodeAppointmentCursor,
  encodeAppointmentCursor,
} from './appointment-cursor';
import {
  ADMIN_APPOINTMENT_STATUSES,
  type AdminAppointmentStatusFilter,
  type AppointmentActionDto,
  type ListAdminAppointmentsDto,
  type RescheduleAdminAppointmentDto,
} from './admin-appointments.dto';

const PAGE_SIZE = 20;
const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

const safeError = (code: string, message: string) => ({
  error: { code, message },
});

const notFound = (): NotFoundException =>
  new NotFoundException(safeError('NOT_FOUND', 'La cita no existe'));

const serviceUnavailable = (): ServiceUnavailableException =>
  new ServiceUnavailableException(
    safeError('SERVICE_UNAVAILABLE', 'No fue posible actualizar la cita'),
  );

const badRequest = (message: string): BadRequestException =>
  new BadRequestException(safeError('BAD_REQUEST', message));

const stateConflict = (): ConflictException =>
  new ConflictException(
    safeError(
      'APPOINTMENT_STATE_CONFLICT',
      'La cita no permite esta transición de estado',
    ),
  );

const versionConflict = (): ConflictException =>
  new ConflictException(
    safeError(
      'APPOINTMENT_VERSION_CONFLICT',
      'La cita cambió desde la última lectura',
    ),
  );

const slotUnavailable = (): ConflictException =>
  new ConflictException(
    safeError(
      'SLOT_UNAVAILABLE',
      'El horario seleccionado ya no está disponible',
    ),
  );

type AppointmentListRow = Prisma.AppointmentGetPayload<{
  select: {
    id: true;
    status: true;
    syncStatus: true;
    startAt: true;
    endAt: true;
    version: true;
    request: {
      select: {
        durationMinutes: true;
        client: { select: { name: true } };
      };
    };
  };
}>;

type AppointmentDetailRow = Prisma.AppointmentGetPayload<{
  select: {
    id: true;
    status: true;
    syncStatus: true;
    startAt: true;
    endAt: true;
    version: true;
    request: {
      select: {
        durationMinutes: true;
        client: {
          select: {
            name: true;
            email: true;
            phone: true;
            contactChannel: true;
            contactValue: true;
          };
        };
      };
    };
    calendarEvent: {
      select: {
        id: true;
        calendarId: true;
        externalEventId: true;
        etag: true;
        lastSyncedAt: true;
      };
    };
  };
}>;

type AuditRow = {
  action: string;
  createdAt: Date;
  changes: Prisma.JsonValue | null;
};

type RescheduleAppointmentRow = Prisma.AppointmentGetPayload<{
  select: {
    id: true;
    artistId: true;
    startAt: true;
    endAt: true;
    status: true;
    version: true;
    request: {
      select: {
        durationMinutes: true;
        minDate: true;
        maxDate: true;
        allowedWeekdays: true;
        allowedWindows: true;
      };
    };
  };
}>;

type TransitionAppointmentRow = {
  id: string;
  status: AppointmentStatus;
  version: number;
};

export type AdminAppointmentListItem = {
  id: string;
  status: Lowercase<AppointmentStatus>;
  syncStatus: 'pending' | 'synced' | 'failed';
  startAt: string;
  endAt: string;
  version: number;
  client: { name: string };
  durationMinutes: number;
};

export type AdminAppointmentDetail = {
  id: string;
  status: Lowercase<AppointmentStatus>;
  syncStatus: 'pending' | 'synced' | 'failed';
  startAt: string;
  endAt: string;
  version: number;
  client: {
    name: string;
    email: string | null;
    phone: string | null;
    contactChannel: string | null;
    contactValue: string | null;
  };
  durationMinutes: number;
  calendarEvent: {
    id: string;
    calendarId: string;
    externalEventId: string;
    etag: string | null;
    lastSyncedAt: string | null;
  } | null;
  audit: Array<{
    action: string;
    createdAt: string;
    changes: unknown;
  }>;
};

@Injectable()
export class AdminAppointmentsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly availability: AppointmentAvailabilityService,
  ) {}

  async list(
    artistId: string,
    query: ListAdminAppointmentsDto = {},
  ): Promise<{
    items: AdminAppointmentListItem[];
    nextCursor: string | null;
  }> {
    try {
      const status = this.statusFromFilter(query.status);
      const cursor = query.cursor
        ? decodeAppointmentCursor(query.cursor)
        : null;
      const where: Prisma.AppointmentWhereInput = {
        artistId,
        ...(status ? { status } : {}),
        ...(cursor
          ? {
              OR: [
                { startAt: { gt: cursor.startAt } },
                { startAt: cursor.startAt, id: { gt: cursor.id } },
              ],
            }
          : {}),
      };

      const rows = await this.prisma.appointment.findMany({
        where,
        orderBy: [{ startAt: 'asc' }, { id: 'asc' }],
        take: PAGE_SIZE + 1,
        select: {
          id: true,
          status: true,
          syncStatus: true,
          startAt: true,
          endAt: true,
          version: true,
          request: {
            select: {
              durationMinutes: true,
              client: { select: { name: true } },
            },
          },
        },
      });

      const hasNextPage = rows.length > PAGE_SIZE;
      const page = hasNextPage ? rows.slice(0, PAGE_SIZE) : rows;
      const last = page.at(-1);

      return {
        items: page.map((row) => this.toListItem(row)),
        nextCursor:
          hasNextPage && last
            ? encodeAppointmentCursor({
                startAt: last.startAt,
                id: last.id,
              })
            : null,
      };
    } catch (error) {
      this.rethrowHttp(error);
    }
  }

  async detail(
    artistId: string,
    id: string,
  ): Promise<AdminAppointmentDetail> {
    if (!UUID_PATTERN.test(id)) throw notFound();

    try {
      const appointment = await this.prisma.appointment.findFirst({
        where: { id, artistId },
        select: {
          id: true,
          status: true,
          syncStatus: true,
          startAt: true,
          endAt: true,
          version: true,
          request: {
            select: {
              durationMinutes: true,
              client: {
                select: {
                  name: true,
                  email: true,
                  phone: true,
                  contactChannel: true,
                  contactValue: true,
                },
              },
            },
          },
          calendarEvent: {
            select: {
              id: true,
              calendarId: true,
              externalEventId: true,
              etag: true,
              lastSyncedAt: true,
            },
          },
        },
      });
      if (!appointment) throw notFound();

      const audit = await this.prisma.auditLog.findMany({
        where: {
          entityType: 'appointment',
          entityId: id,
          actorType: 'ADMIN',
          actorId: artistId,
        },
        orderBy: { createdAt: 'asc' },
        select: { action: true, createdAt: true, changes: true },
      });

      return this.toDetail(appointment, audit);
    } catch (error) {
      this.rethrowHttp(error);
    }
  }

  async reschedule(
    artistId: string,
    id: string,
    dto: RescheduleAdminAppointmentDto,
  ): Promise<AdminAppointmentDetail> {
    const appointmentId = this.assertAppointmentId(id);
    const startAt = this.normalizeStartAt(dto.startAt);
    this.assertVersion(dto.version);

    let current: RescheduleAppointmentRow | null;
    try {
      current = await this.prisma.appointment.findFirst({
        where: { id: appointmentId, artistId },
        select: {
          id: true,
          artistId: true,
          startAt: true,
          endAt: true,
          status: true,
          version: true,
          request: {
            select: {
              durationMinutes: true,
              minDate: true,
              maxDate: true,
              allowedWeekdays: true,
              allowedWindows: true,
            },
          },
        },
      });
    } catch (error) {
      this.rethrowHttp(error);
    }

    if (!current) throw notFound();
    if (current.status !== AppointmentStatus.CONFIRMED) {
      throw stateConflict();
    }

    const endAt = new Date(
      startAt.getTime() + current.request.durationMinutes * 60_000,
    );
    const sameInterval =
      current.startAt.getTime() === startAt.getTime() &&
      current.endAt.getTime() === endAt.getTime();
    if (sameInterval) {
      return this.detail(artistId, appointmentId);
    }
    if (current.version !== dto.version) {
      throw versionConflict();
    }

    await this.availability.assertAvailable({
      artistId,
      appointmentId,
      startAt,
      durationMinutes: current.request.durationMinutes,
      request: {
        minDate: current.request.minDate,
        maxDate: current.request.maxDate,
        allowedWeekdays: current.request.allowedWeekdays,
        allowedWindows: current.request.allowedWindows,
      },
    });

    await this.serializable(async (transaction) => {
      await this.lockAppointment(transaction, artistId, appointmentId);
      const latest = await transaction.appointment.findFirst({
        where: { id: appointmentId, artistId },
        select: { id: true, status: true, version: true, startAt: true, endAt: true },
      });
      if (!latest) throw notFound();
      if (latest.status !== AppointmentStatus.CONFIRMED) {
        throw stateConflict();
      }

      const latestSameInterval =
        latest.startAt.getTime() === startAt.getTime() &&
        latest.endAt.getTime() === endAt.getTime();
      if (latestSameInterval) return;
      if (latest.version !== dto.version) {
        throw versionConflict();
      }

      await transaction.appointment.update({
        where: { id: appointmentId },
        data: {
          startAt,
          endAt,
          version: { increment: 1 },
          syncStatus: SyncStatus.PENDING,
        },
      });
      await transaction.auditLog.create({
        data: {
          actorType: 'ADMIN',
          actorId: artistId,
          entityType: 'appointment',
          entityId: appointmentId,
          action: 'rescheduled',
          changes: {
            from: {
              startAt: latest.startAt.toISOString(),
              endAt: latest.endAt.toISOString(),
            },
            to: { startAt: startAt.toISOString(), endAt: endAt.toISOString() },
          },
        },
      });
      await transaction.outboxEvent.create({
        data: {
          aggregateId: appointmentId,
          type: OUTBOX_UPDATE_EVENT,
          payload: { appointmentId, operation: 'update' },
        },
      });
    });

    return this.detail(artistId, appointmentId);
  }

  async cancel(
    artistId: string,
    id: string,
    dto: AppointmentActionDto,
  ): Promise<AdminAppointmentDetail> {
    return this.transition(
      artistId,
      id,
      dto,
      AppointmentStatus.CANCELLED,
      OUTBOX_DELETE_EVENT,
    );
  }

  async complete(
    artistId: string,
    id: string,
    dto: AppointmentActionDto,
  ): Promise<AdminAppointmentDetail> {
    return this.transition(
      artistId,
      id,
      dto,
      AppointmentStatus.COMPLETED,
    );
  }

  async noShow(
    artistId: string,
    id: string,
    dto: AppointmentActionDto,
  ): Promise<AdminAppointmentDetail> {
    return this.transition(
      artistId,
      id,
      dto,
      AppointmentStatus.NO_SHOW,
    );
  }

  private async transition(
    artistId: string,
    id: string,
    dto: AppointmentActionDto,
    target: AppointmentStatus,
    outboxType?: typeof OUTBOX_DELETE_EVENT,
  ): Promise<AdminAppointmentDetail> {
    const appointmentId = this.assertAppointmentId(id);
    this.assertVersion(dto.version);

    await this.serializable(async (transaction) => {
      await this.lockAppointment(transaction, artistId, appointmentId);
      const current = (await transaction.appointment.findFirst({
        where: { id: appointmentId, artistId },
        select: { id: true, status: true, version: true },
      })) as TransitionAppointmentRow | null;
      if (!current) throw notFound();

      if (current.status === target) return;
      if (current.status !== AppointmentStatus.CONFIRMED) {
        throw stateConflict();
      }
      if (current.version !== dto.version) {
        throw versionConflict();
      }

      await transaction.appointment.update({
        where: { id: appointmentId },
        data: {
          status: target,
          version: { increment: 1 },
          ...(target === AppointmentStatus.CANCELLED
            ? { syncStatus: SyncStatus.PENDING }
            : {}),
        },
      });
      await transaction.auditLog.create({
        data: {
          actorType: 'ADMIN',
          actorId: artistId,
          entityType: 'appointment',
          entityId: appointmentId,
          action: target.toLowerCase(),
          changes: {
            from: { status: current.status.toLowerCase() },
            to: { status: target.toLowerCase() },
          },
        },
      });
      if (outboxType) {
        await transaction.outboxEvent.create({
          data: {
            aggregateId: appointmentId,
            type: outboxType,
            payload: { appointmentId, operation: 'delete' },
          },
        });
      }
    });

    return this.detail(artistId, appointmentId);
  }

  private async lockAppointment(
    transaction: Prisma.TransactionClient,
    artistId: string,
    appointmentId: string,
  ): Promise<void> {
    await transaction.$queryRaw(
      Prisma.sql`SELECT id FROM "appointments" WHERE id = CAST(${appointmentId} AS uuid) AND artist_id = CAST(${artistId} AS uuid) FOR UPDATE`,
    );
  }

  private assertAppointmentId(id: string): string {
    if (typeof id !== 'string' || !UUID_PATTERN.test(id)) {
      throw notFound();
    }
    return id;
  }

  private normalizeStartAt(value: unknown): Date {
    if (
      typeof value !== 'string' ||
      !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/.test(value)
    ) {
      throw badRequest('La fecha de inicio debe estar en UTC');
    }
    const startAt = new Date(value);
    if (!Number.isFinite(startAt.getTime()) || startAt.toISOString() !== value) {
      throw badRequest('La fecha de inicio no es válida');
    }
    return startAt;
  }

  private assertVersion(value: unknown): asserts value is number {
    if (!Number.isInteger(value) || (value as number) < 1) {
      throw badRequest('La versión de la cita no es válida');
    }
  }

  private async serializable<T>(
    operation: (transaction: Prisma.TransactionClient) => Promise<T>,
  ): Promise<T> {
    for (let attempt = 0; attempt < 3; attempt += 1) {
      try {
        return await this.prisma.$transaction(operation, {
          isolationLevel: Prisma.TransactionIsolationLevel.Serializable,
        });
      } catch (error) {
        if (this.isSerializationConflict(error) && attempt < 2) continue;
        if (this.isExclusionConflict(error)) throw slotUnavailable();
        this.rethrowHttp(error);
      }
    }
    throw serviceUnavailable();
  }

  private isSerializationConflict(error: unknown): boolean {
    return this.hasDatabaseCode(error, ['P2034', '40001', '40P01']);
  }

  private isExclusionConflict(error: unknown): boolean {
    return this.hasDatabaseCode(error, ['23P01']);
  }

  private hasDatabaseCode(
    error: unknown,
    expected: readonly string[],
  ): boolean {
    let current: unknown = error;
    for (let depth = 0; depth < 4 && current; depth += 1) {
      if (typeof current !== 'object') return false;
      const record = current as Record<string, unknown>;
      for (const key of ['code', 'sqlState']) {
        if (
          typeof record[key] === 'string' &&
          expected.includes(record[key] as string)
        ) {
          return true;
        }
      }
      if (typeof record.meta === 'object' && record.meta !== null) {
        const meta = record.meta as Record<string, unknown>;
        if (
          (typeof meta.code === 'string' && expected.includes(meta.code)) ||
          (typeof meta.sqlState === 'string' &&
            expected.includes(meta.sqlState))
        ) {
          return true;
        }
      }
      current = record.cause;
    }
    return false;
  }

  private statusFromFilter(
    status: AdminAppointmentStatusFilter | undefined,
  ): AppointmentStatus | undefined {
    if (status === undefined) return undefined;
    if (!ADMIN_APPOINTMENT_STATUSES.includes(status)) {
      throw new BadRequestException(
        safeError('BAD_REQUEST', 'El estado no es válido'),
      );
    }

    const statuses: Record<
      AdminAppointmentStatusFilter,
      AppointmentStatus
    > = {
      confirmed: AppointmentStatus.CONFIRMED,
      completed: AppointmentStatus.COMPLETED,
      cancelled: AppointmentStatus.CANCELLED,
      no_show: AppointmentStatus.NO_SHOW,
    };
    return statuses[status];
  }

  private toListItem(row: AppointmentListRow): AdminAppointmentListItem {
    return {
      id: row.id,
      status: row.status.toLowerCase() as Lowercase<AppointmentStatus>,
      syncStatus: row.syncStatus.toLowerCase() as AdminAppointmentListItem['syncStatus'],
      startAt: row.startAt.toISOString(),
      endAt: row.endAt.toISOString(),
      version: row.version,
      client: { name: row.request.client.name },
      durationMinutes: row.request.durationMinutes,
    };
  }

  private toDetail(
    row: AppointmentDetailRow,
    audit: AuditRow[],
  ): AdminAppointmentDetail {
    return {
      id: row.id,
      status: row.status.toLowerCase() as Lowercase<AppointmentStatus>,
      syncStatus: row.syncStatus.toLowerCase() as AdminAppointmentDetail['syncStatus'],
      startAt: row.startAt.toISOString(),
      endAt: row.endAt.toISOString(),
      version: row.version,
      client: row.request.client,
      durationMinutes: row.request.durationMinutes,
      calendarEvent: row.calendarEvent
        ? {
            id: row.calendarEvent.id,
            calendarId: row.calendarEvent.calendarId,
            externalEventId: row.calendarEvent.externalEventId,
            etag: row.calendarEvent.etag,
            lastSyncedAt: row.calendarEvent.lastSyncedAt?.toISOString() ?? null,
          }
        : null,
      audit: audit.map((entry) => ({
        action: entry.action,
        createdAt: entry.createdAt.toISOString(),
        changes: this.sanitizeChanges(entry.changes),
      })),
    };
  }

  private sanitizeChanges(
    value: Prisma.JsonValue | null | undefined,
  ): unknown {
    if (value === null || value === undefined) return null;
    if (Array.isArray(value)) {
      return value.map((entry) => this.sanitizeChanges(entry));
    }
    if (typeof value !== 'object') return value;

    const allowedKeys = new Set([
      'from',
      'to',
      'startAt',
      'endAt',
      'status',
      'version',
      'syncStatus',
      'operation',
      'calendarOperation',
    ]);
    const sanitized: Record<string, unknown> = {};
    for (const [key, entry] of Object.entries(value)) {
      if (allowedKeys.has(key)) {
        sanitized[key] = this.sanitizeChanges(entry);
      }
    }
    return sanitized;
  }

  private rethrowHttp(error: unknown): never {
    if (error instanceof HttpException) throw error;
    throw serviceUnavailable();
  }
}
