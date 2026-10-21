import { HttpException, ValidationPipe } from '@nestjs/common';
import { BookingRequestStatus, Prisma } from '@prisma/client';
import type { Client } from '@prisma/client';

import { PrismaService } from '../database/prisma.service';
import * as tokens from './booking-token';
import { CreateBookingRequestDto, RenewBookingTokenDto } from './requests.dto';
import { BookingRequestsService } from './requests.service';

type Row = Prisma.BookingRequestGetPayload<{
  include: { client: true; tokens: true };
}>;

describe('BookingRequestsService administration', () => {
  const artistId = '11111111-1111-4111-8111-111111111111';
  const id = '22222222-2222-4222-8222-222222222222';
  const now = new Date('2026-10-15T12:00:00.000Z');
  const client: Client = {
    id: '33333333-3333-4333-8333-333333333333',
    artistId,
    name: 'Cliente',
    email: null,
    phone: '+593000000000',
    contactChannel: null,
    contactValue: null,
    createdAt: now,
  };
  const rawToken = 'unit-test-opaque-secret';
  const tokenHash = 'a'.repeat(64);
  let row: Row;
  const tx = {
    client: {
      create: jest.fn<Promise<Client>, [Prisma.ClientCreateArgs]>(),
      updateMany: jest.fn<
        Promise<Prisma.BatchPayload>,
        [Prisma.ClientUpdateManyArgs]
      >(),
      findFirst: jest.fn<
        Promise<Client | null>,
        [Prisma.ClientFindFirstArgs]
      >(),
    },
    bookingRequest: {
      create: jest.fn<Promise<Row>, [Prisma.BookingRequestCreateArgs]>(),
      findFirst: jest.fn<
        Promise<Row | null>,
        [Prisma.BookingRequestFindFirstArgs]
      >(),
      findMany: jest.fn<Promise<Row[]>, [Prisma.BookingRequestFindManyArgs]>(),
      updateMany: jest.fn<
        Promise<Prisma.BatchPayload>,
        [Prisma.BookingRequestUpdateManyArgs]
      >(),
      update: jest.fn<Promise<Row>, [Prisma.BookingRequestUpdateArgs]>(),
    },
    bookingToken: {
      create: jest.fn<
        Promise<Row['tokens'][number]>,
        [Prisma.BookingTokenCreateArgs]
      >(),
      updateMany: jest.fn<
        Promise<Prisma.BatchPayload>,
        [Prisma.BookingTokenUpdateManyArgs]
      >(),
    },
    auditLog: {
      create: jest.fn<Promise<unknown>, [Prisma.AuditLogCreateArgs]>(),
      findMany: jest.fn<
        Promise<Prisma.AuditLogGetPayload<object>[]>,
        [Prisma.AuditLogFindManyArgs]
      >(),
    },
  };
  const prisma = {
    ...tx,
    $transaction: jest.fn<
      Promise<unknown>,
      [(connection: Prisma.TransactionClient) => Promise<unknown>, object]
    >(),
  };
  let service: BookingRequestsService;
  const input = (): CreateBookingRequestDto => ({
    client: { name: 'Cliente', phone: client.phone! },
    depositVerified: true,
    durationMinutes: 180,
  });

  beforeEach(() => {
    jest.resetAllMocks();
    jest.useFakeTimers().setSystemTime(now);
    jest
      .spyOn(tokens, 'generateBookingToken')
      .mockReturnValue({ token: rawToken, tokenHash });
    row = {
      id,
      artistId,
      clientId: client.id,
      client,
      depositVerifiedAt: now,
      depositVerifiedBy: artistId,
      paymentReference: null,
      durationMinutes: 180,
      status: BookingRequestStatus.PENDING,
      minDate: null,
      maxDate: null,
      allowedWeekdays: null,
      allowedWindows: null,
      createdAt: now,
      version: 1,
      tokens: [
        {
          id: '44444444-4444-4444-8444-444444444444',
          requestId: id,
          tokenHash,
          expiresAt: new Date('2026-10-17T12:00:00.000Z'),
          revokedAt: null,
          consumedAt: null,
          createdAt: now,
        },
      ],
    };
    tx.client.create.mockResolvedValue(client);
    tx.client.updateMany.mockResolvedValue({ count: 1 });
    tx.client.findFirst.mockResolvedValue(client);
    tx.bookingRequest.create.mockImplementation(() => Promise.resolve(row));
    tx.bookingRequest.findFirst.mockImplementation(() => Promise.resolve(row));
    tx.bookingRequest.findMany.mockResolvedValue([row]);
    tx.bookingRequest.updateMany.mockResolvedValue({ count: 0 });
    tx.bookingRequest.update.mockImplementation((args) => {
      const status = args.data.status;
      return Promise.resolve({
        ...row,
        status: typeof status === 'string' ? status : row.status,
      });
    });
    tx.bookingToken.create.mockResolvedValue(row.tokens[0]);
    tx.bookingToken.updateMany.mockResolvedValue({ count: 1 });
    tx.auditLog.create.mockResolvedValue({});
    tx.auditLog.findMany.mockResolvedValue([]);
    prisma.$transaction.mockImplementation((operation) =>
      operation(tx as unknown as Prisma.TransactionClient),
    );
    service = new BookingRequestsService(prisma as unknown as PrismaService);
  });

  afterEach(() => {
    jest.restoreAllMocks();
    jest.useRealTimers();
  });

  async function expectCode(
    operation: Promise<unknown>,
    code: string,
    status: number,
  ) {
    const error: unknown = await operation.catch((failure: unknown) => failure);
    expect(error).toBeInstanceOf(HttpException);
    if (!(error instanceof HttpException))
      throw new Error('Expected safe HTTP error');
    expect(error.getStatus()).toBe(status);
    const response = error.getResponse();
    if (
      typeof response !== 'object' ||
      response === null ||
      !('error' in response)
    ) {
      throw new Error('Expected safe error envelope');
    }
    const envelope = response as {
      error: { code?: unknown; message?: unknown };
    };
    expect(envelope.error.code).toBe(code);
    expect(typeof envelope.error.message).toBe('string');
    expect(JSON.stringify(response)).not.toContain(rawToken);
    expect(JSON.stringify(response)).not.toContain(tokenHash);
  }

  it('creates inline client, verified request, hash and safe audit in one transaction', async () => {
    const result = await service.create(artistId, input());
    expect(prisma.$transaction).toHaveBeenCalledWith(expect.any(Function), {
      isolationLevel: 'Serializable',
    });
    expect(tx.client.create).toHaveBeenCalledWith({
      data: {
        artistId,
        name: 'Cliente',
        email: null,
        phone: client.phone,
        contactChannel: null,
        contactValue: null,
      },
    });
    const requestCreate = tx.bookingRequest.create.mock.calls[0]?.[0];
    expect(requestCreate?.data.artistId).toBe(artistId);
    expect(requestCreate?.data.clientId).toBe(client.id);
    expect(requestCreate?.data.depositVerifiedBy).toBe(artistId);
    expect(requestCreate?.data.depositVerifiedAt).toEqual(now);
    expect(requestCreate?.data.status).toBe('PENDING');
    expect(requestCreate?.data.paymentReference).toBeNull();
    expect(tx.bookingToken.create).toHaveBeenCalledWith({
      data: {
        requestId: id,
        tokenHash,
        expiresAt: new Date('2026-10-17T12:00:00.000Z'),
      },
    });
    expect(tx.auditLog.create).toHaveBeenCalledWith({
      data: {
        actorType: 'ADMIN',
        actorId: artistId,
        entityType: 'booking_request',
        entityId: id,
        action: 'created',
      },
    });
    expect(result.link).toEqual({
      path: `/r/${rawToken}`,
      expiresAt: '2026-10-17T12:00:00.000Z',
    });
    expect(result.request.client).toEqual({
      id: client.id,
      name: client.name,
      email: null,
      phone: client.phone,
      contactChannel: null,
      contactValue: null,
    });
    expect(result.request.paymentReference).toBeNull();
    const writes = JSON.stringify([
      tx.client.create.mock.calls,
      tx.bookingRequest.create.mock.calls,
      tx.bookingToken.create.mock.calls,
      tx.auditLog.create.mock.calls,
    ]);
    expect(writes).not.toContain(rawToken);
    expect(JSON.stringify(tx.auditLog.create.mock.calls)).not.toContain(
      tokenHash,
    );
  });

  it('resolves an existing client only under authenticated artist ownership', async () => {
    await service.create(artistId, {
      clientId: client.id,
      depositVerified: true,
      durationMinutes: 60,
    });
    expect(tx.client.findFirst).toHaveBeenCalledWith({
      where: { id: client.id, artistId },
    });
    expect(tx.client.create).not.toHaveBeenCalled();
  });

  it('persists contact metadata and payment reference with normalized legacy fields', async () => {
    row.client = {
      ...client,
      email: null,
      phone: null,
      contactChannel: 'instagram',
      contactValue: '@inkslot',
    };
    row.paymentReference = 'TRX-123';

    const result = await service.create(artistId, {
      ...input(),
      client: {
        name: 'Cliente',
        email: 'legacy@example.test',
        phone: '+593111111111',
      },
      contactChannel: 'instagram',
      contactValue: '  @inkslot  ',
      paymentReference: '  TRX-123  ',
    });

    expect(tx.client.create).toHaveBeenCalledWith({
      data: {
        artistId,
        name: 'Cliente',
        email: null,
        phone: null,
        contactChannel: 'instagram',
        contactValue: '@inkslot',
      },
    });
    expect(tx.bookingRequest.create.mock.calls[0]?.[0].data).toEqual(
      expect.objectContaining({ paymentReference: 'TRX-123' }),
    );
    expect(result.request.client).toEqual({
      id: client.id,
      name: client.name,
      email: null,
      phone: null,
      contactChannel: 'instagram',
      contactValue: '@inkslot',
    });
    expect(result.request.paymentReference).toBe('TRX-123');
  });

  it.each([
    ['email', 'contact@example.test', 'contact@example.test', null],
    ['whatsapp', '+593999999999', null, '+593999999999'],
    ['phone', '+593888888888', null, '+593888888888'],
  ] as const)(
    'maps %s contact data to legacy fields',
    async (channel, value, email, phone) => {
      await service.create(artistId, {
        ...input(),
        contactChannel: channel,
        contactValue: value,
      });

      expect(tx.client.create.mock.calls[0]?.[0].data).toEqual(
        expect.objectContaining({
          email,
          phone,
          contactChannel: channel,
          contactValue: value,
        }),
      );
    },
  );

  it.each([
    [{ contactChannel: 'email' }, 'INVALID_CONTACT'],
    [{ contactValue: 'contact@example.test' }, 'INVALID_CONTACT'],
    [
      { contactChannel: 'email', contactValue: 'not-an-email' },
      'INVALID_CONTACT',
    ],
    [
      { contactChannel: 'whatsapp', contactValue: 'contact@example.test' },
      'INVALID_CONTACT',
    ],
    [
      { contactChannel: 'phone', contactValue: '1'.repeat(33) },
      'INVALID_CONTACT',
    ],
    [
      { contactChannel: 'instagram', contactValue: '1'.repeat(65) },
      'INVALID_CONTACT',
    ],
    [{ paymentReference: '   ' }, 'INVALID_PAYMENT_REFERENCE'],
    [{ paymentReference: '1'.repeat(161) }, 'INVALID_PAYMENT_REFERENCE'],
  ] as const)('rejects invalid contact metadata %j', async (metadata, code) => {
    await expectCode(
      service.create(artistId, { ...input(), ...metadata }),
      code,
      400,
    );
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });

  it('updates an existing scoped client only when contact metadata is explicit', async () => {
    await service.create(artistId, {
      clientId: client.id,
      contactChannel: 'email',
      contactValue: 'updated@example.test',
      depositVerified: true,
      durationMinutes: 60,
    });

    expect(tx.client.updateMany).toHaveBeenCalledWith({
      where: { id: client.id, artistId },
      data: {
        email: 'updated@example.test',
        phone: null,
        contactChannel: 'email',
        contactValue: 'updated@example.test',
      },
    });
  });

  it('hides clients from another artist', async () => {
    tx.client.findFirst.mockResolvedValue(null);
    await expectCode(
      service.create(artistId, {
        clientId: client.id,
        depositVerified: true,
        durationMinutes: 60,
      }),
      'NOT_FOUND',
      404,
    );
    expect(tx.bookingRequest.create).not.toHaveBeenCalled();
  });

  it.each([{}, { clientId: client.id, client: { name: 'Cliente' } }])(
    'requires exactly one client source: %j',
    async (source) => {
      await expectCode(
        service.create(artistId, {
          ...source,
          depositVerified: true,
          durationMinutes: 60,
        }),
        'BAD_REQUEST',
        400,
      );
      expect(prisma.$transaction).not.toHaveBeenCalled();
    },
  );

  it('rejects an unverified deposit before persistence', async () => {
    await expectCode(
      service.create(artistId, { ...input(), depositVerified: false }),
      'DEPOSIT_NOT_VERIFIED',
      422,
    );
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });

  it.each([0, -1, 1.5, NaN])(
    'rejects invalid duration %s',
    async (durationMinutes) => {
      await expectCode(
        service.create(artistId, { ...input(), durationMinutes }),
        'BAD_REQUEST',
        400,
      );
    },
  );

  it.each([0, -1, 721, 1.5, NaN, null])(
    'rejects invalid TTL %s',
    async (ttl) => {
      await expectCode(
        service.create(artistId, { ...input(), tokenTtlHours: ttl as number }),
        'BAD_REQUEST',
        400,
      );
      expect(prisma.$transaction).not.toHaveBeenCalled();
    },
  );

  it.each([1, 720])('accepts custom TTL boundary %s', async (tokenTtlHours) => {
    await service.create(artistId, { ...input(), tokenTtlHours });
    expect(tx.bookingToken.create).toHaveBeenCalledWith({
      data: {
        requestId: id,
        tokenHash,
        expiresAt: new Date(now.getTime() + tokenTtlHours * 3600000),
      },
    });
  });

  it.each([
    { minDate: '2026-02-30' },
    { minDate: '2026-10-15T00:00:00Z' },
    { minDate: '2026-11-01', maxDate: '2026-10-01' },
    { allowedWeekdays: [1, 1] },
    { allowedWeekdays: [-1] },
    { allowedWeekdays: [7] },
    { allowedWeekdays: [1.5] },
    { allowedWindows: [{ startLocal: '24:00', endLocal: '25:00' }] },
    { allowedWindows: [{ startLocal: '12:00', endLocal: '12:00' }] },
    { allowedWindows: [{ startLocal: '13:00', endLocal: '12:00' }] },
  ])('rejects invalid restrictions %j', async (restrictions) => {
    await expectCode(
      service.create(artistId, { ...input(), ...restrictions }),
      'INVALID_RESTRICTIONS',
      400,
    );
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });

  it('persists inclusive dates and validated JSON restrictions', async () => {
    await service.create(artistId, {
      ...input(),
      minDate: '2026-10-20',
      maxDate: '2026-10-20',
      allowedWeekdays: [0, 6],
      allowedWindows: [{ startLocal: '09:00', endLocal: '17:30' }],
    });
    const requestCreate = tx.bookingRequest.create.mock.calls[0]?.[0];
    expect(requestCreate?.data.minDate).toEqual(
      new Date('2026-10-20T00:00:00Z'),
    );
    expect(requestCreate?.data.maxDate).toEqual(
      new Date('2026-10-20T00:00:00Z'),
    );
    expect(requestCreate?.data.allowedWeekdays).toEqual([0, 6]);
    expect(requestCreate?.data.allowedWindows).toEqual([
      { startLocal: '09:00', endLocal: '17:30' },
    ]);
  });

  it('scopes and filters lists with stable cursor pagination', async () => {
    const rows = Array.from({ length: 21 }, (_, i) => ({
      ...row,
      id: `22222222-2222-4222-8222-${(21 - i).toString().padStart(12, '0')}`,
    }));
    tx.bookingRequest.findMany.mockResolvedValue(rows);
    const result = await service.list(artistId, { status: 'pending' });
    expect(result.items).toHaveLength(20);
    expect(tokens.decodeBookingCursor(result.nextCursor!)).toEqual({
      createdAt: now,
      id: rows[19].id,
    });
    expect(tx.bookingRequest.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { artistId, status: 'PENDING' },
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        take: 21,
      }),
    );
    tx.bookingRequest.findMany.mockResolvedValue([rows[20]]);
    const page = await service.list(artistId, { cursor: result.nextCursor! });
    expect(page.nextCursor).toBeNull();
    expect(tx.bookingRequest.findMany).toHaveBeenLastCalledWith(
      expect.objectContaining({
        where: {
          artistId,
          OR: [
            { createdAt: { lt: now } },
            { createdAt: now, id: { lt: rows[19].id } },
          ],
        },
      }),
    );
    expect(JSON.stringify(result)).not.toContain(tokenHash);
    expect(JSON.stringify(result)).not.toContain(rawToken);
  });

  it('normalizes expired pending requests before listing them', async () => {
    await service.list(artistId, { status: 'expired' });

    expect(tx.bookingRequest.updateMany).toHaveBeenCalledWith({
      where: {
        artistId,
        status: BookingRequestStatus.PENDING,
        tokens: {
          some: {
            revokedAt: null,
            consumedAt: null,
            expiresAt: { lte: now },
          },
          none: {
            revokedAt: null,
            consumedAt: null,
            expiresAt: { gt: now },
          },
        },
      },
      data: {
        status: BookingRequestStatus.EXPIRED,
        version: { increment: 1 },
      },
    });
  });

  it('projects the current active link expiration in list responses', async () => {
    const result = await service.list(artistId, { status: 'pending' });

    expect(
      (result.items[0] as unknown as { linkExpiresAt?: string }).linkExpiresAt,
    ).toBe('2026-10-17T12:00:00.000Z');
  });

  it('rejects invalid cursor and status safely', async () => {
    await expectCode(
      service.list(artistId, { cursor: 'invalid' }),
      'BAD_REQUEST',
      400,
    );
    await expectCode(
      service.list(artistId, { status: 'OTHER' as 'pending' }),
      'BAD_REQUEST',
      400,
    );
    expect(tx.bookingRequest.findMany).not.toHaveBeenCalled();
  });

  it('details only scoped requests and safe audit metadata', async () => {
    tx.auditLog.findMany.mockResolvedValue([
      {
        id,
        actorId: artistId,
        actorType: 'ADMIN',
        entityId: id,
        entityType: 'booking_request',
        action: 'created',
        changes: { private: 'excluded' },
        createdAt: now,
      },
    ]);
    const result = await service.detail(artistId, id);
    expect(tx.bookingRequest.findFirst).toHaveBeenCalledWith(
      expect.objectContaining({ where: { id, artistId } }),
    );
    expect(tx.auditLog.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          entityType: 'booking_request',
          entityId: id,
          actorId: artistId,
          actorType: 'ADMIN',
        },
      }),
    );
    expect(result.currentLink).toEqual({
      status: 'active',
      expiresAt: '2026-10-17T12:00:00.000Z',
    });
    expect(result.audit).toEqual([
      { action: 'created', createdAt: now.toISOString() },
    ]);
    expect(JSON.stringify(result)).not.toContain(tokenHash);
    expect(JSON.stringify(result)).not.toContain('excluded');
  });

  it('returns not found for missing or foreign requests before reading audit', async () => {
    tx.bookingRequest.findFirst.mockResolvedValue(null);
    await expectCode(service.detail(artistId, id), 'NOT_FOUND', 404);
    expect(tx.auditLog.findMany).not.toHaveBeenCalled();
  });

  it.each(['expired', 'revoked', 'consumed'] as const)(
    'derives %s current link without leaking hashes',
    async (status) => {
      if (status === 'expired') row.tokens[0].expiresAt = now;
      if (status === 'revoked') row.tokens[0].revokedAt = now;
      if (status === 'consumed') row.tokens[0].consumedAt = now;
      expect((await service.detail(artistId, id)).currentLink?.status).toBe(
        status,
      );
    },
  );

  it('prefers an active replacement over a revoked historical token', async () => {
    row.tokens.unshift({ ...row.tokens[0], revokedAt: now });
    expect((await service.detail(artistId, id)).currentLink?.status).toBe(
      'active',
    );
  });

  it.each([BookingRequestStatus.PENDING, BookingRequestStatus.EXPIRED])(
    'renews %s by locking, revoking, hashing and auditing atomically',
    async (status) => {
      row.status = status;
      const result = await service.renew(artistId, id, { tokenTtlHours: 1 });
      expect(tx.bookingRequest.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id, artistId },
          data: { status: 'PENDING', version: { increment: 1 } },
        }),
      );
      expect(tx.bookingToken.updateMany).toHaveBeenCalledWith({
        where: { requestId: id, revokedAt: null },
        data: { revokedAt: now },
      });
      expect(tx.bookingToken.create).toHaveBeenCalledWith({
        data: {
          requestId: id,
          tokenHash,
          expiresAt: new Date('2026-10-15T13:00:00.000Z'),
        },
      });
      const auditCreate = tx.auditLog.create.mock.calls.at(-1)?.[0];
      expect(auditCreate?.data.action).toBe('token_renewed');
      expect(result.link.path).toBe(`/r/${rawToken}`);
      expect(result.request.status).toBe('pending');
    },
  );

  it.each(['renew', 'revoke', 'close'] as const)(
    'rejects %s of a booked request',
    async (action) => {
      row.status = 'BOOKED';
      await expectCode(service[action](artistId, id), 'ALREADY_BOOKED', 409);
      expect(tx.bookingToken.updateMany).not.toHaveBeenCalled();
      expect(tx.auditLog.create).not.toHaveBeenCalled();
    },
  );

  it.each([
    ['renew', 'CANCELLED'],
    ['renew', 'CLOSED'],
    ['revoke', 'CLOSED'],
    ['close', 'CANCELLED'],
  ] as const)('rejects incompatible %s on %s', async (action, status) => {
    row.status = status;
    await expectCode(service[action](artistId, id), 'BAD_REQUEST', 400);
  });

  it.each(['renew', 'revoke', 'close'] as const)(
    'scopes %s to authenticated artist',
    async (action) => {
      tx.bookingRequest.findFirst.mockResolvedValue(null);
      await expectCode(service[action](artistId, id), 'NOT_FOUND', 404);
      expect(tx.bookingRequest.findFirst).toHaveBeenCalledWith(
        expect.objectContaining({ where: { id, artistId } }),
      );
      expect(tx.bookingToken.updateMany).not.toHaveBeenCalled();
    },
  );

  it.each([
    ['revoke', 'CANCELLED', 'revoked'],
    ['close', 'CLOSED', 'closed'],
  ] as const)(
    '%s transitions and repeats without duplicate audit or writes',
    async (action, status, auditAction) => {
      expect((await service[action](artistId, id)).status).toBe(
        status.toLowerCase(),
      );
      expect(tx.bookingToken.updateMany).toHaveBeenCalledTimes(1);
      const auditCreate = tx.auditLog.create.mock.calls.at(-1)?.[0];
      expect(auditCreate?.data.action).toBe(auditAction);
      row.status = status;
      await service[action](artistId, id);
      expect(tx.bookingRequest.update).toHaveBeenCalledTimes(1);
      expect(tx.auditLog.create).toHaveBeenCalledTimes(1);
      expect(tx.bookingToken.create).not.toHaveBeenCalled();
    },
  );

  it('does not return a raw link if the transaction fails to persist audit', async () => {
    tx.auditLog.create.mockRejectedValue(new Error(`private ${rawToken}`));
    await expectCode(
      service.create(artistId, input()),
      'SERVICE_UNAVAILABLE',
      503,
    );
  });

  it('retries serializable conflicts but sanitizes exhausted retries', async () => {
    const conflict = new Prisma.PrismaClientKnownRequestError('private', {
      code: 'P2034',
      clientVersion: '6.19.0',
    });
    prisma.$transaction.mockRejectedValueOnce(conflict);
    await service.revoke(artistId, id);
    expect(prisma.$transaction).toHaveBeenCalledTimes(2);
    prisma.$transaction.mockClear().mockRejectedValue(conflict);
    await expectCode(service.renew(artistId, id), 'SERVICE_UNAVAILABLE', 503);
    expect(prisma.$transaction).toHaveBeenCalledTimes(3);
  });

  it('sanitizes persistence failures on list and detail', async () => {
    tx.bookingRequest.findMany.mockRejectedValue(
      new Error(`private ${rawToken}`),
    );
    tx.bookingRequest.findFirst.mockRejectedValue(
      new Error(`private ${tokenHash}`),
    );
    await expectCode(service.list(artistId, {}), 'SERVICE_UNAVAILABLE', 503);
    await expectCode(service.detail(artistId, id), 'SERVICE_UNAVAILABLE', 503);
  });

  it('validates nested DTOs and rejects unknown fields with the application pipe', async () => {
    const pipe = new ValidationPipe({
      transform: true,
      whitelist: true,
      forbidNonWhitelisted: true,
    });
    const validateCreate = (value: unknown) =>
      pipe.transform(value, {
        type: 'body',
        metatype: CreateBookingRequestDto,
      });
    await expect(validateCreate(input())).resolves.toBeInstanceOf(
      CreateBookingRequestDto,
    );
    for (const invalid of [
      { ...input(), artistId },
      { ...input(), client: { name: ' ' } },
      { ...input(), client: { name: 'Cliente', email: 'invalid' } },
      { ...input(), client: { name: 'Cliente', unexpected: true } },
      {
        ...input(),
        allowedWindows: [{ startLocal: '1:00', endLocal: '12:00' }],
      },
      { ...input(), allowedWeekdays: [1, 1] },
      { ...input(), tokenTtlHours: 0 },
    ])
      await expect(validateCreate(invalid)).rejects.toBeInstanceOf(
        HttpException,
      );
    await expect(
      pipe.transform(
        { tokenTtlHours: 721 },
        { type: 'body', metatype: RenewBookingTokenDto },
      ),
    ).rejects.toBeInstanceOf(HttpException);
  });
});
