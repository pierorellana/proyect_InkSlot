import { IsIn, IsOptional, IsString, MaxLength } from 'class-validator';

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
