import type { SyncConfig } from './sync.constants';

const DEFAULTS: Omit<SyncConfig, 'enabled'> = {
  pollIntervalMs: 5_000,
  batchSize: 10,
  leaseMs: 120_000,
  maxAttempts: 5,
  retryBaseMs: 30_000,
  retryMaxMs: 900_000,
  jitterRatio: 0.2,
};

const MAX_TIMEOUT_MS = 2_147_483_647;

const parseInteger = (
  env: NodeJS.ProcessEnv,
  name: string,
  fallback: number,
  minimum: number,
  maximum: number,
): number => {
  const raw = env[name];
  if (raw === undefined) return fallback;

  const normalized = raw.trim();
  if (!/^\d+$/.test(normalized)) {
    throw new Error(`${name} must be an integer`);
  }

  const value = Number(normalized);
  if (
    !Number.isSafeInteger(value) ||
    value < minimum ||
    value > maximum
  ) {
    throw new Error(`${name} must be between ${minimum} and ${maximum}`);
  }

  return value;
};

const parseBoolean = (
  env: NodeJS.ProcessEnv,
  name: string,
  fallback: boolean,
): boolean => {
  const raw = env[name];
  if (raw === undefined) return fallback;

  const normalized = raw.trim().toLowerCase();
  if (normalized === 'true') return true;
  if (normalized === 'false') return false;

  throw new Error(`${name} must be true or false`);
};

const parseJitterRatio = (
  env: NodeJS.ProcessEnv,
  name: string,
  fallback: number,
): number => {
  const raw = env[name];
  if (raw === undefined) return fallback;

  const value = Number(raw.trim());
  if (!Number.isFinite(value) || value < 0 || value > 1) {
    throw new Error(`${name} must be between 0 and 1`);
  }

  return value;
};

export const readSyncConfig = (
  env: NodeJS.ProcessEnv = process.env,
): SyncConfig => {
  const retryBaseMs = parseInteger(
    env,
    'OUTBOX_RETRY_BASE_MS',
    DEFAULTS.retryBaseMs,
    1,
    MAX_TIMEOUT_MS,
  );
  const retryMaxMs = parseInteger(
    env,
    'OUTBOX_RETRY_MAX_MS',
    DEFAULTS.retryMaxMs,
    1,
    MAX_TIMEOUT_MS,
  );

  if (retryMaxMs < retryBaseMs) {
    throw new Error('OUTBOX_RETRY_MAX_MS must be greater than or equal to OUTBOX_RETRY_BASE_MS');
  }

  return {
    enabled:
      env.NODE_ENV === 'test'
        ? false
        : parseBoolean(env, 'OUTBOX_WORKER_ENABLED', true),
    pollIntervalMs: parseInteger(
      env,
      'OUTBOX_POLL_INTERVAL_MS',
      DEFAULTS.pollIntervalMs,
      1,
      MAX_TIMEOUT_MS,
    ),
    batchSize: parseInteger(
      env,
      'OUTBOX_BATCH_SIZE',
      DEFAULTS.batchSize,
      1,
      1_000,
    ),
    leaseMs: parseInteger(
      env,
      'OUTBOX_LEASE_MS',
      DEFAULTS.leaseMs,
      1,
      MAX_TIMEOUT_MS,
    ),
    maxAttempts: parseInteger(
      env,
      'OUTBOX_MAX_ATTEMPTS',
      DEFAULTS.maxAttempts,
      1,
      100,
    ),
    retryBaseMs,
    retryMaxMs,
    jitterRatio: parseJitterRatio(
      env,
      'OUTBOX_JITTER_RATIO',
      DEFAULTS.jitterRatio,
    ),
  };
};
