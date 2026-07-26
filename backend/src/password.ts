// 密码哈希（Node scrypt，无外部依赖）。存储格式 saltHex:hashHex。
import { randomBytes, scryptSync, timingSafeEqual } from 'crypto';

export function hashPassword(pw: string): string {
  const salt = randomBytes(16);
  const dk = scryptSync(pw, salt, 32);
  return `${salt.toString('hex')}:${dk.toString('hex')}`;
}

export function verifyPassword(pw: string, stored: string): boolean {
  const [saltHex, hashHex] = stored.split(':');
  if (!saltHex || !hashHex) return false;
  const dk = scryptSync(pw, Buffer.from(saltHex, 'hex'), 32);
  const h = Buffer.from(hashHex, 'hex');
  return dk.length === h.length && timingSafeEqual(dk, h);
}
