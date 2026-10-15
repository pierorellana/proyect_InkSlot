import {
  BadRequestException,
  ConflictException,
  GoneException,
  HttpException,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
  UnprocessableEntityException,
} from '@nestjs/common';
import { BookingRequestStatus, Prisma } from '@prisma/client';

import { PrismaService } from '../database/prisma.service';
import {
  BOOKING_REQUEST_PAGE_SIZE,
  DEFAULT_BOOKING_TOKEN_TTL_HOURS,
  MAX_BOOKING_TOKEN_TTL_HOURS,
} from './requests.constants';
import {
  decodeBookingCursor,
  encodeBookingCursor,
  generateBookingToken,
  hashBookingToken,
} from './booking-token';
import type {
  BookingRequestStatusFilter,
  CreateBookingRequestDto,
  ListBookingRequestsDto,
  RenewBookingTokenDto,
} from './requests.dto';

type BookingRequestWithClient = Prisma.BookingRequestGetPayload<{
  include: { client: true };
}>;

type BookingRequestWithTokens = Prisma.BookingRequestGetPayload<{
  include: { client: true; tokens: true };
}>;

type PublicTokenRecord = Prisma.BookingTokenGetPayload<{
  include: {
    request: {
      include: {
        artist: {
          select: {
            displayName: true;
            studioSettings: { select: { timezone: true } };
          };
        };
      };
    };
  };
}>;

type Transaction = Prisma.TransactionClient;

type NormalizedRestrictions = {
  minDate: Date | null;
  maxDate: Date | null;
  allowedWeekdays: number[] | null;
  allowedWindows: Array<{ startLocal: string; endLocal: string }> | null;
};

export type BookingRequestResponse = {
  id: string;
  client: {
    id: string;
    name: string;
    email: string | null;
    phone: string | null;
  };
  depositVerified: boolean;
  durationMinutes: number;
  status: Lowercase<BookingRequestStatus>;
  minDate: string | null;
  maxDate: string | null;
  allowedWeekdays: number[] | null;
  allowedWindows: Array<{ startLocal: string; endLocal: string }> | null;
  createdAt: string;
};

export type BookingRequestLink = {
  path: string;
  expiresAt: string;
};

export type PublicReservationResponse = {
  status: 'pending' | 'booked';
  artist: { displayName: string };
  durationMinutes: number;
  timezone: string;
  restrictions: {
    minDate: string | null;
    maxDate: string | null;
    allowedWeekdays: number[] | null;
    allowedWindows: Array<{ startLocal: string; endLocal: string }> | null;
  };
  expiresAt: string;
};

const safeError = (code: string, message: string) => ({
  error: { code, message },
});

const badRequest = (code: string, message: string): BadRequestException =>
  new BadRequestException(safeError(code, message));

const notFound = (): NotFoundException =>
  new NotFoundException(safeError('NOT_FOUND', 'La solicitud no existe'));

const tokenNotFound = (): NotFoundException =>
  new NotFoundException(
    safeError('TOKEN_NOT_FOUND', 'El enlace de reserva no existe'),
  );

const tokenExpired = (): GoneException =>
  new GoneException(safeError('TOKEN_EXPIRED', 'El enlace de reserva expiró'));

const tokenRevoked = (): GoneException =>
  new GoneException(
    safeError('TOKEN_REVOKED', 'El enlace de reserva ya no está disponible'),
  );

const serviceUnavailable = (): ServiceUnavailableException =>
  new ServiceUnavailableException(
    safeError('SERVICE_UNAVAILABLE', 'No fue posible procesar la solicitud'),
  );

@Injectable()
export class BookingRequestsService {
  constructor(private readonly prisma: PrismaService) {}

