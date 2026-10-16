import { BadRequestException, ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.setGlobalPrefix('v1');
  app.enableCors({ origin: true, credentials: true });
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
