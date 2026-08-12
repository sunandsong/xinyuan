// 数据访问层：只有 CloudBase 文档库一套实现，所有数据都落云。
// 同步统一用 Last-Write-Wins（updatedAt 大者胜），软删除用 deleted 传播。

import { COL, ENV_ID } from './config';
import { Feedback, Letter, PullResult, Share, Task, UserProfile, Wish } from './types';

export interface Db {
  getUserByAccount(account: string): Promise<UserProfile | null>;
  createUser(user: UserProfile): Promise<void>;
  getProfile(uid: string): Promise<UserProfile | null>;
  /** opts.replaceMaps：跳过 achievements/checkins 的并集合并，整包替换写入——
   *  演示用户编辑是 diff 语义（删掉的 key 要真的消失），并集合并会把删掉的 key 顶回来。 */
  upsertProfile(uid: string, patch: Partial<UserProfile>, opts?: { replaceMaps?: boolean }): Promise<UserProfile>;

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

  // ---- 管理端通用内容表 CRUD（Task 2）----
  /** 任意集合分页查询：where 是等值过滤条件，返回本页数据 + 命中总数；
   * orderBy 排序；since 是「field 最近 N 毫秒内」的范围过滤（等值过滤覆盖不了 gte，单独开个口子）。 */
  listDocs(
    col: string,
    opts: {
      skip?: number;
      limit?: number;
      where?: Record<string, unknown>;
      orderBy?: string;
      orderDir?: 'asc' | 'desc';
      since?: { field: string; ms: number };
      excludeTrue?: string[];
    },
  ): Promise<{ items: any[]; total: number }>;
  /** 有 id 更新、无 id 新建（新建时 id 由数据库生成并返回） */
  upsertDoc(col: string, id: string | undefined, patch: Record<string, unknown>): Promise<string>;
  /** 物理删除单条文档 */
  deleteDoc(col: string, id: string): Promise<void>;
  /** 用调用方指定的自定义 id 建新文档（.set 而非 .update，upsertDoc 的 update 分支对不存在的 id 建不了文档） */
  createDoc(col: string, id: string, doc: Record<string, unknown>): Promise<void>;
  /** 集合不存在就建（已存在时 createCollection 报错，吞掉）——hero_images 这类
   * 种子脚本没灌过数据的空表，第一次 list/写入前得有表 */
  ensureCollection(col: string): Promise<void>;