  async create(
    artistId: string,
    dto: CreateBookingRequestDto,
  ): Promise<{ request: BookingRequestResponse; link: BookingRequestLink }> {
    if (!Number.isInteger(dto.durationMinutes) || dto.durationMinutes <= 0) {
      throw badRequest('BAD_REQUEST', 'La duración no es válida');
    }
    const restrictions = this.normalizeRestrictions(dto);
    const ttlHours = this.validateTtl(dto.tokenTtlHours);
    this.validateClientSource(dto);

    if (dto.depositVerified !== true) {
      throw new UnprocessableEntityException(
        safeError(
          'DEPOSIT_NOT_VERIFIED',
          'La solicitud requiere un depósito verificado',
        ),
      );
    }

    const generated = generateBookingToken();
    const expiresAt = new Date(Date.now() + ttlHours * 60 * 60 * 1000);

    return this.serializable(async (transaction) => {
      const client = dto.clientId
        ? await transaction.client.findFirst({
            where: { id: dto.clientId, artistId },
          })
        : await transaction.client.create({
            data: {
              artistId,
              name: dto.client!.name.trim(),
              email: dto.client!.email?.trim() || null,
              phone: dto.client!.phone?.trim() || null,
            },
          });

      if (!client) throw notFound();

      const request = await transaction.bookingRequest.create({
        data: {
          artistId,
          clientId: client.id,
          depositVerifiedAt: new Date(),
          depositVerifiedBy: artistId,
          durationMinutes: dto.durationMinutes,
          status: BookingRequestStatus.PENDING,
          minDate: restrictions.minDate,
          maxDate: restrictions.maxDate,
          allowedWeekdays: restrictions.allowedWeekdays as Prisma.InputJsonValue,
          allowedWindows: restrictions.allowedWindows as Prisma.InputJsonValue,
        },
        include: { client: true },
      });

      await transaction.bookingToken.create({
        data: { requestId: request.id, tokenHash: generated.tokenHash, expiresAt },
      });
      await transaction.auditLog.create({
        data: {
          actorType: 'ADMIN',
          actorId: artistId,
          entityType: 'booking_request',
          entityId: request.id,
          action: 'created',
        },
      });

      return {
        request: this.toResponse(request),
        link: { path: `/r/${generated.token}`, expiresAt: expiresAt.toISOString() },
      };
    });
  }

  async list(
    artistId: string,
    query: ListBookingRequestsDto,
  ): Promise<{
    items: BookingRequestResponse[];
    nextCursor: string | null;
  }> {
    try {
      if (
        query.status !== undefined &&
        !['pending', 'booked', 'cancelled', 'expired', 'closed'].includes(
          query.status,
        )
      ) {
        throw badRequest('BAD_REQUEST', 'El estado no es válido');
      }
      const status = this.statusFromFilter(query.status);
      const cursor = query.cursor ? decodeBookingCursor(query.cursor) : null;
      const where: Prisma.BookingRequestWhereInput = {
        artistId,
        ...(status ? { status } : {}),
        ...(cursor
          ? {
              OR: [
                { createdAt: { lt: cursor.createdAt } },
                { createdAt: cursor.createdAt, id: { lt: cursor.id } },
              ],
            }
          : {}),
      };

      const rows = await this.prisma.bookingRequest.findMany({
        where,
        include: { client: true },
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        take: BOOKING_REQUEST_PAGE_SIZE + 1,
      });
      const hasNextPage = rows.length > BOOKING_REQUEST_PAGE_SIZE;
      const page = hasNextPage ? rows.slice(0, BOOKING_REQUEST_PAGE_SIZE) : rows;
      const last = page.at(-1);

      return {
        items: page.map((row) => this.toResponse(row)),
        nextCursor:
          hasNextPage && last
            ? encodeBookingCursor({ createdAt: last.createdAt, id: last.id })
            : null,
      };
    } catch (error) {
      this.rethrowHttp(error);
      throw serviceUnavailable();
    }
  }

  async detail(
    artistId: string,
    id: string,
  ): Promise<{
    request: BookingRequestResponse;
    currentLink: { status: 'active' | 'expired' | 'revoked' | 'consumed'; expiresAt: string } | null;
    audit: Array<{ action: string; createdAt: string }>;
  }> {
    try {
      const request = await this.prisma.bookingRequest.findFirst({
        where: { id, artistId },
        include: { client: true, tokens: true },
      });
      if (!request) throw notFound();

      const audit = await this.prisma.auditLog.findMany({
        where: {
          entityType: 'booking_request',
          entityId: id,
          actorId: artistId,
          actorType: 'ADMIN',
        },
        orderBy: { createdAt: 'asc' },
        select: { action: true, createdAt: true },
      });

      return {
        request: this.toResponse(request),
        currentLink: this.currentLink(request),
        audit: audit.map((entry) => ({
          action: entry.action,
          createdAt: entry.createdAt.toISOString(),
        })),
      };
    } catch (error) {
      this.rethrowHttp(error);
      throw serviceUnavailable();
    }
  }

