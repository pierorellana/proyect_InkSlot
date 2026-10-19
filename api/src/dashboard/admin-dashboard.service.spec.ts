import {
  AppointmentStatus,
  BookingRequestStatus,
  SyncIssueStatus,
  SyncStatus,
} from '@prisma/client';

import { PrismaService } from '../database/prisma.service';
import { AdminDashboardService } from './admin-dashboard.service';

describe('AdminDashboardService', () => {
  const artistId = '11111111-1111-4111-8111-111111111111';
  const otherArtistId = '22222222-2222-4222-8222-222222222222';
  const now = new Date('2026-10-16T12:00:00.000Z');

  const prisma = {
    bookingRequest: { count: jest.fn(), updateMany: jest.fn() },
    appointment: { count: jest.fn(), findMany: jest.fn() },
    syncIssue: { count: jest.fn() },
  };

  let service: AdminDashboardService;

  beforeEach(() => {
    jest.resetAllMocks();
    jest.useFakeTimers().setSystemTime(now);
    prisma.bookingRequest.count.mockResolvedValue(0);
    prisma.bookingRequest.updateMany.mockResolvedValue({ count: 0 });
    prisma.appointment.count.mockResolvedValue(0);
    prisma.syncIssue.count.mockResolvedValue(0);
    prisma.appointment.findMany.mockResolvedValue([]);
    service = new AdminDashboardService(
      prisma as unknown as PrismaService,
    );
  });

  afterEach(() => {
    jest.useRealTimers();
  });

  it('counts only the authenticated artist data and hides sensitive fields', async () => {
    prisma.bookingRequest.count.mockResolvedValue(2);
    prisma.appointment.count.mockResolvedValue(1);
    prisma.syncIssue.count.mockResolvedValue(1);
    prisma.appointment.findMany.mockResolvedValue([
      {
        id: 'appointment-a',
        startAt: new Date('2026-10-20T15:00:00.000Z'),
        endAt: new Date('2026-10-20T18:00:00.000Z'),
        status: AppointmentStatus.CONFIRMED,
        syncStatus: SyncStatus.SYNCED,
        request: {
          durationMinutes: 180,
          client: { name: 'Cliente A' },
        },
      },
    ]);

    await expect(service.get(artistId)).resolves.toEqual({
      pendingRequests: 2,
      upcomingAppointments: 1,
      syncIssues: 1,
      nextAppointments: [
        {
          id: 'appointment-a',
          client: { name: 'Cliente A' },
          startAt: '2026-10-20T15:00:00.000Z',
          endAt: '2026-10-20T18:00:00.000Z',
          durationMinutes: 180,
          status: 'confirmed',
          syncStatus: 'synced',
        },
      ],
    });

    expect(prisma.bookingRequest.count).toHaveBeenCalledWith({
      where: { artistId, status: BookingRequestStatus.PENDING },
    });
    expect(prisma.appointment.count).toHaveBeenCalledWith({
      where: {
        artistId,
        status: AppointmentStatus.CONFIRMED,
        startAt: { gte: now },
      },
    });
    expect(prisma.syncIssue.count).toHaveBeenCalledWith({
      where: {
        status: SyncIssueStatus.OPEN,
        appointment: { artistId },
      },
    });
    expect(JSON.stringify(await service.get(artistId))).not.toContain(
      'calendarId',
    );
  });

  it('normalizes expired pending requests before calculating the dashboard', async () => {
    await service.get(artistId);

    expect(prisma.bookingRequest.updateMany).toHaveBeenCalledWith({
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

  it('uses the artist scope for every query and excludes non-pending, past, and non-confirmed records', async () => {
    await service.get(otherArtistId);

    expect(prisma.bookingRequest.count).toHaveBeenCalledWith({
      where: {
        artistId: otherArtistId,
        status: BookingRequestStatus.PENDING,
      },
    });
    expect(prisma.appointment.count).toHaveBeenCalledWith({
      where: {
        artistId: otherArtistId,
        status: AppointmentStatus.CONFIRMED,
        startAt: { gte: now },
      },
    });
    expect(prisma.syncIssue.count).toHaveBeenCalledWith({
      where: {
        status: SyncIssueStatus.OPEN,
        appointment: { artistId: otherArtistId },
      },
    });
    expect(prisma.appointment.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          artistId: otherArtistId,
          status: AppointmentStatus.CONFIRMED,
          startAt: { gte: now },
        },
      }),
    );
  });

  it('orders upcoming appointments by startAt and id and limits the projection to five rows', async () => {
    prisma.appointment.findMany.mockResolvedValue([
      {
        id: 'appointment-a',
        startAt: new Date('2026-10-17T15:00:00.000Z'),
        endAt: new Date('2026-10-17T16:00:00.000Z'),
        status: AppointmentStatus.CONFIRMED,
        syncStatus: SyncStatus.PENDING,
        request: { durationMinutes: 60, client: { name: 'Cliente A' } },
      },
    ]);

    await service.get(artistId);

    expect(prisma.appointment.findMany).toHaveBeenCalledWith({
      where: {
        artistId,
        status: AppointmentStatus.CONFIRMED,
        startAt: { gte: now },
      },
      orderBy: [{ startAt: 'asc' }, { id: 'asc' }],
      take: 5,
      select: {
        id: true,
        startAt: true,
        endAt: true,
        status: true,
        syncStatus: true,
        request: {
          select: {
            durationMinutes: true,
            client: { select: { name: true } },
          },
        },
      },
    });
  });

  it('returns zero counters and an empty list when the artist has no dashboard data', async () => {
    await expect(service.get(artistId)).resolves.toEqual({
      pendingRequests: 0,
      upcomingAppointments: 0,
      syncIssues: 0,
      nextAppointments: [],
    });
  });
});
