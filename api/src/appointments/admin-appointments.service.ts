import {
  BadRequestException,
  HttpException,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { AppointmentStatus, Prisma } from '@prisma/client';

import { PrismaService } from '../database/prisma.service';
import {
  decodeAppointmentCursor,
  encodeAppointmentCursor,
} from './appointment-cursor';
import {
  ADMIN_APPOINTMENT_STATUSES,
  type AdminAppointmentStatusFilter,
  type ListAdminAppointmentsDto,
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
    safeError('SERVICE_UNAVAILABLE', 'No fue posible consultar las citas'),
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
  constructor(private readonly prisma: PrismaService) {}

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