  async renew(
    artistId: string,
    id: string,
    dto: RenewBookingTokenDto = {},
  ): Promise<{ request: BookingRequestResponse; link: BookingRequestLink }> {
    const ttlHours = this.validateTtl(dto.tokenTtlHours);
    const generated = generateBookingToken();
    const expiresAt = new Date(Date.now() + ttlHours * 60 * 60 * 1000);

    return this.serializable(async (transaction) => {
      const request = await this.findForLifecycle(transaction, artistId, id);
      if (request.status === BookingRequestStatus.BOOKED) {
        throw new ConflictException(
          safeError('ALREADY_BOOKED', 'La solicitud ya fue reservada'),
        );
      }
      if (
        request.status !== BookingRequestStatus.PENDING &&
        request.status !== BookingRequestStatus.EXPIRED
      ) {
        throw badRequest('BAD_REQUEST', 'La solicitud no puede renovarse');
      }

      await transaction.bookingToken.updateMany({
        where: { requestId: id, revokedAt: null },
        data: { revokedAt: new Date() },
      });
      const updated = await transaction.bookingRequest.update({
        where: { id, artistId },
        data: { status: BookingRequestStatus.PENDING, version: { increment: 1 } },
        include: { client: true },
      });
      await transaction.bookingToken.create({
        data: { requestId: id, tokenHash: generated.tokenHash, expiresAt },
      });
      await transaction.auditLog.create({
        data: {
          actorType: 'ADMIN',
          actorId: artistId,
          entityType: 'booking_request',
          entityId: id,
          action: 'token_renewed',
        },
      });

      return {
        request: this.toResponse(updated),
        link: { path: `/r/${generated.token}`, expiresAt: expiresAt.toISOString() },
      };
    });
  }

  async revoke(artistId: string, id: string): Promise<BookingRequestResponse> {
    return this.transition(artistId, id, BookingRequestStatus.CANCELLED, 'revoked');
  }

  async close(artistId: string, id: string): Promise<BookingRequestResponse> {
    return this.transition(artistId, id, BookingRequestStatus.CLOSED, 'closed');
  }

  async resolvePublic(token: string): Promise<PublicReservationResponse> {
    let record: PublicTokenRecord | null;
    try {
      record = await this.prisma.bookingToken.findUnique({
        where: { tokenHash: hashBookingToken(token) },
        include: {
          request: {
            include: {
              artist: {
                select: {
                  displayName: true,
                  studioSettings: { select: { timezone: true } },
                },
              },
            },
          },
        },
      });
    } catch {
      throw serviceUnavailable();
    }

    if (!record) throw tokenNotFound();

    const request = record.request;
    if (
      record.revokedAt !== null ||
      request.status === BookingRequestStatus.CANCELLED ||
      request.status === BookingRequestStatus.CLOSED
    ) {
      throw tokenRevoked();
    }

    const timezone = request.artist.studioSettings?.timezone;
    if (!timezone) throw serviceUnavailable();

    // A booked request remains safely readable even after its token has been
    // consumed or its original TTL has elapsed. The request state is the
    // source of truth for this already-reserved outcome.
    if (request.status === BookingRequestStatus.BOOKED) {
      return this.toPublicResponse(request, timezone, record.expiresAt, 'booked');
    }

    if (record.consumedAt !== null) {
      throw tokenRevoked();
    }

    const now = new Date();
    if (
      request.status === BookingRequestStatus.EXPIRED ||
      record.expiresAt.getTime() <= now.getTime()
    ) {
      if (
        request.status === BookingRequestStatus.PENDING &&
        record.expiresAt.getTime() <= now.getTime()
      ) {
        await this.expirePublicRequestIfNeeded(request.id, now);
      }
      throw tokenExpired();
    }

    return this.toPublicResponse(request, timezone, record.expiresAt, 'pending');
  }

  private toPublicResponse(
    request: PublicTokenRecord['request'],
    timezone: string,
    expiresAt: Date,
    status: 'pending' | 'booked',
  ): PublicReservationResponse {
    return {
      status,
      artist: { displayName: request.artist.displayName },
      durationMinutes: request.durationMinutes,
      timezone,
      restrictions: {
        minDate: request.minDate?.toISOString().slice(0, 10) ?? null,
        maxDate: request.maxDate?.toISOString().slice(0, 10) ?? null,
        allowedWeekdays: this.jsonArray(request.allowedWeekdays),
        allowedWindows: this.jsonWindows(request.allowedWindows),
      },
      expiresAt: expiresAt.toISOString(),
    };
  }

