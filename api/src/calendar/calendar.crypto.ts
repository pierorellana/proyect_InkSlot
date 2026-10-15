import { createCipheriv, createDecipheriv, randomBytes } from 'node:crypto';

const ALGORITHM = 'aes-256-gcm';
const IV_BYTES = 12;
const AUTH_TAG_BYTES = 16;

export class CalendarCrypto {
  constructor(private readonly key?: Buffer) {
    if (key && key.length !== 32) {
      throw new Error('Calendar encryption key must be exactly 32 bytes');
    }
  }

  encrypt(value: string): string {
    const key = this.requireKey();
    const iv = randomBytes(IV_BYTES);
    const cipher = createCipheriv(ALGORITHM, key, iv);
    const ciphertext = Buffer.concat([
      cipher.update(value, 'utf8'),
      cipher.final(),
    ]);
    const authTag = cipher.getAuthTag();

    return ['v1', iv, authTag, ciphertext]
      .map((part) => part.toString('base64url'))
      .join(':');
  }

  decrypt(payload: string): string {
    try {
      const key = this.requireKey();
      const [version, encodedIv, encodedAuthTag, encodedCiphertext] =
        payload.split(':');
      if (
        version !== 'v1' ||
        !encodedIv ||
        !encodedAuthTag ||
        !encodedCiphertext
      ) {
        throw new Error('Invalid payload');
      }

      const iv = Buffer.from(encodedIv, 'base64url');
      const authTag = Buffer.from(encodedAuthTag, 'base64url');
      const ciphertext = Buffer.from(encodedCiphertext, 'base64url');
      if (iv.length !== IV_BYTES || authTag.length !== AUTH_TAG_BYTES) {
        throw new Error('Invalid payload');
      }

      const decipher = createDecipheriv(ALGORITHM, key, iv);
      decipher.setAuthTag(authTag);
      return Buffer.concat([
        decipher.update(ciphertext),
        decipher.final(),
      ]).toString('utf8');
    } catch {
      throw new Error('Invalid encrypted calendar token');
    }
  }

  private requireKey(): Buffer {
    if (!this.key) {
      throw new Error('Calendar encryption is not configured');
    }
    return this.key;
  }
}
