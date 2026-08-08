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

/** 客户端只允许改这几个字段。
 *  以前 /sync/push 把 body.profile 整个透传给 upsertProfile，等于客户端能改
 *  account、passwordHash、deleted —— 改 account 撞上别人的账号名就是账号劫持。 */
export function pickProfilePatch(b: any): Record<string, unknown> {
  const patch: Record<string, unknown> = {};
  if (typeof b?.nickname === 'string') patch.nickname = b.nickname.slice(0, 20);
  if (b?.avatarEmoji === null || typeof b?.avatarEmoji === 'string') patch.avatarEmoji = b.avatarEmoji;
  if (b?.avatarUrl === null || typeof b?.avatarUrl === 'string') patch.avatarUrl = b.avatarUrl;
  if (b?.achievements && typeof b.achievements === 'object') patch.achievements = b.achievements;
  if (b?.checkins && typeof b.checkins === 'object') patch.checkins = b.checkins;
  if (b?.gender === null || typeof b?.gender === 'string') {
    patch.gender = b.gender === null ? null : String(b.gender).slice(0, 8);
  }
  if (b?.birthday === null || (typeof b?.birthday === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(b.birthday))) {
    patch.birthday = b.birthday;
  }
  for (const k of ['doneCount', 'taskCount', 'achvCount', 'placeCount'] as const) {
    if (typeof b?.[k] === 'number' && b[k] >= 0) {
      patch[k] = Math.min(Math.floor(b[k]), 100000);
    }
  }
  return patch;
}

export async function patchMe(req: Req, uid: string) {
  const patch = pickProfilePatch(req.body ?? {});
  if (Object.keys(patch).length === 0) return bad('nothing_to_update');
  const profile = await getDb().upsertProfile(uid, patch);
  return ok({ profile: pub(profile) });
}

export async function deleteAccount(_req: Req, uid: string) {
  await getDb().softDeleteUser(uid);
  // 注：CloudBase 侧账号的停用/删除按认证后台处理（见 docs §5）
  return ok({ deleted: true });
}
