export type CalendarConfig = {
  configured: boolean;
  clientId?: string;
  clientSecret?: string;
  redirectUri?: string;
  calendarName: string;
  scopes: string[];
  tokenEncryptionKey?: Buffer;
};

const DEFAULT_SCOPES = [
  'https://www.googleapis.com/auth/calendar.freebusy',
  'https://www.googleapis.com/auth/calendar.events',
  'https://www.googleapis.com/auth/calendar.calendarlist.readonly',
];

const readOptional = (value: string | undefined): string | undefined => {
  const normalized = value?.trim();
  return normalized ? normalized : undefined;
};

const parseKey = (rawKey: string): Buffer => {
  const trimmed = rawKey.trim();
  const key = /^[0-9a-f]{64}$/i.test(trimmed)
    ? Buffer.from(trimmed, 'hex')
    : Buffer.from(trimmed, 'base64');

  if (key.length !== 32) {
    throw new Error(
      'GOOGLE_TOKEN_ENCRYPTION_KEY must decode to exactly 32 bytes',
    );
  }

  return key;
};

export const readCalendarConfig = (env: NodeJS.ProcessEnv): CalendarConfig => {
  const clientId = readOptional(env.GOOGLE_CLIENT_ID);
  const clientSecret = readOptional(env.GOOGLE_CLIENT_SECRET);
  const redirectUri = readOptional(env.GOOGLE_REDIRECT_URI);
  const calendarName = readOptional(env.GOOGLE_CALENDAR_NAME) ?? 'InkSlot';
  const scopes = (env.GOOGLE_CALENDAR_SCOPES?.split(',') ?? DEFAULT_SCOPES)
    .map((scope) => scope.trim())
    .filter(Boolean);
  const tokenEncryptionKey = readOptional(env.GOOGLE_TOKEN_ENCRYPTION_KEY);

  const decodedKey = tokenEncryptionKey
    ? parseKey(tokenEncryptionKey)
    : undefined;

  return {
    configured: Boolean(
      clientId && clientSecret && redirectUri && decodedKey && scopes.length,
    ),
    clientId,
    clientSecret,
    redirectUri,
    calendarName,
    scopes,
    tokenEncryptionKey: decodedKey,
  };
};
