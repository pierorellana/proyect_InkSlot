import {
  isCorsOriginAllowed,
  isRequestOriginAllowed,
  normalizeOrigin,
  readSecurityConfig,
} from './security.config';

describe('security config', () => {
  it('uses local web origins by default outside production', () => {
    expect(readSecurityConfig({ NODE_ENV: 'test' })).toEqual({
      nodeEnv: 'test',
      allowedOrigins: ['http://localhost:8080', 'http://127.0.0.1:8080'],
    });
  });

  it('requires an explicit origin allowlist in production', () => {
    expect(() => readSecurityConfig({ NODE_ENV: 'production' })).toThrow(
      'CORS_ALLOWED_ORIGINS',
    );
  });

  it('normalizes configured origins and rejects wildcard values', () => {
    expect(
      readSecurityConfig({
        NODE_ENV: 'production',
        CORS_ALLOWED_ORIGINS:
          ' https://studio.example/ , https://studio.example, * , ftp://bad',
      }),
    ).toEqual({
      nodeEnv: 'production',
      allowedOrigins: ['https://studio.example'],
    });
    expect(normalizeOrigin('https://studio.example/path')).toBeNull();
  });

  it('allows only configured CORS origins', () => {
    const config = readSecurityConfig({
      NODE_ENV: 'production',
      CORS_ALLOWED_ORIGINS: 'https://studio.example',
    });
    expect(isCorsOriginAllowed(undefined, config)).toBe(true);
    expect(isCorsOriginAllowed('https://studio.example', config)).toBe(true);
    expect(isCorsOriginAllowed('https://evil.example', config)).toBe(false);
  });

  it('uses referer as a fallback for origin validation', () => {
    const config = readSecurityConfig({
      NODE_ENV: 'production',
      CORS_ALLOWED_ORIGINS: 'https://studio.example',
    });
    expect(
      isRequestOriginAllowed(
        undefined,
        'https://studio.example/admin/login',
        config,
      ),
    ).toBe(true);
    expect(isRequestOriginAllowed(undefined, undefined, config)).toBe(false);
  });
});
