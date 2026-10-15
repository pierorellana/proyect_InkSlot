import { Module } from '@nestjs/common';

import { AuthModule } from '../auth/auth.module';
import { CALENDAR_CONFIG, CALENDAR_PROVIDER } from './calendar.constants';
import { readCalendarConfig } from './calendar.config';
import { CalendarController } from './calendar.controller';
import { CalendarCrypto } from './calendar.crypto';
import { GoogleCalendarProvider } from './google-calendar.provider';
import { CalendarService } from './calendar.service';
import { CalendarStateService } from './calendar.state.service';

@Module({
  imports: [AuthModule],
  controllers: [CalendarController],
  providers: [
    {
      provide: CALENDAR_CONFIG,
      useFactory: () => readCalendarConfig(process.env),
    },
    {
      provide: CalendarCrypto,
      useFactory: (config: ReturnType<typeof readCalendarConfig>) =>
        new CalendarCrypto(config.tokenEncryptionKey),
      inject: [CALENDAR_CONFIG],
    },
    {
      provide: GoogleCalendarProvider,
      useFactory: (config: ReturnType<typeof readCalendarConfig>) =>
        new GoogleCalendarProvider(config),
      inject: [CALENDAR_CONFIG],
    },
    {
      provide: CALENDAR_PROVIDER,
      useExisting: GoogleCalendarProvider,
    },
    CalendarStateService,
    CalendarService,
  ],
  exports: [CalendarService, CALENDAR_PROVIDER],
})
export class CalendarModule {}
