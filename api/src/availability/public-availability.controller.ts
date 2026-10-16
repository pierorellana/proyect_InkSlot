import { Controller, Get, Param, Query } from '@nestjs/common';

import { PublicAvailabilityQueryDto } from './public-availability.dto';
import { PublicAvailabilityService } from './public-availability.service';

@Controller('public/reservations')
export class PublicAvailabilityController {
  constructor(private readonly availability: PublicAvailabilityService) {}

  @Get(':token/availability')
  get(
    @Param('token') token: string,
    @Query() query: PublicAvailabilityQueryDto,
  ) {
    return this.availability.get(token, query);
  }
}
