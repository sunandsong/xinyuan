// 数据访问层：只有 CloudBase 文档库一套实现，所有数据都落云。
// 同步统一用 Last-Write-Wins（updatedAt 大者胜），软删除用 deleted 传播。

import { COL, ENV_ID } from './config';
import { Feedback, Letter, PullResult, Share, Task, UserProfile, Wish } from './types';

export interface Db {
  getUserByAccount(account: string): Promise<UserProfile | null>;
  createUser(user: UserProfile): Promise<void>;
  getProfile(uid: string): Promise<UserProfile | null>;
  upsertProfile(uid: string, patch: Partial<UserProfile>): Promise<UserProfile>;

  pull(uid: string, since: number): Promise<PullResult>;
  upsertWishes(uid: string, items: Array<Partial<Wish> & { _id: string; updatedAt: number }>): Promise<void>;
  upsertTasks(uid: string, items: Array<Partial<Task> & { _id: string; updatedAt: number }>): Promise<void>;
  upsertLetters(uid: string, items: Array<Partial<Letter> & { _id: string; updatedAt: number }>): Promise<void>;

  createFeedback(fb: Feedback): Promise<void>;

  createShare(share: Share): Promise<void>;
  getShareByCode(code: string): Promise<Share | null>;
  bumpShareViews(code: string): Promise<void>;

  softDeleteUser(uid: string): Promise<void>;

  /** 排行榜：按 [field] 取前 [limit] 名 */
  topUsers(field: string, limit: number): Promise<UserProfile[]>;
  /** 该字段上比我多的有几个人（用来算名次，不用把全表拉下来） */
  countAbove(field: string, value: number): Promise<number>;

  /** 内容榜：哪个心愿标题被最多人完成过（跨全部用户统计，同名心愿算一起） */
  topWishTitles(limit: number): Promise<Array<{ title: string; count: number }>>;
  /** 内容榜：哪个景点被最多人打卡过 */
  topPlaces(limit: number): Promise<Array<{ place: string; count: number }>>;

  /** 内容榜穿透：哪些用户完成过这个标题的心愿 */
  usersWhoCompletedWish(title: string, limit: number): Promise<PublicUser[]>;
  /** 这个标题的心愿：多少人写进了清单、多少人已实现（按人去重，可排除自己） */
  wishTitleStats(
    title: string,
    excludeUid?: string,
  ): Promise<{ wanted: number; done: number }>;
  /** 内容榜穿透：哪些用户打卡过这个景点 */
  usersWhoCheckedIn(place: string, limit: number): Promise<PublicUser[]>;
}

/** 内容榜穿透列表只给这几样——跟排行榜一个尺度，不泄露账号名 */
export interface PublicUser {
  uid: string;
  nickname: string;
  avatarUrl: string | null;
  gender: string | null;
}

// CloudBase 文档库不允许 payload 含 _id（它是文档主键）
function noId<T extends Record<string, any>>(o: T): Omit<T, '_id'> {
  const { _id, ...rest } = o;
  return rest;
}

/** 单次查询能带回的最大条数（CloudBase 上限） */
const QUERY_LIMIT = 1000;
/** 批量 upsert 每批条数，必须 <= QUERY_LIMIT，否则查不全存在性会误当新记录覆盖 */
const UPSERT_BATCH = 500;

// ---------------- cloud（CloudBase 文档库）----------------
// 说明：CloudBase Node SDK 的 database API —— db.collection(x).where(...).get()/update()/add()，
// db.command 作比较运算。以下为标准写法；首次部署后按控制台实际返回微调即可。
class CloudDb implements Db {
  private db: any;
  private cmd: any;
  constructor() {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const cloudbase = require('@cloudbase/node-sdk');
    const app = cloudbase.init({ env: ENV_ID });
    this.db = app.database();
    this.cmd = this.db.command;
  }

  async getUserByAccount(account: string): Promise<UserProfile | null> {
    // 必须排除已注销的：否则注销后那条记录仍占着账号名，
    // 重新注册报 account_exists、登录报 invalid_credentials，账号名等于废掉
    const r = await this.db
      .collection(COL.users)
      .where({ account, deleted: this.cmd.neq(true) })
      .limit(1)
      .get();
    return r.data?.[0] ?? null;
  }
  async createUser(user: UserProfile) {
    await this.db.collection(COL.users).doc(user._id).set(noId(user));
  }
  async getProfile(uid: string): Promise<UserProfile | null> {
    const r = await this.db.collection(COL.users).doc(uid).get();
    return r.data?.[0] ?? null;
  }
  async upsertProfile(uid: string, patch: Partial<UserProfile>): Promise<UserProfile> {
    const now = Date.now();
    const exist = await this.getProfile(uid);
    if (!exist) {
      const doc: UserProfile = {
        _id: uid,
        account: patch.account ?? '',
        nickname: patch.nickname ?? '我',
        avatarEmoji: patch.avatarEmoji ?? null,
        createdAt: now,
        updatedAt: now,
      };
      await this.db.collection(COL.users).doc(uid).set(noId(doc));
      return doc;
    }
    const next = { ...exist, ...patch, _id: uid, updatedAt: now };
    await this.db.collection(COL.users).doc(uid).update(noId({ ...patch, updatedAt: now }));
    return next;
  }
  /** 按 updatedAt 升序取一页，这样被截断时还能拿最后一条当游标续拉 */
  private page(col: string, uid: string, since: number) {
    return this.db
      .collection(col)
      .where({ uid, updatedAt: this.cmd.gt(since) })
      .orderBy('updatedAt', 'asc')
      .limit(QUERY_LIMIT)
      .get();
  }

