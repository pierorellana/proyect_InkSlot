import {
  AppointmentStatus,
  BookingRequestStatus,
  Prisma,
  SyncIssueStatus,
} from '@prisma/client';
import { Injectable } from '@nestjs/common';

import { PrismaService } from '../database/prisma.service';

export type AdminDashboardResponse = {
  pendingRequests: number;
  upcomingAppointments: number;
  syncIssues: number;
  nextAppointments: Array<{
    id: string;
    client: { name: string };
    startAt: string;
    endAt: string;
    durationMinutes: number;
    status: 'confirmed';
    syncStatus: 'pending' | 'synced' | 'failed';
  }>;
};

type DashboardAppointment = Prisma.AppointmentGetPayload<{
  select: {
    id: true;
    startAt: true;
    endAt: true;
    status: true;
    syncStatus: true;
    request: {
      select: {
        durationMinutes: true;
        client: { select: { name: true } };
      };
    };
  };
}>;

@Injectable()
export class AdminDashboardService {
  constructor(private readonly prisma: PrismaService) {}

  async get(artistId: string): Promise<AdminDashboardResponse> {
    const now = new Date();
    const appointmentWhere: Prisma.AppointmentWhereInput = {
      artistId,
      status: AppointmentStatus.CONFIRMED,
      startAt: { gte: now },
    };

    const [pendingRequests, upcomingAppointments, syncIssues, appointments] =
      await Promise.all([
        this.prisma.bookingRequest.count({
          where: { artistId, status: BookingRequestStatus.PENDING },
        }),
        this.prisma.appointment.count({ where: appointmentWhere }),
        this.prisma.syncIssue.count({
          where: {
            status: SyncIssueStatus.OPEN,
            appointment: { artistId },
          },
        }),
        this.prisma.appointment.findMany({
          where: appointmentWhere,
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
        }),
      ]);

    return {
      pendingRequests,
      upcomingAppointments,
      syncIssues,
      nextAppointments: appointments.map((appointment) =>
        this.toNextAppointment(appointment),
      ),
    };
  }

  private toNextAppointment(
    appointment: DashboardAppointment,
  ): AdminDashboardResponse['nextAppointments'][number] {
    return {
      id: appointment.id,
      client: { name: appointment.request.client.name },
      startAt: appointment.startAt.toISOString(),
      endAt: appointment.endAt.toISOString(),
      durationMinutes: appointment.request.durationMinutes,
      status: 'confirmed',
      syncStatus: appointment.syncStatus.toLowerCase() as
        | 'pending'
        | 'synced'
        | 'failed',
    };
  }
}
