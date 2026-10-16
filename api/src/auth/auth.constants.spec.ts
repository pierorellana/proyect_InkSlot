import { resolveLoginEmail } from './auth.constants';

describe('resolveLoginEmail', () => {
  const demoEnv = {
    DEMO_LOGIN_USERNAME: 'dodo',
    DEMO_ARTIST_EMAIL: 'demo@inkslot.local',
  };

  it('resolves the configured local demo username', () => {
    expect(resolveLoginEmail(' DODO ', demoEnv)).toBe('demo@inkslot.local');
  });

  it('keeps regular email logins compatible', () => {
    expect(resolveLoginEmail('Artist@Example.com', demoEnv)).toBe(
      'artist@example.com',
    );
  });
});
