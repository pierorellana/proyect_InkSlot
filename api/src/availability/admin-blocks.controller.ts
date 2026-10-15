import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';

import {
  AdminSessionGuard,
  type AuthenticatedRequest,
} from '../auth/admin-session.guard';
import { CreateAvailabilityBlockDto } from './admin-blocks.dto';
import { AdminBlocksService } from './admin-blocks.service';

@Controller('admin/blocks')
@UseGuards(AdminSessionGuard)
export class AdminBlocksController {
  constructor(private readonly blocks: AdminBlocksService) {}

  @Get()
  list(@Req() request: AuthenticatedRequest) {
    return this.blocks.list(request.user.id);
  }

  @Post()
  create(
    @Req() request: AuthenticatedRequest,
    @Body() dto: CreateAvailabilityBlockDto,
  ) {
    return this.blocks.create(request.user.id, dto);
  }

  @Delete(':id')
  @HttpCode(204)
  async remove(
    @Req() request: AuthenticatedRequest,
    @Param('id') id: string,
  ): Promise<void> {
    await this.blocks.remove(request.user.id, id);
  }
}
