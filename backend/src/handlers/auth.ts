import { CODE_MAX_ATTEMPTS, CODE_RESEND_INTERVAL_MS, CODE_TTL_MS, JWT_SECRET } from '../config';
import { getDb } from '../db';
import { bad, json, ok, Req } from '../http';
import { signJwt } from '../jwt';
import { sendVerificationCode } from '../mail';
import { hashPassword, verifyPassword } from '../password';
import { UserProfile } from '../types';

const EMAIL_RE = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;

function publicProfile(u: UserProfile) {
  const { passwordHash, ...rest } = u;
  return rest;
}
function genUid() {
  return 'u_' + Date.now().toString(36) + Math.random().toString(36).slice(2, 8);
}
// TODO(上线前必改)：还没接真实 SMTP，验证码先写死方便联调；
// 接上邮件发送后要改回随机生成，否则任何人都能用别人的邮箱注册。
function genCode() {
  return '123456';
}

/** POST /api/auth/send-code  {email, purpose?: 'register'} 发送注册邮箱验证码 */
export async function sendCode(req: Req) {
  const b = req.body ?? {};
  const email = String(b.email ?? '').trim().toLowerCase();
  const purpose = String(b.purpose ?? 'register');
  if (!EMAIL_RE.test(email)) return bad('invalid_email');
  if (purpose !== 'register') return bad('invalid_purpose');

  const db = getDb();
  if (await db.getUserByEmail(email)) return json(409, { error: 'email_exists' });

  const now = Date.now();
  const exist = await db.getEmailCode(email, purpose);
  if (exist && now - exist.lastSentAt < CODE_RESEND_INTERVAL_MS) {
    return json(429, { error: 'code_rate_limited' });
  }

  const code = genCode();
  await sendVerificationCode(email, code);
  await db.saveEmailCode({
    _id: `${purpose}:${email}`,
    email,
    purpose: 'register',
    code,
    expiresAt: now + CODE_TTL_MS,
    attempts: 0,
    lastSentAt: now,
  });
  return ok();
}

/** POST /api/auth/register  {email, password, code, nickname?} */
export async function register(req: Req) {
  const b = req.body ?? {};
  const email = String(b.email ?? '').trim().toLowerCase();
  const password = String(b.password ?? '');
  const code = String(b.code ?? '').trim();
  if (!EMAIL_RE.test(email)) return bad('invalid_email');
  if (password.length < 6) return bad('weak_password');
  if (!code) return bad('code_required');

  const db = getDb();
  if (await db.getUserByEmail(email)) return json(409, { error: 'email_exists' });

  const rec = await db.getEmailCode(email, 'register');
  if (!rec || rec.expiresAt < Date.now()) return json(400, { error: 'code_expired' });
  if (rec.attempts >= CODE_MAX_ATTEMPTS) return json(429, { error: 'code_too_many_attempts' });
  if (rec.code !== code) {
    await db.saveEmailCode({ ...rec, attempts: rec.attempts + 1 });
    return json(400, { error: 'invalid_code' });
  }
  await db.deleteEmailCode(email, 'register');

  const now = Date.now();
  const user: UserProfile = {
    _id: genUid(),
    email,
    passwordHash: hashPassword(password),
    nickname: b.nickname ? String(b.nickname).slice(0, 20) : email.split('@')[0],
    avatarEmoji: null,
    createdAt: now,
    updatedAt: now,
  };
  await db.createUser(user);
  const token = signJwt({ uid: user._id }, JWT_SECRET);
  return ok({ token, profile: publicProfile(user) });
}

/** POST /api/auth/login  {email, password} */
export async function login(req: Req) {
  const b = req.body ?? {};
  const email = String(b.email ?? '').trim().toLowerCase();
  const password = String(b.password ?? '');

  const user = await getDb().getUserByEmail(email);
  if (!user || user.deleted || !user.passwordHash || !verifyPassword(password, user.passwordHash)) {
    return json(401, { error: 'invalid_credentials' });
  }
  const token = signJwt({ uid: user._id }, JWT_SECRET);
  return ok({ token, profile: publicProfile(user) });
}
