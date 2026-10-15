import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import type { Request } from 'express';

import {
  AdminSessionGuard,
  type AuthenticatedRequest,
} from '../auth/admin-session.guard';
import {
  CreateBookingRequestDto,
  ListBookingRequestsDto,
  RenewBookingTokenDto,
} from './requests.dto';
import { BookingRequestsService } from './requests.service';

@Controller('admin/booking-requests')
@UseGuards(AdminSessionGuard)
export class BookingRequestsController {
  constructor(private readonly service: BookingRequestsService) {}

  @Post()
  create(@Req() request: Request, @Body() dto: CreateBookingRequestDto) {
    return this.service.create(this.user(request).id, dto);
  }

  @Get()
  list(@Req() request: Request, @Query() query: ListBookingRequestsDto) {
    return this.service.list(this.user(request).id, query);
  }

  @Get(':id')
  detail(@Req() request: Request, @Param('id') id: string) {
    return this.service.detail(this.user(request).id, id);
  }

  @Post(':id/renew')
  renew(
    @Req() request: Request,
    @Param('id') id: string,
    @Body() dto: RenewBookingTokenDto,
  ) {
    return this.service.renew(this.user(request).id, id, dto);
  }

  @Post(':id/revoke')
  revoke(@Req() request: Request, @Param('id') id: string) {
    return this.service.revoke(this.user(request).id, id);
  }

  @Post(':id/close')
  close(@Req() request: Request, @Param('id') id: string) {
    return this.service.close(this.user(request).id, id);
  }

  private user(request: Request) {
    return (request as AuthenticatedRequest).user;
  }
}
