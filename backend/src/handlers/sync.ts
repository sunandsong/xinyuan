import { getDb } from '../db';
import { bad, ok, Req } from '../http';
import { PushBody } from '../types';

/** GET /api/sync/pull?since=<ts> —— 拉取增量（含软删除，供本地传播删除） */
export async function pull(req: Req, uid: string) {
  const since = Number(req.query.since ?? '0') || 0;
  const result = await getDb().pull(uid, since);
  return ok(result);
}

/** POST /api/sync/push —— 批量上传本地变更（LWW：updatedAt 大者胜） */
export async function push(req: Req, uid: string) {
  const body = (req.body ?? {}) as PushBody;
  const db = getDb();

  const wishes = (body.wishes ?? []).filter((w) => w && w._id && typeof w.updatedAt === 'number');
  const tasks = (body.tasks ?? []).filter((t) => t && t._id && typeof t.updatedAt === 'number');

  if (wishes.length > 2000 || tasks.length > 2000) return bad('too_many_items');

  await db.upsertWishes(uid, wishes);
  await db.upsertTasks(uid, tasks);
  if (body.profile) await db.upsertProfile(uid, body.profile);

  // 返回服务端最新时间，客户端存为下次 pull 的 since
  return ok({ now: Date.now(), accepted: { wishes: wishes.length, tasks: tasks.length } });
}
