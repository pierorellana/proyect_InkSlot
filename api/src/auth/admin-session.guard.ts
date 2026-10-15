import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import type { Request } from 'express';

import { readAdminSessionToken } from './auth.constants';
import { AuthService, type AuthUser } from './auth.service';

export type AuthenticatedRequest = Request & { user: AuthUser };

@Injectable()
export class AdminSessionGuard implements CanActivate {
  constructor(private readonly authService: AuthService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<Request>();
    const user = await this.authService.me(readAdminSessionToken(request));
    (request as AuthenticatedRequest).user = user;
    return true;
  }
}
