import * as argon2 from 'argon2';
import type { PrismaClient } from '@prisma/client';

import { bootstrapProductionAdmin } from './production-admin.bootstrap';
import type { ProductionAdminBootstrapConfig } from './production-admin.config';

describe('bootstrapProductionAdmin', () => {
  const config: ProductionAdminBootstrapConfig = {
    loginUsername: 'dodo',
    email: 'piero@example.test',
    password: 'secret-from-shell',
    displayName: 'Dodogio',
  };
  const upsert = jest.fn().mockResolvedValue({
    id: 'artist-id',
    displayName: 'Dodogio',
  });
  const prisma = { artist: { upsert } } as unknown as Pick<
    PrismaClient,
    'artist'
  >;

  beforeEach(() => jest.clearAllMocks());

  it('hashes with Argon2id and upserts only the Artist row', async () => {
    const result = await bootstrapProductionAdmin(prisma, config);
    const [payload] = upsert.mock.calls[0] as [
      {
        where: { email: string };
        create: {
          email: string;
          passwordHash: string;
          displayName: string;
          active: boolean;
        };
        update: {
          passwordHash: string;
          displayName: string;
          active: boolean;
        };
      },
    ];
    const passwordMatches = await argon2.verify(
      payload.create.passwordHash,
      config.password,
    );

    expect(upsert).toHaveBeenCalledTimes(1);
    expect(passwordMatches).toBe(true);
    expect(payload.where).toEqual({ email: config.email });
    expect(payload.create).toEqual({
      email: config.email,
      passwordHash: payload.create.passwordHash,
      displayName: config.displayName,
      active: true,
    });
    expect(payload.update).toEqual({
      passwordHash: payload.update.passwordHash,
      displayName: config.displayName,
      active: true,
    });
    expect(payload.create.passwordHash).toMatch(/^\$argon2id\$/);
    expect(payload.update.passwordHash).toBe(payload.create.passwordHash);
    expect(result).toEqual({ artistId: 'artist-id', displayName: 'Dodogio' });
  });
});
