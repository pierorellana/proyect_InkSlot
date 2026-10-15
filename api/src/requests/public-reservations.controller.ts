import { Controller, Get, Param } from '@nestjs/common';

import { BookingRequestsService } from './requests.service';

@Controller('public/reservations')
export class PublicReservationsController {
  constructor(private readonly service: BookingRequestsService) {}

  @Get(':token')
  resolve(@Param('token') token: string) {
    return this.service.resolvePublic(token);
  }
}
