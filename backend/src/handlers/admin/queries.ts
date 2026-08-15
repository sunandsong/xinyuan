// 管理查询 API：stats 总览 / 用户列表详情 / 反馈 / 登录日志 / 事件。只读，不改数据。
import { COL } from '../../config';
import { getDb } from '../../db';
import { notFound, ok, Req } from '../../http';
import { UserProfile } from '../../types';
import { pageLimit } from './paging';

const DAY = 86_400_000;

function sanitizeUser(u: UserProfile) {
  const { passwordHash, ...rest } = u;
  return rest;
}

function dayKey(ts: number): string {
  const d = new Date(ts);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

/** 近 N 天的 day key 列表，从 (N-1) 天前到今天，升序 */
function recentDayKeys(days: number): string[] {
  const now = Date.now();
  return Array.from({ length: days }, (_, i) => dayKey(now - (days - 1 - i) * DAY));
}

/** 本周一 0 点（本地时区） */
function weekStart(): number {
  const d = new Date();
  d.setHours(0, 0, 0, 0);
  const day = d.getDay();
  d.setDate(d.getDate() - (day === 0 ? 6 : day - 1));
  return d.getTime();
}

/** GET /admin/stats —— 近 30 天总览：总量、日序列、留存、热榜、活跃分布 */
export async function stats(_req: Req) {
  const db = getDb();
  const users = await db.allUsers();
  const demoUids = users.filter((u) => u.isDemo).map((u) => u._id);
  const demoSet = new Set(demoUids);
  const liveUsers = users.filter((u) => !u.isDemo);

  const [wishes, tasks, logins, events, feedbackOpen, tasksCount, lettersCount, topWishes, topPlaces] =
    await Promise.all([
      db.allWishes(),
      db.allTasks(),
      db.allLogins(),
      db.allEvents(),
      db.countFeedbackOpen(demoUids),
      db.countActive(COL.tasks, demoUids),
      db.countActive(COL.letters, demoUids),
      db.topWishTitles(10),
      db.topPlaces(10),
    ]);

  const liveWishes = wishes.filter((w) => !demoSet.has(w.uid));
  const liveTasks = tasks.filter((t) => !demoSet.has(t.uid));
  const liveLogins = logins.filter((l) => !demoSet.has(l.uid));
  const liveEvents = events.filter((e) => !demoSet.has(e.uid));

  const week0 = weekStart();
  const totals = {
    users: liveUsers.length,
    weekActive: liveUsers.filter((u) => (u.lastActiveAt ?? 0) >= week0).length,
    weekRegistered: liveUsers.filter((u) => u.createdAt >= week0).length,
    weekCreatedTasks: liveTasks.filter((t) => t.createdAt >= week0).length,
    weekCompletedTasks: liveTasks.filter((t) => t.done && t.updatedAt >= week0).length,
    weekCompletedWishes: liveWishes.filter((w) => w.done && (w.doneAt ?? 0) >= week0).length,
    wishes: liveWishes.length,
    doneWishes: liveWishes.filter((w) => w.done).length,
    tasks: tasksCount,
    letters: lettersCount,
    feedbackOpen,
  };

  // 日序列：近 30 天，signups 按注册、dau/logins 按登录日志（内存 reduce）
  const days = recentDayKeys(30);
  const signupCount = new Map<string, number>();
  for (const u of liveUsers) {
    const k = dayKey(u.createdAt);
    signupCount.set(k, (signupCount.get(k) ?? 0) + 1);
  }
  const dauUidsByDay = new Map<string, Set<string>>();
  const loginCountByDay = new Map<string, number>();
  for (const l of liveLogins) {
    const k = dayKey(l.at);
    loginCountByDay.set(k, (loginCountByDay.get(k) ?? 0) + 1);
    if (!dauUidsByDay.has(k)) dauUidsByDay.set(k, new Set());
    dauUidsByDay.get(k)!.add(l.uid);
  }
  const series = {
    signups: days.map((k) => [k, signupCount.get(k) ?? 0] as [string, number]),
    dau: days.map((k) => [k, dauUidsByDay.get(k)?.size ?? 0] as [string, number]),
    logins: days.map((k) => [k, loginCountByDay.get(k) ?? 0] as [string, number]),
  };

  // 留存：近 30 天注册用户里，注册 N 天后仍有登录记录的占比
  const cohortCutoff = Date.now() - 30 * DAY;
  const cohort = liveUsers.filter((u) => u.createdAt >= cohortCutoff);
  const loginsByUid = new Map<string, number[]>();
  for (const l of liveLogins) {
    if (!loginsByUid.has(l.uid)) loginsByUid.set(l.uid, []);
    loginsByUid.get(l.uid)!.push(l.at);
  }
  function retentionAt(n: number): number {
    if (cohort.length === 0) return 0;
    const hit = cohort.filter((u) => {
      const ats = loginsByUid.get(u._id);
      if (!ats) return false;
      const threshold = u.createdAt + n * DAY;
      return ats.some((at) => at >= threshold);
    }).length;
    return hit / cohort.length;
  }
  const retention = { d1: retentionAt(1), d7: retentionAt(7), d30: retentionAt(30) };

  // topEvents：近 7 天，按 event 计数 Top10
  const eventCutoff = Date.now() - 7 * DAY;
  const eventCount = new Map<string, number>();
  for (const e of liveEvents) {
    if (e.at < eventCutoff) continue;
    eventCount.set(e.event, (eventCount.get(e.event) ?? 0) + 1);
  }
  const topEvents = [...eventCount.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, 10) as Array<[string, number]>;

  // activeBuckets：按 lastActiveAt 距今分档，从没活跃过也算 sleep
  const now = Date.now();
  const activeBuckets = { today: 0, week: 0, month: 0, sleep: 0 };
  for (const u of liveUsers) {
    const diff = now - (u.lastActiveAt ?? 0);
    if (u.lastActiveAt && diff < DAY) activeBuckets.today++;
    else if (u.lastActiveAt && diff < 7 * DAY) activeBuckets.week++;
    else if (u.lastActiveAt && diff < 30 * DAY) activeBuckets.month++;
    else activeBuckets.sleep++;
  }

  return ok({ totals, series, retention, topEvents, topWishes, topPlaces, activeBuckets });
}

/** GET /admin/users?q=&sort=&skip= —— 用户列表，附心愿 done/total */
export async function userList(req: Req) {
  const q = req.query ?? {};
  const kw = (q.q ?? '').trim().toLowerCase();
  const sortField = ['lastActiveAt', 'createdAt', 'doneCount'].includes(q.sort) ? q.sort : 'lastActiveAt';
  const skip = Math.max(0, Number(q.skip) || 0);
  const PAGE_SIZE = pageLimit(q);

  const db = getDb();
  const users = (await db.allUsers()).filter((u) => !u.isDemo);
  let filtered = kw
    ? users.filter(
        (u) =>
          (u.account ?? '').toLowerCase().includes(kw) || (u.nickname ?? '').toLowerCase().includes(kw),
      )
    : users;

  const flag = (v?: string) => v === '1' || v === 'true';
  const needWishes = flag(q.hasWishes);
  const needTasks = flag(q.hasTasks);
  const needLetters = flag(q.hasLetters);

  const [allWishes, allTasks, allLetters] = await Promise.all([
    needWishes ? db.allWishes() : Promise.resolve(null),
    needTasks ? db.allTasks() : Promise.resolve(null),
    needLetters ? db.allLetters() : Promise.resolve(null),
  ]);

  if (needWishes || needTasks || needLetters) {
    const withData = new Set<string>();
    if (allWishes) for (const w of allWishes) withData.add(w.uid);
    if (allTasks) for (const t of allTasks) withData.add(t.uid);
    if (allLetters) for (const l of allLetters) withData.add(l.uid);
    filtered = filtered.filter((u) => withData.has(u._id));
  }

  filtered.sort((a: any, b: any) => (b[sortField] ?? 0) - (a[sortField] ?? 0));

  const page = filtered.slice(skip, skip + PAGE_SIZE);
  const pageUids = new Set(page.map((u) => u._id));

  const wishAgg = new Map<string, { total: number; done: number }>();
  const taskAgg = new Map<string, number>();
  const letterAgg = new Map<string, number>();

  const wishesForPage = allWishes
    ? allWishes.filter((w) => pageUids.has(w.uid))
    : (await db.allWishes()).filter((w) => pageUids.has(w.uid));
  for (const w of wishesForPage) {
    const a = wishAgg.get(w.uid) ?? { total: 0, done: 0 };
    a.total++;
    if (w.done) a.done++;
    wishAgg.set(w.uid, a);
  }

  if (allTasks) {
    for (const t of allTasks) {
      if (!pageUids.has(t.uid)) continue;
      taskAgg.set(t.uid, (taskAgg.get(t.uid) ?? 0) + 1);
    }
  }

  if (allLetters) {
    for (const l of allLetters) {
      if (!pageUids.has(l.uid)) continue;
      letterAgg.set(l.uid, (letterAgg.get(l.uid) ?? 0) + 1);
    }
  }

  const items = page.map((u) => ({
    ...sanitizeUser(u),
    wishTotal: wishAgg.get(u._id)?.total ?? 0,
    wishDone: wishAgg.get(u._id)?.done ?? 0,
    taskTotal: taskAgg.get(u._id) ?? 0,
    letterTotal: letterAgg.get(u._id) ?? 0,
  }));

  return ok({ items, total: filtered.length });
}

/** GET /admin/users/:uid —— 用户详情 + wishes/tasks/letters 计数 + 最近 10 条登录 */
export async function userDetail(_req: Req, uid: string) {
  const db = getDb();
  const user = await db.getProfile(uid);
  if (!user) return notFound();

  const [wishes, tasks, letters, logins] = await Promise.all([
    db.listDocs(COL.wishes, { where: { uid }, excludeTrue: ['deleted'], limit: 1 }),
    db.listDocs(COL.tasks, { where: { uid }, excludeTrue: ['deleted'], limit: 1 }),
    db.listDocs(COL.letters, { where: { uid }, excludeTrue: ['deleted'], limit: 1 }),
    db.listDocs(COL.logins, { where: { uid }, limit: 10, orderBy: 'at', orderDir: 'desc' }),
  ]);

  return ok({
    user: sanitizeUser(user),
    counts: { wishes: wishes.total, tasks: tasks.total, letters: letters.total },
    recentLogins: logins.items,
  });
}

/** GET /admin/feedback?skip= —— 倒序分页 */
export async function feedbackList(req: Req) {
  const q = req.query ?? {};
  const skip = Math.max(0, Number(q.skip) || 0);
  const { items, total } = await getDb().listDocs(COL.feedback, {
    skip,
    limit: pageLimit(q),
    orderBy: 'createdAt',
    orderDir: 'desc',
  });
  return ok({ items, total });
}

/** GET /admin/logins?uid=&days=&skip= —— 倒序分页 */
export async function loginList(req: Req) {
  const q = req.query ?? {};
  const skip = Math.max(0, Number(q.skip) || 0);
  const where: Record<string, unknown> = {};
  if (q.uid) where.uid = q.uid;
  const days = Number(q.days) || 0;
  const { items, total } = await getDb().listDocs(COL.logins, {
    skip,
    limit: pageLimit(q),
    where,
    orderBy: 'at',
    orderDir: 'desc',
    since: days > 0 ? { field: 'at', ms: days * DAY } : undefined,
  });
  return ok({ items, total });
}

/** GET /admin/events?event=&uid=&days=&skip= —— 倒序分页 */
export async function eventList(req: Req) {
  const q = req.query ?? {};
  const skip = Math.max(0, Number(q.skip) || 0);
  const where: Record<string, unknown> = {};
  if (q.uid) where.uid = q.uid;
  if (q.event) where.event = q.event;
  const days = Number(q.days) || 0;
  const { items, total } = await getDb().listDocs(COL.events, {
    skip,
    limit: pageLimit(q),
    where,
    orderBy: 'at',
    orderDir: 'desc',
    since: days > 0 ? { field: 'at', ms: days * DAY } : undefined,
  });
  return ok({ items, total });
}

/** GET /admin/crashes?kind=&days=&skip= —— 按发生次数倒序（最闹心的排最前），
 * 集合可能还没建过（一次崩溃都没上报过），按空表返回别 500。 */
export async function crashList(req: Req) {
  const q = req.query ?? {};
  const skip = Math.max(0, Number(q.skip) || 0);
  const where: Record<string, unknown> = {};
  if (q.kind) where.kind = q.kind;
  const days = Number(q.days) || 0;
  try {
    const { items, total } = await getDb().listDocs(COL.crashes, {
      skip,
      limit: pageLimit(q),
      where,
      orderBy: 'count',
      orderDir: 'desc',
      since: days > 0 ? { field: 'lastAt', ms: days * DAY } : undefined,
    });
    return ok({ items, total });
  } catch {
    return ok({ items: [], total: 0 });
  }
}
