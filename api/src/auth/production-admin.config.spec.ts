import {
  PRODUCTION_ADMIN_CONFIRMATION,
  readProductionAdminConfig,
} from './production-admin.config';

const validEnv = (): NodeJS.ProcessEnv => ({
  ADMIN_LOGIN_USERNAME: 'dodo',
  ADMIN_EMAIL: 'piero@example.test',
  ADMIN_PASSWORD: 'secret-from-shell',
  ADMIN_DISPLAY_NAME: 'Dodogio',
  ADMIN_BOOTSTRAP_CONFIRM: PRODUCTION_ADMIN_CONFIRMATION,
});

describe('readProductionAdminConfig', () => {
  it('normalizes the configured username and email', () => {
    const config = readProductionAdminConfig({
      ...validEnv(),
      ADMIN_LOGIN_USERNAME: ' DODO ',
      ADMIN_EMAIL: ' Piero@Example.Test ',
    });

    expect(config).toEqual({
      loginUsername: 'dodo',
      email: 'piero@example.test',
      password: 'secret-from-shell',
      displayName: 'Dodogio',
    });
  });

  it.each([
    'ADMIN_LOGIN_USERNAME',
    'ADMIN_EMAIL',
    'ADMIN_PASSWORD',
    'ADMIN_DISPLAY_NAME',
    'ADMIN_BOOTSTRAP_CONFIRM',
  ])('rejects a missing %s', (key) => {
    const env = validEnv();
    delete env[key];

    expect(() => readProductionAdminConfig(env)).toThrow(/required/i);
  });

  it('rejects an invalid email', () => {
    expect(() =>
      readProductionAdminConfig({ ...validEnv(), ADMIN_EMAIL: 'not-an-email' }),
    ).toThrow(/email/i);
  });

  it('rejects an incorrect production confirmation', () => {
    expect(() =>
      readProductionAdminConfig({
        ...validEnv(),
        ADMIN_BOOTSTRAP_CONFIRM: 'YES',
      }),
    ).toThrow(/confirmation/i);
  });

  it('does not read DEMO_PASSWORD as a fallback', () => {
    const env = validEnv();
    delete env.ADMIN_PASSWORD;
    env.DEMO_PASSWORD = 'demo-secret';

    expect(() => readProductionAdminConfig(env)).toThrow(/password|required/i);
  });
});