  private async expirePublicRequestIfNeeded(
    requestId: string,
    now: Date,
  ): Promise<void> {
    try {
      await this.prisma.$transaction(
        async (transaction) => {
          const activeReplacement = await transaction.bookingToken.findFirst({
            where: {
              requestId,
              revokedAt: null,
              consumedAt: null,
              expiresAt: { gt: now },
            },
            select: { id: true },
          });

          if (!activeReplacement) {
            await transaction.bookingRequest.updateMany({
              where: { id: requestId, status: BookingRequestStatus.PENDING },
              data: {
                status: BookingRequestStatus.EXPIRED,
                version: { increment: 1 },
              },
            });
          }
        },
        { isolationLevel: Prisma.TransactionIsolationLevel.Serializable },
      );
    } catch {
      throw serviceUnavailable();
    }
  }

  private async transition(
    artistId: string,
    id: string,
    nextStatus: 'CANCELLED' | 'CLOSED',
    auditAction: 'revoked' | 'closed',
  ): Promise<BookingRequestResponse> {
    return this.serializable(async (transaction) => {
      const request = await this.findForLifecycle(transaction, artistId, id);
      if (request.status === BookingRequestStatus.BOOKED) {
        throw new ConflictException(
          safeError('ALREADY_BOOKED', 'La solicitud ya fue reservada'),
        );
      }

      const alreadyInTarget = request.status === nextStatus;
      if (alreadyInTarget) return this.toResponse(request);
      if (
        request.status !== BookingRequestStatus.PENDING &&
        request.status !== BookingRequestStatus.EXPIRED
      ) {
        throw badRequest('BAD_REQUEST', 'La solicitud no puede cambiar de estado');
      }

      await transaction.bookingToken.updateMany({
        where: { requestId: id, revokedAt: null },
        data: { revokedAt: new Date() },
      });
      const updated = await transaction.bookingRequest.update({
        where: { id, artistId },
        data: { status: nextStatus, version: { increment: 1 } },
        include: { client: true },
      });
      await transaction.auditLog.create({
        data: {
          actorType: 'ADMIN',
          actorId: artistId,
          entityType: 'booking_request',
          entityId: id,
          action: auditAction,
        },
      });
      return this.toResponse(updated);
    });
  }

  private async findForLifecycle(
    transaction: Transaction,
    artistId: string,
    id: string,
  ): Promise<BookingRequestWithClient> {
    const request = await transaction.bookingRequest.findFirst({
      where: { id, artistId },
      include: { client: true },
    });
    if (!request) throw notFound();
    return request;
  }

  private async serializable<T>(operation: (transaction: Transaction) => Promise<T>): Promise<T> {
    for (let attempt = 0; attempt < 3; attempt += 1) {
      try {
        return await this.prisma.$transaction(operation, {
          isolationLevel: Prisma.TransactionIsolationLevel.Serializable,
        });
      } catch (error) {
        if (this.isSerializationConflict(error) && attempt < 2) continue;
        this.rethrowHttp(error);
        throw serviceUnavailable();
      }
    }
    throw serviceUnavailable();
  }

  private isSerializationConflict(error: unknown): boolean {
    return error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2034';
  }

  private rethrowHttp(error: unknown): void {
    if (error instanceof HttpException) throw error;
  }

  private validateClientSource(dto: CreateBookingRequestDto): void {
    const hasClientId = dto.clientId !== undefined && dto.clientId !== null;
    const hasInlineClient = dto.client !== undefined && dto.client !== null;
    if (hasClientId === hasInlineClient) {
      throw badRequest('BAD_REQUEST', 'Debe indicar exactamente un cliente');
    }
    if (hasInlineClient && !dto.client!.name.trim()) {
      throw badRequest('BAD_REQUEST', 'El nombre del cliente es obligatorio');
    }
  }

  private validateTtl(value: number | undefined): number {
    const ttl = value === undefined ? DEFAULT_BOOKING_TOKEN_TTL_HOURS : value;
    if (!Number.isInteger(ttl) || ttl < 1 || ttl > MAX_BOOKING_TOKEN_TTL_HOURS) {
      throw badRequest('BAD_REQUEST', 'El TTL del enlace no es válido');
    }
    return ttl;
  }

