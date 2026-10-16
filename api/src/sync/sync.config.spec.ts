import { readSyncConfig } from './sync.config';

describe('SyncConfig', () => {
  it('uses the local defaults outside test mode', () => {
    expect(readSyncConfig({ NODE_ENV: 'development' })).toEqual({
      enabled: true,
      pollIntervalMs: 5_000,
      batchSize: 10,
      leaseMs: 120_000,
      maxAttempts: 5,
      retryBaseMs: 30_000,
      retryMaxMs: 900_000,
      jitterRatio: 0.2,
    });
  });

  it('disables the worker in test mode even when explicitly enabled', () => {
    expect(
      readSyncConfig({
        NODE_ENV: 'test',
        OUTBOX_WORKER_ENABLED: 'true',
      }).enabled,
    ).toBe(false);
  });

  it('honors an explicit disabled flag outside test mode', () => {
    expect(
      readSyncConfig({
        NODE_ENV: 'development',
        OUTBOX_WORKER_ENABLED: 'false',
      }).enabled,
    ).toBe(false);
  });

  it('parses configured integer and jitter values', () => {
    expect(
      readSyncConfig({
        NODE_ENV: 'development',
        OUTBOX_POLL_INTERVAL_MS: '2500',
        OUTBOX_BATCH_SIZE: '25',
        OUTBOX_LEASE_MS: '60000',
        OUTBOX_MAX_ATTEMPTS: '7',
        OUTBOX_RETRY_BASE_MS: '1000',
        OUTBOX_RETRY_MAX_MS: '10000',
        OUTBOX_JITTER_RATIO: '0.35',
      }),
    ).toEqual({
      enabled: true,
      pollIntervalMs: 2500,
      batchSize: 25,
      leaseMs: 60000,
      maxAttempts: 7,
      retryBaseMs: 1000,
      retryMaxMs: 10000,
      jitterRatio: 0.35,
    });
  });

  it.each([
    ['OUTBOX_POLL_INTERVAL_MS', '0'],
    ['OUTBOX_BATCH_SIZE', '1.5'],
    ['OUTBOX_LEASE_MS', '-1'],
    ['OUTBOX_MAX_ATTEMPTS', '0'],
    ['OUTBOX_RETRY_BASE_MS', 'nope'],
    ['OUTBOX_RETRY_MAX_MS', 'Infinity'],
  ])('rejects an invalid integer for %s', (name, value) => {
    expect(() =>
      readSyncConfig({ NODE_ENV: 'development', [name]: value }),
    ).toThrow(name);
  });

  it('rejects a retry cap below its base', () => {
    expect(() =>
      readSyncConfig({
        NODE_ENV: 'development',
        OUTBOX_RETRY_BASE_MS: '10000',
        OUTBOX_RETRY_MAX_MS: '9999',
      }),
    ).toThrow('OUTBOX_RETRY_MAX_MS');
  });

  it.each(['-0.1', '1.1', 'not-a-number'])(
    'rejects jitter ratio %s outside the inclusive range',
    (value) => {
      expect(() =>
        readSyncConfig({ NODE_ENV: 'development', OUTBOX_JITTER_RATIO: value }),
      ).toThrow('OUTBOX_JITTER_RATIO');
    },
  );

  it('rejects an unknown boolean spelling', () => {
    expect(() =>
      readSyncConfig({
        NODE_ENV: 'development',
        OUTBOX_WORKER_ENABLED: 'yes',
      }),
    ).toThrow('OUTBOX_WORKER_ENABLED');
  });
});
