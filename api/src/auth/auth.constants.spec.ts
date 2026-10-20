import {
  resolveAdminSessionSameSite,
  resolveLoginEmail,
} from './auth.constants';

describe('resolveAdminSessionSameSite', () => {
  it('allows the deployed Netlify frontend to send the session cookie', () => {
    expect(resolveAdminSessionSameSite({ NODE_ENV: 'production' })).toBe(
      'none',
    );
  });

  it('keeps local development on lax cookies', () => {
    expect(resolveAdminSessionSameSite({ NODE_ENV: 'development' })).toBe(
      'lax',
    );
  });
});

describe('resolveLoginEmail', () => {
  const productionEnv = {
    ADMIN_LOGIN_USERNAME: 'dodo',
    ADMIN_EMAIL: 'piero@example.test',
    DEMO_LOGIN_USERNAME: 'dodo',
    DEMO_ARTIST_EMAIL: 'demo@inkslot.local',
  };

  it('resolves the configured production username', () => {
    expect(resolveLoginEmail(' DODO ', productionEnv)).toBe(
      'piero@example.test',
    );
  });

  it('normalizes direct email logins', () => {
    expect(resolveLoginEmail(' Artist@Example.com ', productionEnv)).toBe(
      'artist@example.com',
    );
  });

  it('does not use DEMO_* values for runtime login resolution', () => {
    expect(
      resolveLoginEmail('dodo', {
        DEMO_LOGIN_USERNAME: 'dodo',
        DEMO_ARTIST_EMAIL: 'demo@inkslot.local',
      }),
    ).toBe('dodo');
  });
});
