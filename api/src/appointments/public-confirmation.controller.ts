import { Body, Controller, Get, Headers, Param, Post } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';

import { PublicConfirmDto } from './public-confirmation.dto';
import { PublicConfirmationService } from './public-confirmation.service';

@Controller('public/reservations')
export class PublicConfirmationController {
  constructor(private readonly confirmations: PublicConfirmationService) {}

  @Post(':token/confirm')
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  confirm(
    @Param('token') token: string,
    @Headers('idempotency-key') idempotencyKey: string | undefined,
    @Body() input: PublicConfirmDto,
  ) {
    return this.confirmations.confirm(token, idempotencyKey, input);
  }

  @Get(':token/appointment')
  @Throttle({ default: { limit: 30, ttl: 60_000 } })
  getAppointment(@Param('token') token: string) {
    return this.confirmations.getAppointment(token);
  }
}
