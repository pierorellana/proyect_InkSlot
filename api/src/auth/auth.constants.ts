import type { Request } from 'express';

export const ADMIN_SESSION_COOKIE = 'inkslot_session';
export const ADMIN_SESSION_TTL_SECONDS = 7 * 24 * 60 * 60;
export const ADMIN_SESSION_TTL_MS = ADMIN_SESSION_TTL_SECONDS * 1000;

export const resolveLoginEmail = (
  login: string,
  env: NodeJS.ProcessEnv = process.env,
): string => {
  const normalizedLogin = login.trim().toLowerCase();
  const configuredUsername = env.ADMIN_LOGIN_USERNAME?.trim().toLowerCase();
  const configuredEmail = env.ADMIN_EMAIL?.trim().toLowerCase();

  if (
    configuredUsername &&
    configuredEmail &&
    normalizedLogin === configuredUsername
  ) {
    return configuredEmail;
  }

  return normalizedLogin;
};

export const readAdminSessionToken = (request: Request): string | undefined => {
  const cookieHeader = request.headers.cookie;
  if (!cookieHeader) return undefined;

  const cookie = cookieHeader
    .split(';')
    .map((entry) => entry.trim())
    .find((entry) => entry.startsWith(`${ADMIN_SESSION_COOKIE}=`));

  return cookie?.slice(ADMIN_SESSION_COOKIE.length + 1);
};
