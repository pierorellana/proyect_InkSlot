import type { AvailabilityResult } from './availability.engine';

export type PublicSlotCheck = {
  startAt: Date;
  endAt: Date;
  timezone: string;
  refreshed: AvailabilityResult;
};
