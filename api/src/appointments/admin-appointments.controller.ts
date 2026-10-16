import {
  Controller,
  Get,
  Param,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';

import {
  AdminSessionGuard,
  type AuthenticatedRequest,
} from '../auth/admin-session.guard';
import { ListAdminAppointmentsDto } from './admin-appointments.dto';
import { AdminAppointmentsService } from './admin-appointments.service';

@Controller('admin/appointments')
@UseGuards(AdminSessionGuard)
export class AdminAppointmentsController {
  constructor(private readonly appointments: AdminAppointmentsService) {}

  @Get()
  list(
    @Req() request: AuthenticatedRequest,
    @Query() query: ListAdminAppointmentsDto,
  ) {
    return this.appointments.list(request.user.id, query);
  }

  @Get(':id')
  detail(@Req() request: AuthenticatedRequest, @Param('id') id: string) {
    return this.appointments.detail(request.user.id, id);
  }
}
