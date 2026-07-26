import { getDb } from '../db';
import { bad, ok, Req } from '../http';
import { UserProfile } from '../types';

function pub(u: UserProfile) {
  const { passwordHash, ...rest } = u;
  return rest;
}

export async function getMe(_req: Req, uid: string) {
  const db = getDb();
  const profile = (await db.getProfile(uid)) ?? (await db.upsertProfile(uid, {}));
  return ok({ profile: pub(profile) });
}

export async function patchMe(req: Req, uid: string) {
  const b = req.body ?? {};
  const patch: Record<string, unknown> = {};
  if (typeof b.nickname === 'string') patch.nickname = b.nickname.slice(0, 20);
  if (b.avatarEmoji === null || typeof b.avatarEmoji === 'string') patch.avatarEmoji = b.avatarEmoji;
  if (Object.keys(patch).length === 0) return bad('nothing_to_update');
  const profile = await getDb().upsertProfile(uid, patch);
  return ok({ profile: pub(profile) });
}

export async function deleteAccount(_req: Req, uid: string) {
  await getDb().softDeleteUser(uid);
  // 注：CloudBase 侧账号的停用/删除按认证后台处理（见 docs §5）
  return ok({ deleted: true });
}
