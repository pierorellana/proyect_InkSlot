import { PrismaClient } from '@prisma/client';

import { readProductionAdminConfig } from '../src/auth/production-admin.config';
import { bootstrapProductionAdmin } from '../src/auth/production-admin.bootstrap';

const SAFE_VALIDATION_MESSAGES = [
  'ADMIN_LOGIN_USERNAME is required',
  'ADMIN_EMAIL is required',
  'ADMIN_PASSWORD is required',
  'ADMIN_DISPLAY_NAME is required',
  'ADMIN_BOOTSTRAP_CONFIRM is required',
  'ADMIN_LOGIN_USERNAME must contain only lowercase letters, numbers, dots, underscores or hyphens',
  'ADMIN_EMAIL must be a valid email',
  'ADMIN_BOOTSTRAP_CONFIRM contains an invalid confirmation',
] as const;

const safeValidationMessage = (error: unknown): string => {
  if (
    error instanceof Error &&
    SAFE_VALIDATION_MESSAGES.includes(
      error.message as (typeof SAFE_VALIDATION_MESSAGES)[number],
    )
  ) {
    return error.message;
  }

  return 'invalid production admin configuration';
};

const printFailure = (message?: string): void => {
  process.stderr.write(
    message
      ? `Production admin bootstrap failed: ${message}\n`
      : 'Production admin bootstrap failed\n',
  );
  process.exitCode = 1;
};

async function main(): Promise<void> {
  let config;

  try {
    config = readProductionAdminConfig();
  } catch (error) {
    printFailure(safeValidationMessage(error));
    return;
  }

  const prisma = new PrismaClient();
  let result: Awaited<ReturnType<typeof bootstrapProductionAdmin>> | undefined;
  let failed = false;

  try {
    result = await bootstrapProductionAdmin(prisma, config);
  } catch {
    failed = true;
  } finally {
    try {
      await prisma.$disconnect();
    } catch {
      failed = true;
    }
  }

  if (failed || !result) {
    printFailure();
    return;
  }

  process.stdout.write(
    `${JSON.stringify({
      bootstrapped: true,
      artistId: result.artistId,
      displayName: result.displayName,
    })}\n`,
  );
}

void main().catch(() => {
  printFailure();
});
