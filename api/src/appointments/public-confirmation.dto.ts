import { IsString, Matches } from 'class-validator';

export const UTC_START_PATTERN =
  /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/;

export class PublicConfirmDto {
  @IsString()
  @Matches(UTC_START_PATTERN)
  startAt!: string;
}
