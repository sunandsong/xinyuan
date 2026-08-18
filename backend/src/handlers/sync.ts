import { COL } from '../config';
import { getDb } from '../db';
import { bad, ok, Req } from '../http';
import { accountBlocked } from './account_guard';
import { PushBody } from '../types';
import { pickProfilePatch } from './me';

/** GET /api/sync/pull?since=<ts> —— 拉取增量（含软删除，供本地传播删除） */
export async function pull(req: Req, uid: string) {
  const since = Number(req.query.since ?? '0') || 0;
  const result = await getDb().pull(uid, since);
  // 封禁/已注销拦在数据面入口：401 走 App 端已有的处理，不单独开一套提示
  const blocked = accountBlocked(result.profile);
  if (blocked) return blocked;
  // 绝不把 passwordHash 返回客户端
  if (result.profile) {
    const { passwordHash, ...safe } = result.profile as any;
    result.profile = safe;

    // 活跃心跳：节流写（超过 1 小时才盖一次），profile 上面已经查过了，不再多发请求
    const now = Date.now();
    if (now - (safe.lastActiveAt ?? 0) > 3600_000) {
      try {
        await getDb().upsertDoc(COL.users, uid, { lastActiveAt: now });
      } catch {}
    }
  }
  return ok(result);
}

/** POST /api/sync/push —— 批量上传本地变更（LWW：updatedAt 大者胜） */
export async function push(req: Req, uid: string) {
  const body = (req.body ?? {}) as PushBody;
  const db = getDb();

  // 封禁/已注销拦在数据面入口：跟 pull 一致，多一次 getProfile 查询可接受。
  // push 这个入口尤其不能漏——放过去就等于允许把注销掉的数据推回来复活
  const profile = await db.getProfile(uid);
  const blocked = accountBlocked(profile);
  if (blocked) return blocked;

  const wishes = (body.wishes ?? []).filter((w) => w && w._id && typeof w.updatedAt === 'number');
  const tasks = (body.tasks ?? []).filter((t) => t && t._id && typeof t.updatedAt === 'number');
  const letters = (body.letters ?? []).filter((l) => l && l._id && typeof l.updatedAt === 'number');

  if (wishes.length > 2000 || tasks.length > 2000 || letters.length > 2000) return bad('too_many_items');

  await db.upsertWishes(uid, wishes);
  await db.upsertTasks(uid, tasks);
  await db.upsertLetters(uid, letters);
  if (body.profile) {
    const patch = pickProfilePatch(body.profile);
    if (Object.keys(patch).length > 0) await db.upsertProfile(uid, patch);
  }

  // 返回服务端最新时间，客户端存为下次 pull 的 since
  return ok({ now: Date.now(), accepted: { wishes: wishes.length, tasks: tasks.length, letters: letters.length } });
}
