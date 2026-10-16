import { Body, Controller, Get, Headers, Param, Post } from '@nestjs/common';

import { PublicConfirmDto } from './public-confirmation.dto';
import { PublicConfirmationService } from './public-confirmation.service';

@Controller('public/reservations')
export class PublicConfirmationController {
  constructor(private readonly confirmations: PublicConfirmationService) {}

  @Post(':token/confirm')
  confirm(
    @Param('token') token: string,
    @Headers('idempotency-key') idempotencyKey: string | undefined,
    @Body() input: PublicConfirmDto,
  ) {
    return this.confirmations.confirm(token, idempotencyKey, input);
  }

  @Get(':token/appointment')
  getAppointment(@Param('token') token: string) {
    return this.confirmations.getAppointment(token);
  }
}
