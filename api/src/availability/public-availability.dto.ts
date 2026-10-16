import { IsString, Matches } from 'class-validator';

export const DATE_ONLY_PATTERN = /^\d{4}-\d{2}-\d{2}$/;

export class PublicAvailabilityQueryDto {
  @IsString()
  @Matches(DATE_ONLY_PATTERN)
  from!: string;

  @IsString()
  @Matches(DATE_ONLY_PATTERN)
  to!: string;
}
