import { randomUUID } from 'node:crypto';

import { Logger } from '@nestjs/common';
import type { NextFunction, Request, Response } from 'express';

export const REQUEST_ID_HEADER = 'X-Request-Id';

export type RequestWithId = Request & { requestId: string };

const SAFE_REQUEST_ID = /^[A-Za-z0-9._:-]{1,128}$/;
const logger = new Logger('HTTP');

export function requestIdMiddleware(
  request: Request,
  response: Response,
  next: NextFunction,
): void {
  const incoming = headerValue(request.headers['x-request-id']);
  const requestId =
    incoming && SAFE_REQUEST_ID.test(incoming) ? incoming : randomUUID();
  (request as RequestWithId).requestId = requestId;
  response.setHeader(REQUEST_ID_HEADER, requestId);

  const startedAt = process.hrtime.bigint();
  response.once('finish', () => {
    const durationMs = Number(process.hrtime.bigint() - startedAt) / 1_000_000;
    logger.log(
      JSON.stringify({
        event: 'http_request',
        requestId,
        method: request.method,
        route: normalizedRoute(request),
        status: response.statusCode,
        durationMs: Math.round(durationMs * 100) / 100,
      }),
    );
  });

  next();
}

export function isSafeRequestId(value: string | undefined): boolean {
  return value !== undefined && SAFE_REQUEST_ID.test(value);
}

function headerValue(value: string | string[] | undefined): string | undefined {
  return Array.isArray(value) ? value[0] : value;
}

function normalizedRoute(request: Request): string {
  const route = request.route?.path;
  if (typeof route === 'string') return route;
  return request.path
    .replace(
      /\/public\/reservations\/[^/]+(?=\/|$)/,
      '/public/reservations/:token',
    )
    .replace(/\/[0-9a-f]{8}-[0-9a-f-]{27,36}(?=\/|$)/gi, '/:id');
}
