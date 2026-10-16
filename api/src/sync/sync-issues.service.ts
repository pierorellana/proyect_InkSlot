import { Inject, Injectable, Optional } from '@nestjs/common';
import {
  CalendarConnectionStatus,
  OutboxStatus,
  Prisma,
  SyncIssueStatus,
  SyncStatus,
} from '@prisma/client';

import { PrismaService } from '../database/prisma.service';
import { OUTBOX_CREATE_EVENT, SYNC_RANDOM } from './sync.constants';
import type { CalendarSyncSuccess } from './calendar-sync.service';
import type {
  ClaimedOutboxEvent,
  SyncConfig,
  SyncFailure,
} from './sync.constants';

const SAFE_MESSAGES: Record<SyncFailure['code'], string> = {
  CALENDAR_REAUTH_REQUIRED:
    'La conexión de Google requiere autorización nuevamente',
  CALENDAR_UNAVAILABLE:
    'No fue posible sincronizar el evento con Google Calendar',
  APPOINTMENT_NOT_FOUND: 'La reserva no existe',
  OUTBOX_PAYLOAD_INVALID:
    'El evento de sincronización no tiene un payload válido',
  SYNC_ATTEMPTS_EXHAUSTED: 'Se agotaron los intentos de sincronización',
};

@Injectable()
export class SyncIssuesService {
  constructor(
    private readonly prisma: PrismaService,
    @Optional()
    @Inject(SYNC_RANDOM)
    private readonly random?: () => number,
  ) {}

  async finalizeSuccess(
    outboxId: string,
    success: CalendarSyncSuccess,
  ): Promise<void> {
    const syncedAt = new Date();

    try {
      await this.prisma.$transaction((transaction) =>
        this.persistSuccess(transaction, outboxId, success, syncedAt, true),
      );
    } catch (error) {
      if (!this.isUniqueConflict(error)) throw error;

      await this.prisma.$transaction(async (transaction) => {
        const existing = await transaction.calendarEvent.findUnique({
          where: { appointmentId: success.appointmentId },
          select: { appointmentId: true },
        });
        if (!existing) throw error;

        await this.persistSuccess(
          transaction,
          outboxId,
          success,
          syncedAt,
          false,
        );
      });
    }
  }

  async finalizeFailure(
    event: ClaimedOutboxEvent,
    failure: SyncFailure,
    config: SyncConfig,
  ): Promise<void> {
    const exhausted = failure.retryable && event.attempts >= config.maxAttempts;
    const retry = failure.retryable && !exhausted;
    const issueCode = exhausted ? 'SYNC_ATTEMPTS_EXHAUSTED' : failure.code;
    const message = SAFE_MESSAGES[issueCode];
    const attemptedAt = new Date();
    const nextAttemptAt = retry
      ? new Date(
          attemptedAt.getTime() + this.retryDelay(event.attempts, config),
        )
      : null;

    await this.prisma.$transaction(async (transaction) => {
      await transaction.outboxEvent.update({
        where: { id: event.id },
        data: {
          status: retry ? OutboxStatus.PENDING : OutboxStatus.FAILED,
          nextAttemptAt,
        },
      });

      const appointment = await transaction.appointment.findUnique({
        where: { id: event.aggregateId },
        select: { artistId: true },
      });
      if (!appointment) return;

      await transaction.appointment.update({
        where: { id: event.aggregateId },
        data: { syncStatus: retry ? SyncStatus.PENDING : SyncStatus.FAILED },
      });

      if (failure.code === 'CALENDAR_REAUTH_REQUIRED') {
        await transaction.calendarConnection.updateMany({
          where: { artistId: appointment.artistId },
          data: { status: CalendarConnectionStatus.NEEDS_RECONNECT },
        });
      }

      await this.upsertOpenIssue(transaction, {
        appointmentId: event.aggregateId,
        operation: OUTBOX_CREATE_EVENT,
        code: issueCode,
        message,
        lastAttemptAt: attemptedAt,
      });
    });
  }

  private async persistSuccess(
    transaction: Prisma.TransactionClient,
    outboxId: string,
    success: CalendarSyncSuccess,
    syncedAt: Date,
    createCalendarEvent: boolean,
  ): Promise<void> {
    if (createCalendarEvent) {
      await transaction.calendarEvent.create({
        data: {
          appointmentId: success.appointmentId,
          calendarId: success.calendarId,
          externalEventId: success.externalEventId,
          etag: success.etag,
          lastSyncedAt: syncedAt,
        },
      });
    }

    await transaction.appointment.update({
      where: { id: success.appointmentId },
      data: { syncStatus: SyncStatus.SYNCED },
    });
    await transaction.outboxEvent.update({
      where: { id: outboxId },
      data: { status: OutboxStatus.COMPLETED, nextAttemptAt: null },
    });
    await transaction.syncIssue.updateMany({
      where: {
        appointmentId: success.appointmentId,
        operation: OUTBOX_CREATE_EVENT,
        status: SyncIssueStatus.OPEN,
      },
      data: { status: SyncIssueStatus.RESOLVED },
    });
  }

  private async upsertOpenIssue(
    transaction: Prisma.TransactionClient,
    issue: {
      appointmentId: string;
      operation: string;
      code: string;
      message: string;
      lastAttemptAt: Date;
    },
  ): Promise<void> {
    const openIssue = await transaction.syncIssue.findFirst({
      where: {
        appointmentId: issue.appointmentId,
        operation: issue.operation,
        status: SyncIssueStatus.OPEN,
      },
      select: { id: true },
    });

    if (openIssue) {
      await transaction.syncIssue.update({
        where: { id: openIssue.id },
        data: {
          code: issue.code,
          messageSafe: issue.message,
          lastAttemptAt: issue.lastAttemptAt,
        },
      });
      return;
    }

    await transaction.syncIssue.create({
      data: {
        appointmentId: issue.appointmentId,
        operation: issue.operation,
        code: issue.code,
        messageSafe: issue.message,
        status: SyncIssueStatus.OPEN,
        lastAttemptAt: issue.lastAttemptAt,
      },
    });
  }

  private retryDelay(attempts: number, config: SyncConfig): number {
    const exponential = config.retryBaseMs * 2 ** Math.max(0, attempts - 1);
    const capped = Math.min(config.retryMaxMs, exponential);
    const random = Math.min(1, Math.max(0, this.random?.() ?? Math.random()));
    const factor = 1 - config.jitterRatio + random * config.jitterRatio * 2;
    return Math.round(capped * factor);
  }

  private isUniqueConflict(error: unknown): boolean {
    let current: unknown = error;
    for (let depth = 0; depth < 3 && current; depth += 1) {
      if (typeof current !== 'object' || current === null) return false;
      const record = current as Record<string, unknown>;
      const meta = record.meta;
      const metaCode =
        typeof meta === 'object' && meta !== null
          ? (meta as Record<string, unknown>).code
          : undefined;
      if (
        record.code === 'P2002' ||
        record.sqlState === '23505' ||
        metaCode === '23505'
      ) {
        return true;
      }
      current = record.cause;
    }
    return false;
  }
}
