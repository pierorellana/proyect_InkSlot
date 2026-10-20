export type ProductionAdminBootstrapConfig = {
  loginUsername: string;
  email: string;
  password: string;
  displayName: string;
};

export const PRODUCTION_ADMIN_CONFIRMATION = 'CREATE_PRODUCTION_ADMIN' as const;

const USERNAME_PATTERN = /^[a-z0-9._-]{2,64}$/;
const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

const readRequiredValue = (env: NodeJS.ProcessEnv, key: string): string => {
  const value = env[key];

  if (value === undefined || value.trim() === '') {
    throw new Error(`${key} is required`);
  }

  return value;
};

export function readProductionAdminConfig(
  env: NodeJS.ProcessEnv = process.env,
): ProductionAdminBootstrapConfig {
  const loginUsername = readRequiredValue(env, 'ADMIN_LOGIN_USERNAME')
    .trim()
    .toLowerCase();
  const email = readRequiredValue(env, 'ADMIN_EMAIL').trim().toLowerCase();
  const password = readRequiredValue(env, 'ADMIN_PASSWORD');
  const displayName = readRequiredValue(env, 'ADMIN_DISPLAY_NAME').trim();
  const confirmation = readRequiredValue(env, 'ADMIN_BOOTSTRAP_CONFIRM');

  if (!USERNAME_PATTERN.test(loginUsername)) {
    throw new Error(
      'ADMIN_LOGIN_USERNAME must contain only lowercase letters, numbers, dots, underscores or hyphens',
    );
  }

  if (!EMAIL_PATTERN.test(email)) {
    throw new Error('ADMIN_EMAIL must be a valid email');
  }

  if (confirmation !== PRODUCTION_ADMIN_CONFIRMATION) {
    throw new Error('ADMIN_BOOTSTRAP_CONFIRM contains an invalid confirmation');
  }

  return {
    loginUsername,
    email,
    password,
    displayName,
  };
}
