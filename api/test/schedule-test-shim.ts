import { DynamicModule, Injectable, Module } from '@nestjs/common';

@Injectable()
export class SchedulerRegistry {
  private readonly intervals = new Map<string, NodeJS.Timeout>();

  addInterval(name: string, interval: NodeJS.Timeout): void {
    this.intervals.set(name, interval);
  }

  deleteInterval(name: string): void {
    this.intervals.delete(name);
  }
}

@Module({})
export class ScheduleModule {
  static forRoot(): DynamicModule {
    return {
      module: ScheduleModule,
      providers: [SchedulerRegistry],
      exports: [SchedulerRegistry],
    };
  }
}
