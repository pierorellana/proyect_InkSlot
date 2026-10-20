import { BadRequestException, ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import {
  isCorsOriginAllowed,
  readSecurityConfig,
} from './security/security.config';
import {
  originValidationMiddleware,
  securityHeadersMiddleware,
} from './security/security.middleware';
import { RequestIdExceptionFilter } from './observability/request-id.exception-filter';
import { requestIdMiddleware } from './observability/request-id.middleware';

type CorsOriginCallback = (error: Error | null, allow?: boolean) => void;

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  const security = readSecurityConfig();
  app.enableShutdownHooks();
  app.setGlobalPrefix('v1');
  app.use(requestIdMiddleware);
  app.use(securityHeadersMiddleware(security));
  app.use(originValidationMiddleware(security));
  app.useGlobalFilters(new RequestIdExceptionFilter());
  app.enableCors({
    origin: (origin: string | undefined, callback: CorsOriginCallback) => {
      callback(null, isCorsOriginAllowed(origin, security));
    },
    credentials: true,
    allowedHeaders: ['Content-Type', 'Idempotency-Key', 'X-Request-Id'],
    exposedHeaders: ['X-Request-Id'],
  });
  app.useGlobalPipes(
    new ValidationPipe({
      transform: true,
      whitelist: true,
      forbidNonWhitelisted: true,
      exceptionFactory: () =>
        new BadRequestException({
          error: {
            code: 'BAD_REQUEST',
            message: 'Los datos enviados no son válidos',
          },
        }),
    }),
  );
  await app.listen(process.env.PORT ?? 3000);
}

void bootstrap();
