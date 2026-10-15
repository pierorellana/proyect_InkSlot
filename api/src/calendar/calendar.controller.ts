import {
  Controller,
  Get,
  HttpCode,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';

import {
  AdminSessionGuard,
  type AuthenticatedRequest,
} from '../auth/admin-session.guard';
import { CalendarService } from './calendar.service';

@Controller('admin/calendar')
export class CalendarController {
  constructor(private readonly calendar: CalendarService) {}

  @Get('status')
  @UseGuards(AdminSessionGuard)
  status(@Req() request: AuthenticatedRequest) {
    return this.calendar.status(request.user.id);
  }

  @Get('connect')
  @UseGuards(AdminSessionGuard)
  connect(@Req() request: AuthenticatedRequest) {
    return this.calendar.connect(request.user.id);
  }

  @Get('callback')
  callback(
    @Query('code') code?: string,
    @Query('state') state?: string,
    @Query('error') error?: string,
  ) {
    return this.calendar.callback({ code, state, error });
  }

  @Post('disconnect')
  @HttpCode(204)
  @UseGuards(AdminSessionGuard)
  async disconnect(@Req() request: AuthenticatedRequest): Promise<void> {
    await this.calendar.disconnect(request.user.id);
  }

  @Post('reconnect')
  @UseGuards(AdminSessionGuard)
  reconnect(@Req() request: AuthenticatedRequest) {
    return this.calendar.reconnect(request.user.id);
  }
}
