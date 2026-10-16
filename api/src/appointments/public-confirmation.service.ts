import {
  BadRequestException,
  ConflictException,
  GoneException,
  HttpException,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import {
  AppointmentStatus,
  BookingRequestStatus,
  Prisma,
  SyncStatus,
} from '@prisma/client';
import { createHash } from 'node:crypto';

import { PublicAvailabilityService } from '../availability/public-availability.service';
import { PrismaService } from '../database/prisma.service';
import { hashBookingToken } from '../requests/booking-token';
import { BookingRequestsService } from '../requests/requests.service';
import type { PublicConfirmDto } from './public-confirmation.dto';
import type {
  PublicAppointmentResponse,
  PublicConfirmationResponse,
} from './public-confirmation.types';

const IDEMPOTENCY_TTL_MS = 24 * 60 * 60 * 1000;
const IDEMPOTENCY_SCOPE_PREFIX = 'public-confirmation:v1:';
const MAX_TRANSACTION_ATTEMPTS = 3;

const safeError = (code: string, message: string) => ({
  error: { code, message },
});

const badRequest = (message: string): BadRequestException =>
  new BadRequestException(safeError('BAD_REQUEST', message));

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

const alreadyBooked = (): ConflictException =>
  new ConflictException(
    safeError('ALREADY_BOOKED', 'La solicitud ya fue reservada'),
  );

const idempotencyReused = (): ConflictException =>
  new ConflictException(
    safeError(
      'IDEMPOTENCY_REUSED',
      'La clave de idempotencia ya fue utilizada con otros datos',
    ),
  );

const appointmentNotFound = (): NotFoundException =>
  new NotFoundException(
    safeError('APPOINTMENT_NOT_FOUND', 'La reserva no existe'),
  );

const serviceUnavailable = (): ServiceUnavailableException =>
  new ServiceUnavailableException(
    safeError('SERVICE_UNAVAILABLE', 'No fue posible procesar la solicitud'),
  );

type Transaction = Prisma.TransactionClient;
type StoredIdempotencyKey = Prisma.IdempotencyKeyGetPayload<object>;

@Injectable()
export class PublicConfirmationService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly availability: PublicAvailabilityService,
    private readonly requests: BookingRequestsService,
  ) {}

  async confirm(
    token: string,
    idempotencyKey: string | undefined,
    input: PublicConfirmDto,
  ): Promise<PublicConfirmationResponse> {
    const normalizedKey = this.normalizeIdempotencyKey(idempotencyKey);
    const startAt = this.normalizeStartAt(input?.startAt);
    const requestHash = this.hash(
      JSON.stringify({ startAt: startAt.toISOString() }),
    );
    const tokenHash = hashBookingToken(token);
    const scope = `${IDEMPOTENCY_SCOPE_PREFIX}${tokenHash}`;
    const now = new Date();
    const replay = await this.findReplay(
      scope,
      normalizedKey,
      requestHash,
      now,
    );
    if (replay) return replay;

    const context = await this.requests.resolvePublicAvailabilityContext(token);
    const slot = await this.availability.assertSlotAvailable(token, startAt);
    const response: PublicConfirmationResponse = {
      status: 'confirmed',
      syncStatus: 'pending',
      startAt: slot.startAt.toISOString(),
      endAt: slot.endAt.toISOString(),
      timezone: slot.timezone,
    };

    return this.serializable(async (transaction) => {
      await transaction.$queryRaw(
        Prisma.sql`SELECT id FROM "booking_requests" WHERE id = CAST(${context.requestId} AS uuid) FOR UPDATE`,
      );

      const transactionReplay = await this.findTransactionReplay(
        transaction,
        scope,
        normalizedKey,
        requestHash,
        now,
      );
      if (transactionReplay) return transactionReplay;

      const request = await transaction.bookingRequest.findUnique({
        where: { id: context.requestId },
        select: { id: true, artistId: true, status: true, version: true },
      });
      if (!request) throw tokenNotFound();
      if (request.status === BookingRequestStatus.BOOKED) {
        throw alreadyBooked();
      }
      if (request.status !== BookingRequestStatus.PENDING) {
        throw tokenRevoked();
      }

      const bookingToken = await transaction.bookingToken.findUnique({
        where: { tokenHash },
        select: {
          id: true,
          requestId: true,
          expiresAt: true,
          revokedAt: true,
          consumedAt: true,
        },
      });
      this.assertTokenForTransaction(bookingToken, context.requestId, now);

      const appointment = await transaction.appointment.create({
        data: {
          requestId: request.id,
          artistId: request.artistId,
          startAt: slot.startAt,
          endAt: slot.endAt,
          status: AppointmentStatus.CONFIRMED,
          syncStatus: SyncStatus.PENDING,
        },
      });

      await transaction.bookingRequest.update({
        where: { id: request.id },
        data: {
          status: BookingRequestStatus.BOOKED,
          version: { increment: 1 },
        },
      });
      await transaction.bookingToken.update({
        where: { id: bookingToken.id },
        data: { consumedAt: now },
      });
      await transaction.outboxEvent.create({
        data: {
          aggregateId: appointment.id,
          type: 'appointment.calendar.create',
          payload: { appointmentId: appointment.id, operation: 'create' },
        },
      });
      await transaction.idempotencyKey.create({
        data: {
          keyHash: normalizedKey.keyHash,
          scope,
          requestHash,
          responseCode: 201,
          responseBody: response as unknown as Prisma.InputJsonValue,
          createdAt: now,
          expiresAt: new Date(now.getTime() + IDEMPOTENCY_TTL_MS),
        },
      });

      return response;
    });
  }

  async getAppointment(token: string): Promise<PublicAppointmentResponse> {
    const context = await this.requests.resolvePublicAppointmentContext(token);
    const appointment = await this.prisma.appointment.findUnique({
      where: { requestId: context.requestId },
      select: {
        status: true,
        syncStatus: true,
        startAt: true,
        endAt: true,
      },
    });
    if (!appointment) throw appointmentNotFound();

    return {
      status: appointment.status.toLowerCase() as 'confirmed',
      syncStatus: appointment.syncStatus.toLowerCase() as
        'pending' | 'synced' | 'failed',
      startAt: appointment.startAt.toISOString(),
      endAt: appointment.endAt.toISOString(),
      timezone: context.timezone,
    };
  }

  private normalizeIdempotencyKey(value: string | undefined): {
    keyHash: string;
  } {
    if (
      typeof value !== 'string' ||
      value.length < 1 ||
      value.length > 128 ||
      !/^[\x20-\x7e]+$/.test(value)
    ) {
      throw badRequest('La clave de idempotencia debe ser imprimible y válida');
    }
    return { keyHash: this.hash(value) };
  }

  private normalizeStartAt(value: string | undefined): Date {
    if (
      typeof value !== 'string' ||
      !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/.test(value)
    ) {
      throw badRequest('La fecha de inicio debe estar en UTC');
    }
    const date = new Date(value);
    if (!Number.isFinite(date.getTime()) || date.toISOString() !== value) {
      throw badRequest('La fecha de inicio no es válida');
    }
    return date;
  }

  private hash(value: string): string {
    return createHash('sha256').update(value, 'utf8').digest('hex');
  }

  private async findReplay(
    scope: string,
    normalizedKey: { keyHash: string },
    requestHash: string,
    now: Date,
  ): Promise<PublicConfirmationResponse | null> {
    try {
      const stored = await this.prisma.idempotencyKey.findUnique({
        where: { scope_keyHash: { scope, keyHash: normalizedKey.keyHash } },
      });
      if (!stored || stored.expiresAt.getTime() <= now.getTime()) return null;
      if (stored.requestHash !== requestHash) throw idempotencyReused();
      return this.readStoredResponse(stored);
    } catch (error) {
      if (error instanceof HttpException) throw error;
      throw serviceUnavailable();
    }
  }

  private async findTransactionReplay(
    transaction: Transaction,
    scope: string,
    normalizedKey: { keyHash: string },
    requestHash: string,
    now: Date,
  ): Promise<PublicConfirmationResponse | null> {
    const stored = await transaction.idempotencyKey.findUnique({
      where: { scope_keyHash: { scope, keyHash: normalizedKey.keyHash } },
    });
    if (!stored) return null;
    if (stored.expiresAt.getTime() <= now.getTime()) {
      await transaction.idempotencyKey.delete({ where: { id: stored.id } });
      return null;
    }
    if (stored.requestHash !== requestHash) throw idempotencyReused();
    return this.readStoredResponse(stored);
  }

  private readStoredResponse(
    stored: StoredIdempotencyKey,
  ): PublicConfirmationResponse {
    return stored.responseBody as unknown as PublicConfirmationResponse;
  }

  private assertTokenForTransaction(
    token: {
      id: string;
      requestId: string;
      expiresAt: Date;
      revokedAt: Date | null;
      consumedAt: Date | null;
    } | null,
    requestId: string,
    now: Date,
  ): asserts token is NonNullable<typeof token> {
    if (!token || token.requestId !== requestId) throw tokenNotFound();
    if (token.revokedAt !== null || token.consumedAt !== null) {
      throw tokenRevoked();
    }
    if (token.expiresAt.getTime() <= now.getTime()) throw tokenExpired();
  }

  private async serializable<T>(
    operation: (transaction: Transaction) => Promise<T>,
  ): Promise<T> {
    for (let attempt = 0; attempt < MAX_TRANSACTION_ATTEMPTS; attempt += 1) {
      try {
        return await this.prisma.$transaction(operation, {
          isolationLevel: Prisma.TransactionIsolationLevel.Serializable,
          maxWait: 5_000,
          timeout: 10_000,
        });
      } catch (error) {
        if (
          this.isRetryableConflict(error) &&
          attempt < MAX_TRANSACTION_ATTEMPTS - 1
        ) {
          continue;
        }
        if (error instanceof HttpException) throw error;
        if (this.isExclusionConflict(error)) {
          throw new ConflictException(
            safeError(
              'SLOT_UNAVAILABLE',
              'El horario seleccionado ya no está disponible',
            ),
          );
        }
        if (this.isUniqueConflict(error)) throw alreadyBooked();
        throw serviceUnavailable();
      }
    }
    throw serviceUnavailable();
  }

  private isRetryableConflict(error: unknown): boolean {
    return this.errorCodes(error).some(
      (code) => code === 'P2034' || code === '40001' || code === '40P01',
    );
  }

  private isExclusionConflict(error: unknown): boolean {
    return this.errorCodes(error).includes('23P01');
  }

  private isUniqueConflict(error: unknown): boolean {
    return this.errorCodes(error).some(
      (code) => code === 'P2002' || code === '23505',
    );
  }

  private errorCodes(error: unknown): string[] {
    const values: unknown[] = [];
    let current: unknown = error;
    for (let depth = 0; depth < 3 && current; depth += 1) {
      values.push(current);
      current = this.readProperty(current, 'cause');
    }

    return values.flatMap((value) => {
      if (typeof value !== 'object' || value === null) return [];
      const record = value as Record<string, unknown>;
      const meta = record.meta;
      const metaCode =
        typeof meta === 'object' && meta !== null
          ? (meta as Record<string, unknown>).code
          : undefined;
      return [record.code, record.sqlState, metaCode].filter(
        (code): code is string => typeof code === 'string',
      );
    });
  }

  private readProperty(value: unknown, property: string): unknown {
    if (typeof value !== 'object' || value === null) return undefined;
    return (value as Record<string, unknown>)[property];
  }
}
