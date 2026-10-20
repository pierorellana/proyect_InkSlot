import { Controller, Get, Param } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';

import { BookingRequestsService } from './requests.service';

@Controller('public/reservations')
export class PublicReservationsController {
  constructor(private readonly service: BookingRequestsService) {}

  @Get(':token')
  @Throttle({ default: { limit: 30, ttl: 60_000 } })
  resolve(@Param('token') token: string) {
    return this.service.resolvePublic(token);
  }
}