  async pull(uid: string, since: number): Promise<PullResult> {
    const [w, t, l, p] = await Promise.all([
      this.page(COL.wishes, uid, since),
      this.page(COL.tasks, uid, since),
      this.page(COL.letters, uid, since),
      this.getProfile(uid),
    ]);
    const wishes = w.data ?? [];
    const tasks = t.data ?? [];
    const letters = l.data ?? [];

    // 有集合被截断时，绝不能把 now 报成当前时间：客户端会把水位推到那里，
    // 没返回的记录就永远拉不到了。改成报「已经返回到哪一条」，下次从这儿续。
    const cut: number[] = [];
    for (const list of [wishes, tasks, letters]) {
      if (list.length === QUERY_LIMIT) cut.push(list[list.length - 1].updatedAt);
    }
    const now = cut.length === 0
      ? Date.now()
      // 多个集合都截断时取最小的游标，保证谁都不会被跳过（重复拉到的记录合并是幂等的）
      // ponytail: 同一毫秒挤满 1000 条会卡住游标，现实里不可能；真出现就得改成 (updatedAt,_id) 复合游标
      : Math.max(Math.min(...cut), since + 1);

    return { now, wishes, tasks, letters, profile: p };
  }
  /// 批量 upsert：先一次查出这批 id 里已存在的，再并发写。
  /// 原来是逐条 get 再 set，推 50 条要 100 次串行往返，云函数执行时间（按 GBs 计费）
  /// 和延迟都被这个循环吃掉了。现在是 1 次查 + N 次并发写。
  private async upsertAll(
    col: string,
    uid: string,
    items: Array<{ _id: string; updatedAt: number } & Record<string, any>>,
  ) {
    // 一次查存在性最多能带回 QUERY_LIMIT 条，所以必须按这个粒度分批。
    // 不分批的话：超出部分查不到已存在记录 → 当成新记录 .set() 整文档覆盖，
    // 绕过 LWW 和归属校验，把别人的或更新的版本盖掉。
    for (let i = 0; i < items.length; i += UPSERT_BATCH) {
      await this.upsertBatch(col, uid, items.slice(i, i + UPSERT_BATCH));
    }
  }

  private async upsertBatch(
    col: string,
    uid: string,
    items: Array<{ _id: string; updatedAt: number } & Record<string, any>>,
  ) {
    if (items.length === 0) return;
    const r = await this.db
      .collection(col)
      .where({ _id: this.cmd.in(items.map((i) => i._id)) })
      .limit(QUERY_LIMIT)
      .get();
    const exist = new Map<string, any>((r.data ?? []).map((d: any) => [d._id, d]));
    await Promise.all(
      items.map((it) => {
        const cur = exist.get(it._id);
        if (!cur) {
          return this.db.collection(col).doc(it._id).set(noId({ ...it, uid }));
        }
        // 别人的数据不许改；本地版本更旧就丢弃（LWW）
        if (cur.uid === uid && it.updatedAt >= cur.updatedAt) {
          return this.db.collection(col).doc(it._id).update(noId({ ...it, uid }));
        }
        return Promise.resolve();
      }),
    );
  }

  async upsertWishes(uid: string, items: Array<Partial<Wish> & { _id: string; updatedAt: number }>) {
    await this.upsertAll(COL.wishes, uid, items);
  }
  async upsertTasks(uid: string, items: Array<Partial<Task> & { _id: string; updatedAt: number }>) {
    await this.upsertAll(COL.tasks, uid, items);
  }
  async upsertLetters(uid: string, items: Array<Partial<Letter> & { _id: string; updatedAt: number }>) {
    await this.upsertAll(COL.letters, uid, items);
  }
  async topUsers(field: string, limit: number): Promise<UserProfile[]> {
    const r = await this.db
      .collection(COL.users)
      .where({ deleted: this.cmd.neq(true), [field]: this.cmd.gt(0) })
      .orderBy(field, 'desc')
      .limit(limit)
      .get();
    return r.data ?? [];
  }

  async countAbove(field: string, value: number): Promise<number> {
    const r = await this.db
      .collection(COL.users)
      .where({ deleted: this.cmd.neq(true), [field]: this.cmd.gt(value) })
      .count();
    return r.total ?? 0;
  }

