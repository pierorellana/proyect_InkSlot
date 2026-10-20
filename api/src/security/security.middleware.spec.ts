import { ForbiddenException } from '@nestjs/common';
import type { Request, Response } from 'express';

import { readSecurityConfig } from './security.config';
import {
  originValidationMiddleware,
  requiresOriginValidation,
  securityHeadersMiddleware,
} from './security.middleware';

const production = readSecurityConfig({
  NODE_ENV: 'production',
  CORS_ALLOWED_ORIGINS: 'https://studio.example',
});

describe('security middleware', () => {
  it('requires origins for mutating admin and auth routes only', () => {
    expect(
      requiresOriginValidation({ method: 'POST', path: '/v1/admin/blocks' }),
    ).toBe(true);
    expect(
      requiresOriginValidation({ method: 'POST', path: '/v1/auth/login' }),
    ).toBe(true);
    expect(
      requiresOriginValidation({ method: 'GET', path: '/v1/admin/agenda' }),
    ).toBe(false);
    expect(
      requiresOriginValidation({
        method: 'POST',
        path: '/v1/public/reservations/token/confirm',
      }),
    ).toBe(false);
  });

  it('rejects a production mutation from an unknown origin', () => {
    const next = jest.fn();
    originValidationMiddleware(production)(
      {
        method: 'POST',
        path: '/v1/admin/blocks',
        headers: { origin: 'https://evil.example' },
      } as Request,
      {} as Response,
      next,
    );

    expect(next).toHaveBeenCalledWith(expect.any(ForbiddenException));
  });

  it('accepts a configured origin and exposes safe response headers', () => {
    const next = jest.fn();
    originValidationMiddleware(production)(
      {
        method: 'POST',
        path: '/v1/admin/blocks',
        headers: { origin: 'https://studio.example' },
      } as Request,
      {} as Response,
      next,
    );
    expect(next).toHaveBeenCalledWith();

    const headers = new Map<string, string>();
    securityHeadersMiddleware(production)(
      {} as Request,
      {
        setHeader: (name: string, value: string) => headers.set(name, value),
      } as unknown as Response,
      jest.fn(),
    );
    expect(headers.get('X-Content-Type-Options')).toBe('nosniff');
    expect(headers.get('X-Frame-Options')).toBe('DENY');
    expect(headers.get('Strict-Transport-Security')).toContain('max-age=');
  });
});
