import type { Request, Response } from 'express';

import {
  isSafeRequestId,
  requestIdMiddleware,
  REQUEST_ID_HEADER,
} from './request-id.middleware';

describe('requestIdMiddleware', () => {
  it('preserves a safe incoming id and exposes it in the response', () => {
    const responseHeaders = new Map<string, string>();
    const finish = jest.fn();
    const next = jest.fn();
    requestIdMiddleware(
      {
        headers: { 'x-request-id': 'trace-123' },
        method: 'GET',
        path: '/v1/health',
      } as Request,
      {
        setHeader: (name: string, value: string) =>
          responseHeaders.set(name, value),
        once: (_event: string, listener: () => void) => {
          finish.mockImplementation(listener);
          return undefined;
        },
      } as unknown as Response,
      next,
    );

    expect(responseHeaders.get(REQUEST_ID_HEADER)).toBe('trace-123');
    expect(next).toHaveBeenCalledWith();
    finish();
  });

  it('replaces malformed or missing ids with a UUID', () => {
    const responseHeaders = new Map<string, string>();
    requestIdMiddleware(
      {
        headers: { 'x-request-id': 'bad\nvalue' },
        method: 'GET',
        path: '/v1/health',
      } as Request,
      {
        setHeader: (name: string, value: string) =>
          responseHeaders.set(name, value),
        once: jest.fn(),
      } as unknown as Response,
      jest.fn(),
    );

    expect(responseHeaders.get(REQUEST_ID_HEADER)).toMatch(/^[0-9a-f-]{36}$/);
  });

  it('accepts bounded ids and rejects control characters', () => {
    expect(isSafeRequestId('abc_123')).toBe(true);
    expect(isSafeRequestId('a'.repeat(129))).toBe(false);
    expect(isSafeRequestId('trace\n123')).toBe(false);
  });
});
