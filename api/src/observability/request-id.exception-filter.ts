import {
  ArgumentsHost,
  Catch,
  type ExceptionFilter,
  HttpException,
} from '@nestjs/common';
import type { Request, Response } from 'express';

import { type RequestWithId, REQUEST_ID_HEADER } from './request-id.middleware';

@Catch()
export class RequestIdExceptionFilter implements ExceptionFilter {
  catch(exception: unknown, host: ArgumentsHost): void {
    const http = host.switchToHttp();
    const request = http.getRequest<Request>() as RequestWithId;
    const response = http.getResponse<Response>();
    const status =
      exception instanceof HttpException ? exception.getStatus() : 500;
    const requestId = request.requestId;
    const body =
      exception instanceof HttpException ? exception.getResponse() : undefined;

    response.setHeader(REQUEST_ID_HEADER, requestId);
    response.status(status).json(withRequestId(body, status, requestId));
  }
}

function withRequestId(
  body: unknown,
  status: number,
  requestId: string,
): Record<string, unknown> {
  if (isRecord(body) && isRecord(body.error)) {
    return {
      ...body,
      error: { ...body.error, requestId },
    };
  }

  if (
    isRecord(body) &&
    body.status === 'error' &&
    typeof body.service === 'string'
  ) {
    return { ...body, requestId };
  }

  const rawMessage = isRecord(body) ? body.message : body;
  const message =
    typeof rawMessage === 'string' ? rawMessage : defaultMessage(status);
  return {
    error: {
      code: defaultCode(status),
      message,
      requestId,
    },
  };
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function defaultCode(status: number): string {
  return (
    (
      {
        400: 'BAD_REQUEST',
        401: 'AUTH_INVALID',
        403: 'FORBIDDEN',
        404: 'NOT_FOUND',
        409: 'CONFLICT',
        410: 'GONE',
        422: 'UNPROCESSABLE_ENTITY',
        429: 'RATE_LIMITED',
        503: 'SERVICE_UNAVAILABLE',
      } as Record<number, string>
    )[status] ?? 'INTERNAL_SERVER_ERROR'
  );
}

function defaultMessage(status: number): string {
  if (status >= 500) return 'No se pudo completar la solicitud.';
  return 'La solicitud no es válida.';
}
