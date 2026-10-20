import {
  Body,
  Controller,
  Get,
  HttpCode,
  Post,
  Req,
  Res,
} from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import type { Request, Response } from 'express';

import {
  ADMIN_SESSION_COOKIE,
  ADMIN_SESSION_TTL_SECONDS,
  readAdminSessionToken,
  resolveAdminSessionSameSite,
} from './auth.constants';
import { LoginDto } from './auth.dto';
import { AuthService } from './auth.service';

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('login')
  @HttpCode(200)
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  async login(
    @Body() loginDto: LoginDto,
    @Res({ passthrough: true }) response: Response,
  ) {
    const result = await this.authService.login(
      loginDto.email,
      loginDto.password,
    );
    this.setSessionCookie(response, result.sessionToken);

    return { user: result.user };
  }

  @Get('me')
  async me(@Req() request: Request) {
    return {
      user: await this.authService.me(readAdminSessionToken(request)),
    };
  }

  @Post('logout')
  @HttpCode(204)
  async logout(
    @Req() request: Request,
    @Res({ passthrough: true }) response: Response,
  ): Promise<void> {
    await this.authService.logout(readAdminSessionToken(request));
    response.clearCookie(ADMIN_SESSION_COOKIE, {
      httpOnly: true,
      path: '/',
      sameSite: resolveAdminSessionSameSite(),
      secure: process.env.NODE_ENV === 'production',
    });
  }

  private setSessionCookie(response: Response, sessionToken: string): void {
    response.cookie(ADMIN_SESSION_COOKIE, sessionToken, {
      httpOnly: true,
      maxAge: ADMIN_SESSION_TTL_SECONDS * 1000,
      path: '/',
      sameSite: resolveAdminSessionSameSite(),
      secure: process.env.NODE_ENV === 'production',
    });
  }
}
