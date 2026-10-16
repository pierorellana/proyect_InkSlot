import {
  Controller,
  Get,
  HttpCode,
  Param,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';

import {
  AdminSessionGuard,
  type AuthenticatedRequest,
} from '../auth/admin-session.guard';
import { ListSyncIssuesDto } from './sync-issues.dto';
import { SyncIssuesService } from './sync-issues.service';

@Controller('admin/sync-issues')
@UseGuards(AdminSessionGuard)
export class SyncIssuesController {
  constructor(private readonly syncIssues: SyncIssuesService) {}

  @Get()
  list(
    @Req() request: AuthenticatedRequest,
    @Query() query: ListSyncIssuesDto,
  ) {
    return this.syncIssues.list(request.user.id, query);
  }

  @Post(':id/retry')
  @HttpCode(200)
  retry(@Req() request: AuthenticatedRequest, @Param('id') issueId: string) {
    return this.syncIssues.retry(request.user.id, issueId);
  }
}
