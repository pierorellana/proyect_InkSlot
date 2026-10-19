import { BookingRequestStatus, Prisma } from '@prisma/client';

import { PrismaService } from '../database/prisma.service';

type BookingRequestPrisma = Pick<PrismaService, 'bookingRequest'>;

/**
 * Keeps the persisted request status aligned with the lifecycle of its link.
 *
 * This is intentionally lazy: admin reads are enough to remove stale pending
 * requests from operational views without requiring a background worker.
 */
export async function expirePendingBookingRequests(
  prisma: BookingRequestPrisma,
  artistId: string,
  now: Date,
): Promise<number> {
  const result = await prisma.bookingRequest.updateMany({
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

  return result.count;
}
