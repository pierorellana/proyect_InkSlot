import {
  Body,
  Controller,
  Get,
  HttpCode,
  Post,
  Req,
  Res,
} from '@nestjs/common';
import type { Request, Response } from 'express';

import {
  ADMIN_SESSION_COOKIE,
  ADMIN_SESSION_TTL_SECONDS,
} from './auth.constants';
import { LoginDto } from './auth.dto';
import { AuthService } from './auth.service';

type RequestWithCookies = Request;

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('login')
  @HttpCode(200)
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
  async me(@Req() request: RequestWithCookies) {
    return {
      user: await this.authService.me(this.readSessionToken(request)),
    };
  }

  @Post('logout')
  @HttpCode(204)
  async logout(
    @Req() request: RequestWithCookies,
    @Res({ passthrough: true }) response: Response,
  ): Promise<void> {
    await this.authService.logout(this.readSessionToken(request));
    response.clearCookie(ADMIN_SESSION_COOKIE, {
      httpOnly: true,
      path: '/',
      sameSite: 'lax',
      secure: process.env.NODE_ENV === 'production',
    });
  }

  private setSessionCookie(response: Response, sessionToken: string): void {
    response.cookie(ADMIN_SESSION_COOKIE, sessionToken, {
      httpOnly: true,
      maxAge: ADMIN_SESSION_TTL_SECONDS * 1000,
      path: '/',
      sameSite: 'lax',
      secure: process.env.NODE_ENV === 'production',
    });
  }

  private readSessionToken(request: RequestWithCookies): string | undefined {
    const cookieHeader = request.headers.cookie;
    if (!cookieHeader) return undefined;

    const cookie = cookieHeader
      .split(';')
      .map((entry) => entry.trim())
      .find((entry) => entry.startsWith(`${ADMIN_SESSION_COOKIE}=`));

    return cookie?.slice(ADMIN_SESSION_COOKIE.length + 1);
  }
}
