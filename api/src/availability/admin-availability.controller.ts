import { Body, Controller, Get, Put, Req, UseGuards } from '@nestjs/common';

import {
  AdminSessionGuard,
  type AuthenticatedRequest,
} from '../auth/admin-session.guard';
import { UpdateAdminAvailabilityDto } from './admin-availability.dto';
import { AdminAvailabilityService } from './admin-availability.service';

@Controller('admin/availability')
@UseGuards(AdminSessionGuard)
export class AdminAvailabilityController {
  constructor(private readonly availability: AdminAvailabilityService) {}

  @Get()
  get(@Req() request: AuthenticatedRequest) {
    return this.availability.get(request.user.id);
  }

  @Put()
  update(
    @Req() request: AuthenticatedRequest,
    @Body() dto: UpdateAdminAvailabilityDto,
  ) {
    return this.availability.update(request.user.id, dto);
  }
}