  // ---- 管理端查询聚合（Task 4）----
  /** 全部未注销用户（含 isDemo，是否排除由调用方决定） */
  allUsers(): Promise<UserProfile[]>;
  /** 全部未删除心愿（跨用户，用于 stats 汇总 / 用户列表按 uid 聚合 done/total） */
  allWishes(): Promise<Wish[]>;
  /** 全部登录日志（供 stats 的 dau/留存内存计算，一次拉全量） */
  allLogins(): Promise<Array<{ uid: string; at: number }>>;
  /** 全部行为埋点（供 stats 的 topEvents 内存计算，一次拉全量） */
  allEvents(): Promise<Array<{ uid: string; event: string; at: number }>>;
  /** col 里未删除、且 uid 不在 excludeUids 里的文档数 */
  countActive(col: string, excludeUids: string[]): Promise<number>;
  /** 未处理反馈数（handled != true），排除 excludeUids（demo 用户） */
  countFeedbackOpen(excludeUids: string[]): Promise<number>;
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

/** achievements/checkins 并集合入：新 key 才加，已有 key 保留旧值——这类「拿到即永久」的
 * 字段不适用 LWW（覆盖式 upsert 会把补发/其它端并发写入的 key 抹掉）。 */
function unionMerge(
  existing: Record<string, number> | undefined,
  incoming: unknown,
  now: number,
): Record<string, number> {
  const merged: Record<string, number> = { ...(existing ?? {}) };
  if (incoming && typeof incoming === 'object') {
    for (const [k, v] of Object.entries(incoming as Record<string, unknown>)) {
      if (k in merged) continue;
      merged[k] = typeof v === 'number' && v > 0 ? v : now;
    }
  }
  return merged;
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
  async upsertProfile(
    uid: string,
    patch: Partial<UserProfile>,
    opts?: { replaceMaps?: boolean },
  ): Promise<UserProfile> {
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
    // achievements/checkins 是「拿到即永久」的集合字段：整包替换会把补发/其它端并发写入的
    // key 抹掉。改成并集合入——新 key 才加，已有 key 保留旧时间戳。exist 上面已经查过，
    // 放在这里改（而不是每个调用方各自查一遍）不多发一次查询。
    // opts.replaceMaps 跳过这一步：演示用户编辑（demo.ts）是 diff 语义，调用方已经算好
    // 「删掉的 key 就该消失」的完整 map，并集合并会把删掉的 key 顶回来。
    const merged: Partial<UserProfile> = { ...patch };
    if (!opts?.replaceMaps) {
      if (patch.achievements) merged.achievements = unionMerge(exist.achievements, patch.achievements, now);
      if (patch.checkins) merged.checkins = unionMerge(exist.checkins, patch.checkins, now);
    }

    const next = { ...exist, ...merged, _id: uid, updatedAt: now };
    await this.db.collection(COL.users).doc(uid).update(noId({ ...merged, updatedAt: now }));
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
  // ---- 管理端通用内容表 CRUD（Task 2）----
  async listDocs(
    col: string,
    opts: {
      skip?: number;
      limit?: number;
      where?: Record<string, unknown>;
      orderBy?: string;
      orderDir?: 'asc' | 'desc';
      since?: { field: string; ms: number };
      /** 这些字段按「!= true」过滤，而不是等值匹配——软删标记等字段在老数据上可能
       * 干脆没这个 key（而不是显式 false），等值查 false 会漏掉它们。 */
      excludeTrue?: string[];
    } = {},
  ): Promise<{ items: any[]; total: number }> {
    const { skip = 0, limit = 20, where = {}, orderBy, orderDir = 'desc', since, excludeTrue } = opts;
    const w = { ...where };
    if (since) w[since.field] = this.cmd.gte(Date.now() - since.ms);
    for (const f of excludeTrue ?? []) w[f] = this.cmd.neq(true);
    // count() 和 get() 各建各的 query：同一个 query 对象连续 skip/limit/count 链式调用
    // 有互相污染的风险，分开建更保险，反正就多一次网络往返。
    const [r, c] = await Promise.all([
      (orderBy
        ? this.db.collection(col).where(w).orderBy(orderBy, orderDir)
        : this.db.collection(col).where(w)
      )
        .skip(skip)
        .limit(limit)
        .get(),
      this.db.collection(col).where(w).count(),
    ]);
    return { items: r.data ?? [], total: c.total ?? 0 };
  }

  async upsertDoc(col: string, id: string | undefined, patch: Record<string, unknown>): Promise<string> {
    if (id) {
      await this.db.collection(col).doc(id).update(noId(patch));
      return id;
    }
    const r = await this.db.collection(col).add(noId(patch));
    return r.id as string;
  }

  async deleteDoc(col: string, id: string): Promise<void> {
    await this.db.collection(col).doc(id).delete();
  }

  async createDoc(col: string, id: string, doc: Record<string, unknown>): Promise<void> {
    await this.db.collection(col).doc(id).set(noId(doc));
  }

  async ensureCollection(col: string): Promise<void> {
    try {
      await this.db.createCollection(col);
    } catch {
      // 已存在时报错，忽略
    }
  }

  // ---- 管理端查询聚合（Task 4）----
  // 这几个都是「拉一次全量、内存里算」——沿用 topWishTitles/topPlaces 的单次
  // limit(QUERY_LIMIT) 查询风格，量级是百级用户，不需要多页扫描。
  async allUsers(): Promise<UserProfile[]> {
    const r = await this.db
      .collection(COL.users)
      .where({ deleted: this.cmd.neq(true) })
      .limit(QUERY_LIMIT)
      .get();
    return r.data ?? [];
  }

  async allWishes(): Promise<Wish[]> {
    const r = await this.db
      .collection(COL.wishes)
      .where({ deleted: this.cmd.neq(true) })
      .limit(QUERY_LIMIT)
      .get();
    return r.data ?? [];
  }

  async allLogins(): Promise<Array<{ uid: string; at: number }>> {
    const r = await this.db.collection(COL.logins).limit(QUERY_LIMIT).get();
    return r.data ?? [];
  }

  async allEvents(): Promise<Array<{ uid: string; event: string; at: number }>> {
    const r = await this.db.collection(COL.events).limit(QUERY_LIMIT).get();
    return r.data ?? [];
  }

  async countActive(col: string, excludeUids: string[]): Promise<number> {
    const where: Record<string, unknown> = { deleted: this.cmd.neq(true) };
    if (excludeUids.length) where.uid = this.cmd.nin(excludeUids);
    const r = await this.db.collection(col).where(where).count();
    return r.total ?? 0;
  }

  async countFeedbackOpen(excludeUids: string[]): Promise<number> {
    const where: Record<string, unknown> = { handled: this.cmd.neq(true) };
    if (excludeUids.length) where.uid = this.cmd.nin(excludeUids);
    const r = await this.db.collection(COL.feedback).where(where).count();
    return r.total ?? 0;
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
