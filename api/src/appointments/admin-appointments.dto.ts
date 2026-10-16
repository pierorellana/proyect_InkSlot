import {
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
  Min,
} from 'class-validator';

export const ADMIN_APPOINTMENT_STATUSES = [
  'confirmed',
  'completed',
  'cancelled',
  'no_show',
] as const;

export type AdminAppointmentStatusFilter =
  (typeof ADMIN_APPOINTMENT_STATUSES)[number];

export class ListAdminAppointmentsDto {
  @IsOptional()
  @IsIn(ADMIN_APPOINTMENT_STATUSES)
  status?: AdminAppointmentStatusFilter;

  @IsOptional()
  @IsString()
  @MaxLength(256)
  cursor?: string;
}

export const UTC_DATETIME_WITH_MILLISECONDS_PATTERN =
  /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/;

export class RescheduleAdminAppointmentDto {
  @IsString()
  @Matches(UTC_DATETIME_WITH_MILLISECONDS_PATTERN)
  startAt!: string;

  @IsInt()
  @Min(1)
  version!: number;
}

export class AppointmentActionDto {
  @IsInt()
  @Min(1)
  version!: number;
}
