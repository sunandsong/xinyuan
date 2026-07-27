// 数据访问层：mock（内存）与 cloud（CloudBase 文档库）两套实现，同一接口。
// 同步统一用 Last-Write-Wins（updatedAt 大者胜），软删除用 deleted 传播。

import { COL, ENV_ID, IS_MOCK } from './config';
import { EmailCode, PullResult, Share, Task, UserProfile, Wish } from './types';

export interface Db {
  getUserByEmail(email: string): Promise<UserProfile | null>;
  createUser(user: UserProfile): Promise<void>;
  getProfile(uid: string): Promise<UserProfile | null>;
  upsertProfile(uid: string, patch: Partial<UserProfile>): Promise<UserProfile>;

  getEmailCode(email: string, purpose: string): Promise<EmailCode | null>;
  saveEmailCode(rec: EmailCode): Promise<void>;
  deleteEmailCode(email: string, purpose: string): Promise<void>;

  pull(uid: string, since: number): Promise<PullResult>;
  upsertWishes(uid: string, items: Array<Partial<Wish> & { _id: string; updatedAt: number }>): Promise<void>;
  upsertTasks(uid: string, items: Array<Partial<Task> & { _id: string; updatedAt: number }>): Promise<void>;

  createShare(share: Share): Promise<void>;
  getShareByCode(code: string): Promise<Share | null>;
  bumpShareViews(code: string): Promise<void>;

  softDeleteUser(uid: string): Promise<void>;
}

// ---------------- mock（内存，供本地开发/测试，不消耗云额度）----------------
class MockDb implements Db {
  private profiles = new Map<string, UserProfile>();
  private wishes: Wish[] = [];
  private tasks: Task[] = [];
  private shares: Share[] = [];
  private emailCodes = new Map<string, EmailCode>();

  async getUserByEmail(email: string) {
    for (const u of this.profiles.values()) if (u.email === email && !u.deleted) return u;
    return null;
  }
  async createUser(user: UserProfile) {
    this.profiles.set(user._id, user);
  }
  async getProfile(uid: string) {
    return this.profiles.get(uid) ?? null;
  }
  async upsertProfile(uid: string, patch: Partial<UserProfile>) {
    const now = Date.now();
    const cur =
      this.profiles.get(uid) ??
      ({
        _id: uid,
        email: patch.email ?? `${uid}@mock.local`,
        nickname: '我',
        avatarEmoji: null,
        createdAt: now,
        updatedAt: now,
      } as UserProfile);
    const next = { ...cur, ...patch, _id: uid, updatedAt: now };
    this.profiles.set(uid, next);
    return next;
  }
  async getEmailCode(email: string, purpose: string) {
    return this.emailCodes.get(`${purpose}:${email}`) ?? null;
  }
  async saveEmailCode(rec: EmailCode) {
    this.emailCodes.set(`${rec.purpose}:${rec.email}`, rec);
  }
  async deleteEmailCode(email: string, purpose: string) {
    this.emailCodes.delete(`${purpose}:${email}`);
  }
  async pull(uid: string, since: number): Promise<PullResult> {
    return {
      now: Date.now(),
      wishes: this.wishes.filter((w) => w.uid === uid && w.updatedAt > since),
      tasks: this.tasks.filter((t) => t.uid === uid && t.updatedAt > since),
      profile: this.profiles.get(uid) ?? null,
    };
  }
  async upsertWishes(uid: string, items: Array<Partial<Wish> & { _id: string; updatedAt: number }>) {
    for (const it of items) {
      const i = this.wishes.findIndex((w) => w._id === it._id && w.uid === uid);
      if (i < 0) {
        this.wishes.push({ ...(it as Wish), uid });
      } else if (it.updatedAt >= this.wishes[i].updatedAt) {
        this.wishes[i] = { ...this.wishes[i], ...it, uid };
      }
    }
  }
  async upsertTasks(uid: string, items: Array<Partial<Task> & { _id: string; updatedAt: number }>) {
    for (const it of items) {
      const i = this.tasks.findIndex((t) => t._id === it._id && t.uid === uid);
      if (i < 0) {
        this.tasks.push({ ...(it as Task), uid });
      } else if (it.updatedAt >= this.tasks[i].updatedAt) {
        this.tasks[i] = { ...this.tasks[i], ...it, uid };
      }
    }
  }
  async createShare(share: Share) {
    this.shares.push(share);
  }
  async getShareByCode(code: string) {
    return this.shares.find((s) => s.code === code) ?? null;
  }
  async bumpShareViews(code: string) {
    const s = this.shares.find((x) => x.code === code);
    if (s) s.views += 1;
  }
  async softDeleteUser(uid: string) {
    const p = this.profiles.get(uid);
    if (p) p.deleted = true;
    this.wishes.forEach((w) => w.uid === uid && (w.deleted = true));
    this.tasks.forEach((t) => t.uid === uid && (t.deleted = true));
  }
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

