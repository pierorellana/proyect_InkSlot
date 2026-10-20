import { BadRequestException } from '@nestjs/common';

import { RequestIdExceptionFilter } from './request-id.exception-filter';

describe('RequestIdExceptionFilter', () => {
  it('adds the request id without changing the business error', () => {
    const status = jest.fn();
    const json = jest.fn();
    const setHeader = jest.fn();
    const filter = new RequestIdExceptionFilter();
    filter.catch(
      new BadRequestException({
        error: { code: 'BAD_REQUEST', message: 'Datos inválidos' },
      }),
      {
        switchToHttp: () => ({
          getRequest: () => ({ requestId: 'trace-123' }),
          getResponse: () => ({
            setHeader,
            status: (value: number) => {
              status(value);
              return { json };
            },
          }),
        }),
      } as never,
    );

    expect(setHeader).toHaveBeenCalledWith('X-Request-Id', 'trace-123');
    expect(status).toHaveBeenCalledWith(400);
    expect(json).toHaveBeenCalledWith({
      error: {
        code: 'BAD_REQUEST',
        message: 'Datos inválidos',
        requestId: 'trace-123',
      },
    });
  });
});
