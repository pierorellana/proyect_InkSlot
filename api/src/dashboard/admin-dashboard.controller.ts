import { Controller, Get, Req, UseGuards } from '@nestjs/common';

import {
  AdminSessionGuard,
  type AuthenticatedRequest,
} from '../auth/admin-session.guard';
import {
  AdminDashboardService,
  type AdminDashboardResponse,
} from './admin-dashboard.service';

@Controller('admin/dashboard')
@UseGuards(AdminSessionGuard)
export class AdminDashboardController {
  constructor(private readonly dashboard: AdminDashboardService) {}

  @Get()
  get(@Req() request: AuthenticatedRequest): Promise<AdminDashboardResponse> {
    return this.dashboard.get(request.user.id);
  }
}
