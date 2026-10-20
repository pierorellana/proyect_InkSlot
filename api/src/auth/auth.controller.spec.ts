import type { Response } from 'express';

import { AuthController } from './auth.controller';
import type { AuthService } from './auth.service';

describe('AuthController production session cookie', () => {
  const originalNodeEnv = process.env.NODE_ENV;

  afterEach(() => {
    if (originalNodeEnv === undefined) {
      delete process.env.NODE_ENV;
    } else {
      process.env.NODE_ENV = originalNodeEnv;
    }
  });

  it('marks the session cookie cross-site compatible in production', async () => {
    process.env.NODE_ENV = 'production';
    const cookie = jest.fn();
    const service = {
      login: jest.fn().mockResolvedValue({
        user: { id: 'artist-1', name: 'Dodogio', role: 'admin' },
        sessionToken: 'session-token',
      }),
    } as unknown as AuthService;
    const controller = new AuthController(service);

    await controller.login(
      { email: 'dodo', password: 'test-password' },
      { cookie } as unknown as Response,
    );

    expect(cookie).toHaveBeenCalledWith(
      'inkslot_session',
      'session-token',
      expect.objectContaining({
        httpOnly: true,
        sameSite: 'none',
        secure: true,
      }),
    );
  });
});
