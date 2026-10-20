import * as argon2 from 'argon2';
import type { PrismaClient } from '@prisma/client';

import type { ProductionAdminBootstrapConfig } from './production-admin.config';

export type ProductionAdminBootstrapResult = {
  artistId: string;
  displayName: string;
};

export async function bootstrapProductionAdmin(
  prisma: Pick<PrismaClient, 'artist'>,
  config: ProductionAdminBootstrapConfig,
): Promise<ProductionAdminBootstrapResult> {
  const passwordHash = await argon2.hash(config.password, {
    type: argon2.argon2id,
  });
  const artist = await prisma.artist.upsert({
    where: { email: config.email },
    create: {
      email: config.email,
      passwordHash,
      displayName: config.displayName,
      active: true,
    },
    update: {
      passwordHash,
      displayName: config.displayName,
      active: true,
    },
  });

  return {
    artistId: artist.id,
    displayName: artist.displayName,
  };
}
