import { IsIn, IsOptional } from 'class-validator';

export class ListSyncIssuesDto {
  @IsOptional()
  @IsIn(['open', 'resolved'])
  status?: 'open' | 'resolved';
}
