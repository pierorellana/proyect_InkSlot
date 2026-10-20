import { ForbiddenException } from '@nestjs/common';
import type { NextFunction, Request, Response } from 'express';

import { isRequestOriginAllowed, type SecurityConfig } from './security.config';

const SAFE_METHODS = new Set(['GET', 'HEAD', 'OPTIONS']);

export function securityHeadersMiddleware(
  config: SecurityConfig,
): (request: Request, response: Response, next: NextFunction) => void {
  return (_request, response, next) => {
    response.setHeader('X-Content-Type-Options', 'nosniff');
    response.setHeader('X-Frame-Options', 'DENY');
    response.setHeader('Referrer-Policy', 'strict-origin-when-cross-origin');
    response.setHeader(
      'Permissions-Policy',
      'camera=(), microphone=(), geolocation=()',
    );
    response.setHeader(
      'Content-Security-Policy',
      "default-src 'none'; frame-ancestors 'none'; base-uri 'none'",
    );
    if (config.nodeEnv === 'production') {
      response.setHeader(
        'Strict-Transport-Security',
        'max-age=31536000; includeSubDomains',
      );
    }
    next();
  };
}

export function originValidationMiddleware(
  config: SecurityConfig,
): (request: Request, response: Response, next: NextFunction) => void {
  return (request, _response, next) => {
    if (!requiresOriginValidation(request)) {
      next();
      return;
    }

    const origin = headerValue(request.headers.origin);
    const referer = headerValue(request.headers.referer);
    if (isRequestOriginAllowed(origin, referer, config)) {
      next();
      return;
    }

    next(
      new ForbiddenException({
        error: {
          code: 'CSRF_ORIGIN_INVALID',
          message: 'El origen de la solicitud no está permitido',
        },
      }),
    );
  };
}

export function requiresOriginValidation(
  request: Pick<Request, 'method' | 'path'>,
): boolean {
  if (SAFE_METHODS.has(request.method.toUpperCase())) return false;
  const path = request.path.replace(/^\/v1(?=\/|$)/, '');
  return (
    path.startsWith('/admin/') ||
    path === '/auth/login' ||
    path === '/auth/logout'
  );
}

function headerValue(value: string | string[] | undefined): string | undefined {
  return Array.isArray(value) ? value[0] : value;
}
