// 用户管理写操作（Task 5）：重置密码 / 封禁 / 删号 / 补发成就打卡 / 重置昵称头像 + 反馈处理。
import { randomBytes } from 'crypto';
import { COL } from '../../config';
import { getDb } from '../../db';
import { bad, notFound, ok, Req } from '../../http';
import { hashPassword } from '../../password';
import { UserProfile } from '../../types';
import { audit } from './audit';

function sanitizeUser(u: UserProfile) {
  const { passwordHash, ...rest } = u;
  return rest;
}

// 无歧义字符集：去掉 0O1lI（数字 0/字母 O、数字 1/小写 l/大写 I 易混）和 Bb8（裁决字面要求）
const PW_CHARS = 'abcdefghjkmnpqrstuvwxyzACDEFGHJKLMNPQRSTUVWXYZ23456789';

function genPassword(len = 8): string {
  const bytes = randomBytes(len);
  let s = '';
  for (let i = 0; i < len; i++) s += PW_CHARS[bytes[i] % PW_CHARS.length];
  return s;
}

/** POST /admin/users/:uid/reset-password —— 生成随机密码写库，明文只在这次响应里返回一次 */
export async function resetPassword(_req: Req, uid: string) {
  const db = getDb();
  const user = await db.getProfile(uid);
  if (!user) return notFound();
  const password = genPassword();
  await db.upsertProfile(uid, { passwordHash: hashPassword(password) });
  await audit('reset-password', 'users', uid);
  return ok({ password });
}

/** POST /admin/users/:uid/ban  body {banned: boolean} */
export async function ban(req: Req, uid: string) {
  const banned = req.body?.banned;
  if (typeof banned !== 'boolean') return bad('banned_required');
  const db = getDb();
  const user = await db.getProfile(uid);
  if (!user) return notFound();
  const next = await db.upsertProfile(uid, { banned });
  await audit(banned ? 'ban' : 'unban', 'users', uid);
  return ok({ user: sanitizeUser(next) });
}

/** POST /admin/users/:uid/delete —— 复用现有软删逻辑（用户 + 三张同步表全软删） */
export async function remove(_req: Req, uid: string) {
  const db = getDb();
  const user = await db.getProfile(uid);
  if (!user) return notFound();
  await db.softDeleteUser(uid);
  await audit('delete', 'users', uid);
  return ok({ deleted: true });
}

/** 新 key 合入 existing，已有 key 不覆盖；值不是正数时缺省用 now。无新 key 时返回 undefined（不产生 patch）。 */
function mergeGrant(
  existing: Record<string, number> | undefined,
  incoming: unknown,
  now: number,
): Record<string, number> | undefined {
  if (!incoming || typeof incoming !== 'object') return undefined;
  const merged = { ...(existing ?? {}) };
  let changed = false;
  for (const [k, v] of Object.entries(incoming as Record<string, unknown>)) {
    if (k in merged) continue;
    merged[k] = typeof v === 'number' && v > 0 ? v : now;
    changed = true;
  }
  return changed ? merged : undefined;
}

/** POST /admin/users/:uid/grant  body {achievements?, checkins?} —— 与现有并集语义一致 */
export async function grant(req: Req, uid: string) {
  const db = getDb();
  const user = await db.getProfile(uid);
  if (!user) return notFound();
  const b = req.body ?? {};
  const now = Date.now();

  const patch: Record<string, unknown> = {};
  const achievements = mergeGrant(user.achievements, b.achievements, now);
  if (achievements) patch.achievements = achievements;
  const checkins = mergeGrant(user.checkins, b.checkins, now);
  if (checkins) patch.checkins = checkins;
  if (Object.keys(patch).length === 0) return bad('nothing_to_grant');

  const next = await db.upsertProfile(uid, patch);
  await audit('grant', 'users', uid, b);
  return ok({ user: sanitizeUser(next) });
}

/** POST /admin/users/:uid/reset-profile  body {nickname?: true, avatar?: true} */
export async function resetProfile(req: Req, uid: string) {
  const db = getDb();
  const user = await db.getProfile(uid);
  if (!user) return notFound();
  const b = req.body ?? {};
  if (b.nickname !== true && b.avatar !== true) return bad('nothing_to_reset');

  const patch: Record<string, unknown> = {};
  if (b.nickname === true) patch.nickname = '用户' + uid.slice(-4);
  if (b.avatar === true) patch.avatarUrl = null;

  const next = await db.upsertProfile(uid, patch);
  await audit('reset-profile', 'users', uid, b);
  return ok({ user: sanitizeUser(next) });
}

/** POST /admin/feedback/:id  body {handled?: boolean, note?: string} */
export async function feedbackUpdate(req: Req, id: string) {
  const b = req.body ?? {};
  const patch: Record<string, unknown> = {};
  if (typeof b.handled === 'boolean') patch.handled = b.handled;
  if (typeof b.note === 'string') patch.note = b.note.slice(0, 1000);
  if (Object.keys(patch).length === 0) return bad('nothing_to_update');

  await getDb().upsertDoc(COL.feedback, id, patch);
  await audit('update', 'feedback', id, patch);
  return ok({ id });
}

/** POST /admin/feedback/:id/delete —— 物理删 */
export async function feedbackDelete(_req: Req, id: string) {
  await getDb().deleteDoc(COL.feedback, id);
  await audit('delete', 'feedback', id);
  return ok({ id });
}
