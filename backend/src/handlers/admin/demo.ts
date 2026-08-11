// 演示用户接口（Task 6）：管理端"造"几个假账号用来演示 App 功能，不走注册/登录
// （无 account/passwordHash，登录不了）。心愿数据跟 nickname/成就/打卡一起由管理端
// 一次性描述、后端 diff 同步落库，不走真实用户的 sync push/pull 路径。
import { randomBytes } from 'crypto';
import { COL } from '../../config';
import { getDb } from '../../db';
import { bad, notFound, ok, Req } from '../../http';
import { UserProfile, Wish } from '../../types';
import { audit } from './audit';

function sanitizeUser(u: UserProfile) {
  const { passwordHash, ...rest } = u;
  return rest;
}

/** 字符串数组 → {key: 时间戳}；已有 key 沿用旧时间戳，新 key 用 now */
function toTimeMap(existing: Record<string, number> | undefined, keys: string[], now: number) {
  const out: Record<string, number> = {};
  for (const k of keys) out[k] = existing?.[k] ?? now;
  return out;
}

/** GET /admin/demo-users —— 全量，不分页（演示账号就十几个） */
export async function list(_req: Req) {
  const { items } = await getDb().listDocs(COL.users, { where: { isDemo: true }, limit: 1000 });
  return ok({ items: items.map(sanitizeUser) });
}

/**
 * POST /admin/demo-users
 * body {id?, nickname, gender?, avatarUrl?, taskCount, achievements: string[], doneWishTitles: string[], checkins: string[]}
 * 无 id 新建（生成 demo_+8位hex 的 uid），有 id 更新已有演示用户；同时 diff 同步该 uid 的心愿文档。
 */
export async function upsert(req: Req) {
  const b = req.body ?? {};
  const nickname = typeof b.nickname === 'string' ? b.nickname.trim() : '';
  if (!nickname) return bad('nickname_required');
  const taskCount = Number(b.taskCount);
  if (!Number.isFinite(taskCount) || taskCount < 0) return bad('taskCount_required');
  const achievements: string[] = Array.isArray(b.achievements)
    ? b.achievements.filter((s: unknown) => typeof s === 'string')
    : [];
  const doneWishTitles: string[] = Array.isArray(b.doneWishTitles)
    ? b.doneWishTitles.filter((s: unknown) => typeof s === 'string' && s.trim())
    : [];
  const checkins: string[] = Array.isArray(b.checkins)
    ? b.checkins.filter((s: unknown) => typeof s === 'string')
    : [];

  const db = getDb();
  const hasId = typeof b.id === 'string' && b.id;
  let uid: string;
  let existing: UserProfile | null = null;
  if (hasId) {
    uid = b.id;
    existing = await db.getProfile(uid);
    if (!existing) return notFound();
  } else {
    uid = 'demo_' + randomBytes(4).toString('hex');
  }

  const now = Date.now();
  const fields = {
    nickname,
    gender: typeof b.gender === 'string' ? b.gender : null,
    avatarUrl: typeof b.avatarUrl === 'string' ? b.avatarUrl : null,
    isDemo: true as const,
    taskCount,
    doneCount: doneWishTitles.length,
    achvCount: achievements.length,
    placeCount: checkins.length,
    achievements: toTimeMap(existing?.achievements, achievements, now),
    checkins: toTimeMap(existing?.checkins, checkins, now),
  };

  let user: UserProfile;
  if (existing) {
    user = await db.upsertProfile(uid, fields);
  } else {
    user = { _id: uid, account: '', avatarEmoji: null, createdAt: now, updatedAt: now, ...fields };
    await db.createDoc(COL.users, uid, user as unknown as Record<string, unknown>);
  }

  // diff 同步心愿：该 uid 现有（未软删的）心愿标题集合 vs 本次 doneWishTitles
  const { items: activeWishes } = await db.listDocs(COL.wishes, {
    where: { uid },
    excludeTrue: ['deleted'],
    limit: 1000,
  });
  const activeTitles = new Set((activeWishes as Wish[]).map((w) => w.title));
  const wantTitles = new Set(doneWishTitles);
  const toAdd = doneWishTitles.filter((t) => !activeTitles.has(t));
  const toRemove = (activeWishes as Wish[]).filter((w) => !wantTitles.has(w.title));

  await Promise.all([
    ...toAdd.map((title, i) =>
      db.createDoc(COL.wishes, `demo_${uid}_${now + i}`, {
        uid,
        title,
        done: true,
        doneAt: now,
        color: 'E05A5A',
        createdAt: now,
        updatedAt: now,
      }),
    ),
    ...toRemove.map((w) => db.upsertDoc(COL.wishes, w._id, { deleted: true, updatedAt: now })),
  ]);

  await audit(existing ? 'demo-update' : 'demo-create', 'users', uid, {
    added: toAdd.length,
    removed: toRemove.length,
  });
  return ok({ user: sanitizeUser(user) });
}

/** POST /admin/demo-users/:uid/delete —— 硬删 user + 其全部 wishes；防误删真实用户，仅限 isDemo===true */
export async function remove(_req: Req, uid: string) {
  const db = getDb();
  const user = await db.getProfile(uid);
  if (!user) return notFound();
  if (user.isDemo !== true) return bad('not_demo');

  const { items: wishes } = await db.listDocs(COL.wishes, { where: { uid }, limit: 1000 });
  await Promise.all([
    db.deleteDoc(COL.users, uid),
    ...wishes.map((w: any) => db.deleteDoc(COL.wishes, w._id)),
  ]);
  await audit('demo-delete', 'users', uid);
  return ok({ deleted: true });
}

/** POST /admin/demo-users/mark  body {uids: string[]} —— 一次性迁移：给已存在的假账号补 isDemo:true */
export async function mark(req: Req) {
  const uids: string[] = Array.isArray(req.body?.uids)
    ? req.body.uids.filter((u: unknown) => typeof u === 'string')
    : [];
  const db = getDb();
  let marked = 0;
  for (const uid of uids) {
    const user = await db.getProfile(uid);
    if (!user) continue;
    await db.upsertProfile(uid, { isDemo: true });
    await audit('demo-mark', 'users', uid);
    marked++;
  }
  return ok({ marked });
}
