import { Injectable, UnauthorizedException } from '@nestjs/common';
import * as argon2 from 'argon2';
import { createHash, randomBytes } from 'node:crypto';

import { PrismaService } from '../database/prisma.service';
import {
  ADMIN_SESSION_TTL_MS,
  ADMIN_SESSION_TTL_SECONDS,
  resolveLoginEmail,
} from './auth.constants';

export type AuthUser = {
  id: string;
  name: string;
  role: 'admin';
};

export type AuthLoginResult = {
  user: AuthUser;
  sessionToken: string;
  sessionMaxAgeSeconds: number;
};

const invalidCredentials = (): UnauthorizedException =>
  new UnauthorizedException({
    error: {
      code: 'AUTH_INVALID',
      message: 'Credenciales inválidas',
    },
  });

@Injectable()
export class AuthService {
  constructor(private readonly prisma: PrismaService) {}

  async login(email: string, password: string): Promise<AuthLoginResult> {
    const artist = await this.prisma.artist.findUnique({
      where: { email: resolveLoginEmail(email) },
    });

    if (!artist?.active) {
      throw invalidCredentials();
    }

    let passwordMatches = false;
    try {
      passwordMatches = await argon2.verify(artist.passwordHash, password);
    } catch {
      throw invalidCredentials();
    }

    if (!passwordMatches) {
      throw invalidCredentials();
    }

    const sessionToken = randomBytes(32).toString('base64url');
    await this.prisma.adminSession.create({
      data: {
        artistId: artist.id,
        tokenHash: this.hashSessionToken(sessionToken),
        expiresAt: new Date(Date.now() + ADMIN_SESSION_TTL_MS),
      },
    });

    return {
      user: this.toAuthUser(artist.id, artist.displayName),
      sessionToken,
      sessionMaxAgeSeconds: ADMIN_SESSION_TTL_SECONDS,
    };
  }

  async me(sessionToken: string | undefined): Promise<AuthUser> {
    const session = await this.findValidSession(sessionToken);

    await this.prisma.adminSession.update({
      where: { id: session.id },
      data: { lastSeenAt: new Date() },
    });

    return this.toAuthUser(session.artist.id, session.artist.displayName);
  }

  async logout(sessionToken: string | undefined): Promise<void> {
    if (!sessionToken) return;

    await this.prisma.adminSession.updateMany({
      where: {
        tokenHash: this.hashSessionToken(sessionToken),
        revokedAt: null,
      },
      data: { revokedAt: new Date() },
    });
  }

  private async findValidSession(sessionToken: string | undefined) {
    if (!sessionToken) {
      throw invalidCredentials();
    }

    const session = await this.prisma.adminSession.findUnique({
      where: { tokenHash: this.hashSessionToken(sessionToken) },
      include: { artist: true },
    });
    const now = Date.now();

    if (
      !session ||
      session.revokedAt !== null ||
      session.expiresAt.getTime() <= now ||
      !session.artist.active
    ) {
      throw invalidCredentials();
    }

    return session;
  }

  private hashSessionToken(sessionToken: string): string {
    return createHash('sha256').update(sessionToken).digest('hex');
  }

  private toAuthUser(id: string, name: string): AuthUser {
    return { id, name, role: 'admin' };
  }
}