  private normalizeRestrictions(dto: CreateBookingRequestDto): NormalizedRestrictions {
    const minDate = dto.minDate ? this.parseDate(dto.minDate) : null;
    const maxDate = dto.maxDate ? this.parseDate(dto.maxDate) : null;
    if (minDate && maxDate && minDate.getTime() > maxDate.getTime()) {
      throw badRequest('INVALID_RESTRICTIONS', 'El rango de fechas no es válido');
    }

    const allowedWeekdays = dto.allowedWeekdays ?? null;
    if (
      allowedWeekdays &&
      (allowedWeekdays.some((day) => !Number.isInteger(day) || day < 0 || day > 6) ||
        new Set(allowedWeekdays).size !== allowedWeekdays.length)
    ) {
      throw badRequest('INVALID_RESTRICTIONS', 'Los días permitidos no son válidos');
    }

    const allowedWindows = dto.allowedWindows ?? null;
    if (
      allowedWindows &&
      allowedWindows.some(
        (window) =>
          !this.isLocalTime(window.startLocal) ||
          !this.isLocalTime(window.endLocal) ||
          window.startLocal >= window.endLocal,
      )
    ) {
      throw badRequest('INVALID_RESTRICTIONS', 'Las franjas permitidas no son válidas');
    }

    return { minDate, maxDate, allowedWeekdays, allowedWindows };
  }

  private parseDate(value: string): Date {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) {
      throw badRequest('INVALID_RESTRICTIONS', 'Las fechas no son válidas');
    }
    const [year, month, day] = value.split('-').map(Number);
    const date = new Date(Date.UTC(year, month - 1, day));
    if (
      date.getUTCFullYear() !== year ||
      date.getUTCMonth() !== month - 1 ||
      date.getUTCDate() !== day
    ) {
      throw badRequest('INVALID_RESTRICTIONS', 'Las fechas no son válidas');
    }
    return date;
  }

  private isLocalTime(value: string): boolean {
    return /^(?:[01]\d|2[0-3]):[0-5]\d$/.test(value);
  }

  private statusFromFilter(status: BookingRequestStatusFilter | undefined): BookingRequestStatus | undefined {
    if (!status) return undefined;
    const mapped: Record<BookingRequestStatusFilter, BookingRequestStatus> = {
      pending: BookingRequestStatus.PENDING,
      booked: BookingRequestStatus.BOOKED,
      cancelled: BookingRequestStatus.CANCELLED,
      expired: BookingRequestStatus.EXPIRED,
      closed: BookingRequestStatus.CLOSED,
    };
    return mapped[status];
  }

  private currentLink(request: BookingRequestWithTokens): {
    status: 'active' | 'expired' | 'revoked' | 'consumed';
    expiresAt: string;
  } | null {
    const active = request.tokens.find(
      (token) =>
        token.revokedAt === null &&
        token.consumedAt === null &&
        token.expiresAt.getTime() > Date.now(),
    );
    if (active) return { status: 'active', expiresAt: active.expiresAt.toISOString() };

    const token = [...request.tokens].sort(
      (left, right) => right.createdAt.getTime() - left.createdAt.getTime(),
    )[0];
    if (!token) return null;
    return {
      status:
        token.revokedAt !== null
          ? 'revoked'
          : token.consumedAt !== null
            ? 'consumed'
            : 'expired',
      expiresAt: token.expiresAt.toISOString(),
    };
  }

  private toResponse(
    request: BookingRequestWithClient,
  ): BookingRequestResponse {
    return {
      id: request.id,
      client: {
        id: request.client.id,
        name: request.client.name,
        email: request.client.email,
        phone: request.client.phone,
      },
      depositVerified: request.depositVerifiedAt !== null,
      durationMinutes: request.durationMinutes,
      status: request.status.toLowerCase() as Lowercase<BookingRequestStatus>,
      minDate: request.minDate?.toISOString().slice(0, 10) ?? null,
      maxDate: request.maxDate?.toISOString().slice(0, 10) ?? null,
      allowedWeekdays: this.jsonArray(request.allowedWeekdays),
      allowedWindows: this.jsonWindows(request.allowedWindows),
      createdAt: request.createdAt.toISOString(),
    };
  }

  private jsonArray(value: Prisma.JsonValue | null): number[] | null {
    return Array.isArray(value) && value.every((entry) => typeof entry === 'number')
      ? value as number[]
      : null;
  }

  private jsonWindows(
    value: Prisma.JsonValue | null,
  ): Array<{ startLocal: string; endLocal: string }> | null {
    if (!Array.isArray(value)) return null;
    const windows = value.filter(
      (entry): entry is { startLocal: string; endLocal: string } =>
        typeof entry === 'object' &&
        entry !== null &&
        'startLocal' in entry &&
        'endLocal' in entry &&
        typeof entry.startLocal === 'string' &&
        typeof entry.endLocal === 'string',
    );
    return windows.length === value.length ? windows : null;
  }
}