  async topWishTitles(limit: number): Promise<Array<{ title: string; count: number }>> {
    const r = await this.db
      .collection(COL.wishes)
      .where({ done: true, deleted: this.cmd.neq(true) })
      .limit(QUERY_LIMIT)
      .get();
    const counts = new Map<string, number>();
    for (const w of r.data ?? []) {
      const t = String(w.title ?? '').trim();
      if (!t) continue;
      counts.set(t, (counts.get(t) ?? 0) + 1);
    }
    return [...counts.entries()]
      .sort((a, b) => b[1] - a[1])
      .slice(0, limit)
      .map(([title, count]) => ({ title, count }));
  }

  async topPlaces(limit: number): Promise<Array<{ place: string; count: number }>> {
    const r = await this.db
      .collection(COL.users)
      .where({ deleted: this.cmd.neq(true) })
      .limit(QUERY_LIMIT)
      .get();
    const counts = new Map<string, number>();
    for (const u of r.data ?? []) {
      for (const place of Object.keys(u.checkins ?? {})) {
        counts.set(place, (counts.get(place) ?? 0) + 1);
      }
    }
    return [...counts.entries()]
      .sort((a, b) => b[1] - a[1])
      .slice(0, limit)
      .map(([place, count]) => ({ place, count }));
  }

  async wishTitleStats(
    title: string,
    excludeUid?: string,
  ): Promise<{ wanted: number; done: number }> {
    const r = await this.db
      .collection(COL.wishes)
      .where({ title, deleted: this.cmd.neq(true) })
      .limit(QUERY_LIMIT)
      .get();
    const wanted = new Set<string>();
    const done = new Set<string>();
    for (const w of r.data ?? []) {
      const uid = String(w.uid ?? '');
      if (!uid || uid === excludeUid) continue;
      wanted.add(uid);
      if (w.done === true) done.add(uid);
    }
    return { wanted: wanted.size, done: done.size };
  }

  async usersWhoCompletedWish(title: string, limit: number): Promise<PublicUser[]> {
    // wishes 和 users 是两个表，join 不了：先查这个标题下完成过的 uid（去重），
    // 再按 uid 批量查资料。心愿标题不会太多人完成，两次查询成本可控。
    const wr = await this.db
      .collection(COL.wishes)
      .where({ title, done: true, deleted: this.cmd.neq(true) })
      .limit(QUERY_LIMIT)
      .get();
    const uids = [...new Set((wr.data ?? []).map((w: any) => w.uid as string))].slice(
      0,
      limit,
    );
    if (uids.length === 0) return [];
    const ur = await this.db
      .collection(COL.users)
      .where({ _id: this.cmd.in(uids), deleted: this.cmd.neq(true) })
      .limit(QUERY_LIMIT)
      .get();
    return (ur.data ?? []).map((u: any) => ({
      uid: u._id,
      nickname: u.nickname || '匿名',
      avatarUrl: u.avatarUrl ?? null,
      gender: u.gender ?? null,
    }));
  }

  async usersWhoCheckedIn(place: string, limit: number): Promise<PublicUser[]> {
    // checkins 是 { 景点名: 时间戳 } 的动态字段，按点路径查有没有这个 key
    const r = await this.db
      .collection(COL.users)
      .where({
        deleted: this.cmd.neq(true),
        [`checkins.${place}`]: this.cmd.exists(true),
      })
      .limit(limit)
      .get();
    return (r.data ?? []).map((u: any) => ({
      uid: u._id,
      nickname: u.nickname || '匿名',
      avatarUrl: u.avatarUrl ?? null,
      gender: u.gender ?? null,
    }));
  }

  async createFeedback(fb: Feedback) {
    await this.db.collection(COL.feedback).doc(fb._id).set(noId(fb));
  }
  async createShare(share: Share) {
    await this.db.collection(COL.shares).doc(share._id).set(noId(share));
  }
  async getShareByCode(code: string): Promise<Share | null> {
    const r = await this.db.collection(COL.shares).where({ code }).limit(1).get();
    return r.data?.[0] ?? null;
  }
  async bumpShareViews(code: string) {
    await this.db.collection(COL.shares).where({ code }).update({ views: this.cmd.inc(1) });
  }
  async softDeleteUser(uid: string) {
    await Promise.all([
      this.db.collection(COL.users).doc(uid).update({ deleted: true }),
      this.db.collection(COL.wishes).where({ uid }).update({ deleted: true, updatedAt: Date.now() }),
      this.db.collection(COL.tasks).where({ uid }).update({ deleted: true, updatedAt: Date.now() }),
      this.db.collection(COL.letters).where({ uid }).update({ deleted: true, updatedAt: Date.now() }),
    ]);
  }
}

let _db: Db | null = null;
export function getDb(): Db {
  if (!_db) _db = new CloudDb();
  return _db;
}
