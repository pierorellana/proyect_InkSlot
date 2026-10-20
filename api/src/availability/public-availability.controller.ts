import { Controller, Get, Param, Query } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';

import { PublicAvailabilityQueryDto } from './public-availability.dto';
import { PublicAvailabilityService } from './public-availability.service';

@Controller('public/reservations')
export class PublicAvailabilityController {
  constructor(private readonly availability: PublicAvailabilityService) {}

  @Get(':token/availability')
  @Throttle({ default: { limit: 30, ttl: 60_000 } })
  get(
    @Param('token') token: string,
    @Query() query: PublicAvailabilityQueryDto,
  ) {
    return this.availability.get(token, query);
  }
}
