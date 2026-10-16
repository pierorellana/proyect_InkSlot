import { Type } from 'class-transformer';
import {
  ArrayUnique,
  IsArray,
  IsBoolean,
  IsEmail,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Matches,
  Max,
  MaxLength,
  MinLength,
  Min,
  ValidateNested,
} from 'class-validator';

const DATE_PATTERN = /^\d{4}-\d{2}-\d{2}$/;
const LOCAL_TIME_PATTERN = /^(?:[01]\d|2[0-3]):[0-5]\d$/;
const BOOKING_STATUSES = [
  'pending',
  'booked',
  'cancelled',
  'expired',
  'closed',
] as const;

export const CONTACT_CHANNELS = [
  'whatsapp',
  'instagram',
  'email',
  'phone',
] as const;

export type ContactChannel = (typeof CONTACT_CHANNELS)[number];

export type BookingRequestStatusFilter = (typeof BOOKING_STATUSES)[number];

export class InlineClientDto {
  @IsString()
  @MinLength(1)
  @Matches(/\S/)
  @MaxLength(120)
  name!: string;

  @IsOptional()
  @IsEmail()
  @MaxLength(320)
  email?: string;

  @IsOptional()
  @IsString()
  @MaxLength(32)
  phone?: string;
}

export class BookingRestrictionWindowDto {
  @IsString()
  @Matches(LOCAL_TIME_PATTERN)
  startLocal!: string;

  @IsString()
  @Matches(LOCAL_TIME_PATTERN)
  endLocal!: string;
}

export class CreateBookingRequestDto {
  @IsOptional()
  @IsUUID()
  clientId?: string;

  @IsOptional()
  @ValidateNested()
  @Type(() => InlineClientDto)
  client?: InlineClientDto;

  @IsBoolean()
  depositVerified!: boolean;

  @IsOptional()
  @IsIn(CONTACT_CHANNELS)
  contactChannel?: ContactChannel;

  @IsOptional()
  @IsString()
  @Matches(/\S/)
  @MaxLength(320)
  contactValue?: string;

  @IsOptional()
  @IsString()
  @Matches(/\S/)
  @MaxLength(160)
  paymentReference?: string;

  @IsInt()
  @Min(1)
  durationMinutes!: number;

  @IsOptional()
  @IsString()
  @Matches(DATE_PATTERN)
  minDate?: string;

  @IsOptional()
  @IsString()
  @Matches(DATE_PATTERN)
  maxDate?: string;

  @IsOptional()
  @IsArray()
  @ArrayUnique()
  @IsInt({ each: true })
  @Min(0, { each: true })
  @Max(6, { each: true })
  allowedWeekdays?: number[];

  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => BookingRestrictionWindowDto)
  allowedWindows?: BookingRestrictionWindowDto[];

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(720)
  tokenTtlHours?: number;
}

export class RenewBookingTokenDto {
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(720)
  tokenTtlHours?: number;
}

export class ListBookingRequestsDto {
  @IsOptional()
  @IsIn(BOOKING_STATUSES)
  status?: BookingRequestStatusFilter;

  @IsOptional()
  @IsString()
  @MaxLength(256)
  cursor?: string;
}
