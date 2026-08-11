import { COL, JWT_SECRET } from '../config';
import { getDb } from '../db';
import { bad, json, ok, Req } from '../http';
import { signJwt } from '../jwt';
import { hashPassword, verifyPassword } from '../password';
import { UserProfile } from '../types';

// 账号：3–20 位字母/数字/下划线（大小写不敏感，统一小写存）
const ACCOUNT_RE = /^[a-zA-Z0-9_]{3,20}$/;

function publicProfile(u: UserProfile) {
  const { passwordHash, ...rest } = u;
  return rest;
}
function genUid() {
  return 'u_' + Date.now().toString(36) + Math.random().toString(36).slice(2, 8);
}

/** POST /api/auth/register  {account, password, nickname?} */
export async function register(req: Req) {
  const b = req.body ?? {};
  const account = String(b.account ?? '').trim().toLowerCase();
  const password = String(b.password ?? '');
  if (!ACCOUNT_RE.test(account)) return bad('invalid_account');
  if (password.length < 6) return bad('weak_password');

  const db = getDb();
  if (await db.getUserByAccount(account)) return json(409, { error: 'account_exists' });

  const now = Date.now();
  const user: UserProfile = {
    _id: genUid(),
    account,
    passwordHash: hashPassword(password),
    nickname: b.nickname ? String(b.nickname).slice(0, 20) : account,
    avatarEmoji: null,
    createdAt: now,
    updatedAt: now,
  };
  await db.createUser(user);
  const token = signJwt({ uid: user._id }, JWT_SECRET);
  return ok({ token, profile: publicProfile(user) });
}

/** POST /api/auth/login  {account, password, device?, os?, appVersion?} */
export async function login(req: Req) {
  const b = req.body ?? {};
  const account = String(b.account ?? '').trim().toLowerCase();
  const password = String(b.password ?? '');

  const user = await getDb().getUserByAccount(account);
  if (!user || user.deleted || !user.passwordHash || !verifyPassword(password, user.passwordHash)) {
    return json(401, { error: 'invalid_credentials' });
  }
  // 401 而不是 400：跟 pull/push 的封禁拦截返回值约定一致（unauthorized() 是 {error:'unauthorized'}，
  // 这里要保留更具体的 'banned' 文案，所以现取 json() 而不是复用 unauthorized()）
  if (user.banned) return json(401, { error: 'banned' });
  const token = signJwt({ uid: user._id }, JWT_SECRET);

  // 打点：登录日志 + 盖 lastLoginAt。绝不能因为这个挡登录，两件事都单独吞错。
  const now = Date.now();
  const db = getDb();
  const ip = String(req.headers['x-forwarded-for'] ?? '').split(',')[0].trim() || null;
  try {
    await db.upsertDoc(COL.logins, undefined, {
      uid: user._id,
      at: now,
      device: b.device ?? null,
      os: b.os ?? null,
      appVersion: b.appVersion ?? null,
      ip,
    });
  } catch {}
  try {
    await db.upsertDoc(COL.users, user._id, { lastLoginAt: now });
  } catch {}

  return ok({ token, profile: publicProfile(user) });
}
