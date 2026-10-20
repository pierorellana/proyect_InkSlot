export type SecurityConfig = {
  nodeEnv: string;
  allowedOrigins: readonly string[];
};

const LOCAL_ORIGINS = [
  'http://localhost:8080',
  'http://127.0.0.1:8080',
] as const;

export function readSecurityConfig(
  env: NodeJS.ProcessEnv = process.env,
): SecurityConfig {
  const nodeEnv = env.NODE_ENV?.trim() || 'development';
  const configured = (env.CORS_ALLOWED_ORIGINS ?? '')
    .split(',')
    .map((origin) => normalizeOrigin(origin))
    .filter((origin): origin is string => origin !== null);
  const allowedOrigins =
    configured.length > 0
      ? [...new Set(configured)]
      : nodeEnv === 'production'
        ? []
        : [...LOCAL_ORIGINS];

  if (nodeEnv === 'production' && allowedOrigins.length === 0) {
    throw new Error(
      'CORS_ALLOWED_ORIGINS must contain at least one origin in production',
    );
  }

  return { nodeEnv, allowedOrigins };
}

export function normalizeOrigin(value: string): string | null {
  const trimmed = value.trim();
  if (!trimmed || trimmed === '*') return null;
  try {
    const url = new URL(trimmed);
    if (!['http:', 'https:'].includes(url.protocol)) return null;
    if (url.pathname !== '/' || url.search || url.hash) return null;
    return url.origin;
  } catch {
    return null;
  }
}

export function isCorsOriginAllowed(
  origin: string | undefined,
  config: SecurityConfig,
): boolean {
  return origin === undefined || config.allowedOrigins.includes(origin);
}

export function isRequestOriginAllowed(
  origin: string | undefined,
  referer: string | undefined,
  config: SecurityConfig,
): boolean {
  const candidate = origin ?? originFromReferer(referer);
  if (candidate === undefined) return config.nodeEnv !== 'production';
  return config.allowedOrigins.includes(candidate);
}

function originFromReferer(referer: string | undefined): string | undefined {
  if (!referer) return undefined;
  try {
    return new URL(referer).origin;
  } catch {
    return undefined;
  }
}
