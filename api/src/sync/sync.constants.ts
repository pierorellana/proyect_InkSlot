export const SYNC_CONFIG = Symbol('SYNC_CONFIG');
export const OUTBOX_EVENT_PROCESSOR = Symbol('OUTBOX_EVENT_PROCESSOR');
export const OUTBOX_WORKER_INTERVAL = 'OUTBOX_WORKER_INTERVAL';
export const OUTBOX_CREATE_EVENT = 'appointment.calendar.create';

export type SyncConfig = {
  enabled: boolean;
  pollIntervalMs: number;
  batchSize: number;
  leaseMs: number;
  maxAttempts: number;
  retryBaseMs: number;
  retryMaxMs: number;
  jitterRatio: number;
};

export type ClaimedOutboxEvent = {
  id: string;
  aggregateId: string;
  type: string;
  payload: unknown;
  attempts: number;
};

export type SyncFailureCode =
  | 'CALENDAR_REAUTH_REQUIRED'
  | 'CALENDAR_UNAVAILABLE'
  | 'APPOINTMENT_NOT_FOUND'
  | 'OUTBOX_PAYLOAD_INVALID'
  | 'SYNC_ATTEMPTS_EXHAUSTED';

export type SyncFailure = {
  code: SyncFailureCode;
  message: string;
  retryable: boolean;
};

export type OutboxEventProcessor = (
  event: ClaimedOutboxEvent,
) => Promise<void>;
