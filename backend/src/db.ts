// 数据访问层：只有 CloudBase 文档库一套实现，所有数据都落云。
// 同步统一用 Last-Write-Wins（updatedAt 大者胜），软删除用 deleted 传播。

import { COL, ENV_ID } from './config';
import { Letter, PullResult, Share, Task, UserProfile, Wish } from './types';

export interface Db {
  getUserByAccount(account: string): Promise<UserProfile | null>;
  createUser(user: UserProfile): Promise<void>;
  getProfile(uid: string): Promise<UserProfile | null>;
  upsertProfile(uid: string, patch: Partial<UserProfile>): Promise<UserProfile>;

  pull(uid: string, since: number): Promise<PullResult>;
  upsertWishes(uid: string, items: Array<Partial<Wish> & { _id: string; updatedAt: number }>): Promise<void>;
  upsertTasks(uid: string, items: Array<Partial<Task> & { _id: string; updatedAt: number }>): Promise<void>;
  upsertLetters(uid: string, items: Array<Partial<Letter> & { _id: string; updatedAt: number }>): Promise<void>;

  createShare(share: Share): Promise<void>;
  getShareByCode(code: string): Promise<Share | null>;
  bumpShareViews(code: string): Promise<void>;

  softDeleteUser(uid: string): Promise<void>;
}

// CloudBase 文档库不允许 payload 含 _id（它是文档主键）
function noId<T extends Record<string, any>>(o: T): Omit<T, '_id'> {
  const { _id, ...rest } = o;
  return rest;
}

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
  async pull(uid: string, since: number): Promise<PullResult> {
    const [w, t, l, p] = await Promise.all([
      this.db.collection(COL.wishes).where({ uid, updatedAt: this.cmd.gt(since) }).limit(1000).get(),
      this.db.collection(COL.tasks).where({ uid, updatedAt: this.cmd.gt(since) }).limit(1000).get(),
      this.db.collection(COL.letters).where({ uid, updatedAt: this.cmd.gt(since) }).limit(1000).get(),
      this.getProfile(uid),
    ]);
    return { now: Date.now(), wishes: w.data ?? [], tasks: t.data ?? [], letters: l.data ?? [], profile: p };
  }
  /// 批量 upsert：先一次查出这批 id 里已存在的，再并发写。
  /// 原来是逐条 get 再 set，推 50 条要 100 次串行往返，云函数执行时间（按 GBs 计费）
  /// 和延迟都被这个循环吃掉了。现在是 1 次查 + N 次并发写。
  private async upsertAll(
    col: string,
    uid: string,
    items: Array<{ _id: string; updatedAt: number } & Record<string, any>>,
  ) {
    if (items.length === 0) return;
    const r = await this.db
      .collection(col)
      .where({ _id: this.cmd.in(items.map((i) => i._id)) })
      .limit(1000)
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
