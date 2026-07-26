import { JWT_SECRET } from '../config';
import { getDb } from '../db';
import { bad, json, ok, Req } from '../http';
import { signJwt } from '../jwt';
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

/** POST /api/auth/register  {email, password, nickname?} */
export async function register(req: Req) {
  const b = req.body ?? {};
  const email = String(b.email ?? '').trim().toLowerCase();
  const password = String(b.password ?? '');
  if (!EMAIL_RE.test(email)) return bad('invalid_email');
  if (password.length < 6) return bad('weak_password');

  const db = getDb();
  if (await db.getUserByEmail(email)) return json(409, { error: 'email_exists' });

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
