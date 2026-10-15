import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsInt,
  IsString,
  Matches,
  Max,
  Min,
  ValidateNested,
} from 'class-validator';

const LOCAL_TIME_PATTERN = /^(?:[01]\d|2[0-3]):[0-5]\d$/;

export class WeeklyWindowDto {
  @IsInt()
  @Min(0)
  @Max(6)
  weekday!: number;

  @IsString()
  @Matches(LOCAL_TIME_PATTERN)
  startLocal!: string;

  @IsString()
  @Matches(LOCAL_TIME_PATTERN)
  endLocal!: string;
}

export class UpdateAdminAvailabilityDto {
  @IsString()
  timezone!: string;

  @IsInt()
  @Min(1)
  slotStepMinutes!: number;

  @IsInt()
  @Min(0)
  bufferMinutes!: number;

  @IsInt()
  @Min(0)
  minimumNoticeHours!: number;

  @IsInt()
  @Min(1)
  horizonDays!: number;

  @IsArray()
  @ArrayMaxSize(50)
  @ValidateNested({ each: true })
  @Type(() => WeeklyWindowDto)
  weeklyWindows!: WeeklyWindowDto[];
}
