export const SYNC_CONFIG = Symbol('SYNC_CONFIG');
export const OUTBOX_EVENT_PROCESSOR = Symbol('OUTBOX_EVENT_PROCESSOR');
export const SYNC_RANDOM = Symbol('SYNC_RANDOM');
export const SCHEDULER_REGISTRY = Symbol('SCHEDULER_REGISTRY');
export const OUTBOX_WORKER_INTERVAL = 'OUTBOX_WORKER_INTERVAL';
export const OUTBOX_CREATE_EVENT = 'appointment.calendar.create';
export const OUTBOX_UPDATE_EVENT = 'appointment.calendar.update';
export const OUTBOX_DELETE_EVENT = 'appointment.calendar.delete';

export type CalendarOutboxOperation = 'create' | 'update' | 'delete';

export type CalendarOutboxEventType =
  | typeof OUTBOX_CREATE_EVENT
  | typeof OUTBOX_UPDATE_EVENT
  | typeof OUTBOX_DELETE_EVENT;

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

export type OutboxEventProcessor = (event: ClaimedOutboxEvent) => Promise<void>;

export type CalendarSyncSuccess =
  | {
      operation: 'create' | 'update';
      appointmentId: string;
      calendarId: string;
      externalEventId: string;
      etag: string | null;
    }
  | {
      operation: 'create';
      effect: 'noop';
      appointmentId: string;
    }
  | {
      operation: 'delete';
      effect: 'deleted';
      appointmentId: string;
    };

export type SchedulerRegistryPort = {
  addInterval(name: string, interval: NodeJS.Timeout): void;
  deleteInterval(name: string): void;
};