  async getUserByEmail(email: string): Promise<UserProfile | null> {
    const r = await this.db.collection(COL.users).where({ email }).limit(1).get();
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
        email: patch.email ?? '',
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
  async getEmailCode(email: string, purpose: string): Promise<EmailCode | null> {
    const r = await this.db.collection(COL.emailCodes).where({ email, purpose }).limit(1).get();
    return r.data?.[0] ?? null;
  }
  async saveEmailCode(rec: EmailCode) {
    const exist = await this.getEmailCode(rec.email, rec.purpose);
    if (exist) {
      await this.db.collection(COL.emailCodes).where({ email: rec.email, purpose: rec.purpose }).update(noId(rec));
    } else {
      await this.db.collection(COL.emailCodes).add(noId(rec));
    }
  }
  async deleteEmailCode(email: string, purpose: string) {
    await this.db.collection(COL.emailCodes).where({ email, purpose }).remove();
  }
  async pull(uid: string, since: number): Promise<PullResult> {
    const [w, t, p] = await Promise.all([
      this.db.collection(COL.wishes).where({ uid, updatedAt: this.cmd.gt(since) }).limit(1000).get(),
      this.db.collection(COL.tasks).where({ uid, updatedAt: this.cmd.gt(since) }).limit(1000).get(),
      this.getProfile(uid),
    ]);
    return { now: Date.now(), wishes: w.data ?? [], tasks: t.data ?? [], profile: p };
  }
  async upsertWishes(uid: string, items: Array<Partial<Wish> & { _id: string; updatedAt: number }>) {
    for (const it of items) {
      const cur = await this.db.collection(COL.wishes).doc(it._id).get();
      const exist: Wish | undefined = cur.data?.[0];
      if (!exist) {
        await this.db.collection(COL.wishes).doc(it._id).set(noId({ ...it, uid }));
      } else if (exist.uid === uid && it.updatedAt >= exist.updatedAt) {
        await this.db.collection(COL.wishes).doc(it._id).update(noId({ ...it, uid }));
      }
    }
  }
  async upsertTasks(uid: string, items: Array<Partial<Task> & { _id: string; updatedAt: number }>) {
    for (const it of items) {
      const cur = await this.db.collection(COL.tasks).doc(it._id).get();
      const exist: Task | undefined = cur.data?.[0];
      if (!exist) {
        await this.db.collection(COL.tasks).doc(it._id).set(noId({ ...it, uid }));
      } else if (exist.uid === uid && it.updatedAt >= exist.updatedAt) {
        await this.db.collection(COL.tasks).doc(it._id).update(noId({ ...it, uid }));
      }
    }
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
    ]);
  }
}

let _db: Db | null = null;
export function getDb(): Db {
  if (!_db) _db = IS_MOCK ? new MockDb() : new CloudDb();
  return _db;
}
