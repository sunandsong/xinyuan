// 测试用的内存假数据库。只实现被测代码真正用到的那几个方法，
// 其余的留 notImplemented——真被调到会直接炸，比返回空值悄悄让测试通过好。
//
// 查询条件用的是 CloudBase 那套「命令对象」（cmd.lt / cmd.neq / cmd.in / cmd.exists），
// 这里用带 __op 标记的普通对象模拟，matches() 负责解释它们。
import { Db, PublicUser } from '../src/db';

type Doc = Record<string, any>;

interface Cond {
  __op: 'lt' | 'neq' | 'in' | 'exists';
  v: any;
}

function isCond(x: any): x is Cond {
  return x !== null && typeof x === 'object' && typeof x.__op === 'string';
}

/** 一条文档是否命中 where。undefined 字段按「不存在」处理，跟 CloudBase 一致。 */
function matches(doc: Doc, where: Record<string, any>): boolean {
  for (const [k, expected] of Object.entries(where)) {
    const actual = doc[k];
    if (isCond(expected)) {
      switch (expected.__op) {
        case 'lt':
          if (!(typeof actual === 'number' && actual < expected.v)) return false;
          break;
        case 'neq':
          if (actual === expected.v) return false;
          break;
        case 'in':
          if (!Array.isArray(expected.v) || !expected.v.includes(actual)) return false;
          break;
        case 'exists':
          if ((actual !== undefined) !== expected.v) return false;
          break;
      }
    } else if (actual !== expected) {
      return false;
    }
  }
  return true;
}

function notImplemented(name: string): never {
  throw new Error(`FakeDb: ${name} 没实现——被测代码用到了它，需要在这里补上`);
}

export class FakeDb implements Db {
  /** 集合名 → 文档数组。文档必须带 _id。 */
  cols: Record<string, Doc[]>;
  /** 建过的集合名，用来断言 ensureCollection 有没有被调用 */
  ensured = new Set<string>();

  constructor(cols: Record<string, Doc[]> = {}) {
    this.cols = cols;
  }

  private col(name: string): Doc[] {
    if (!this.cols[name]) this.cols[name] = [];
    return this.cols[name];
  }

  count(name: string): number {
    return (this.cols[name] ?? []).length;
  }

  ids(name: string): string[] {
    return (this.cols[name] ?? []).map((d) => d._id);
  }

  // ---- 被测代码实际用到的 ----
  lt(value: number): unknown {
    return { __op: 'lt', v: value };
  }
  fieldMissing(): unknown {
    return { __op: 'exists', v: false };
  }

  async ensureCollection(name: string): Promise<void> {
    this.ensured.add(name);
    this.col(name);
  }

  async listDocs(
    name: string,
    opts: { skip?: number; limit?: number; where?: Record<string, unknown> } = {},
  ): Promise<{ items: any[]; total: number }> {
    const where = (opts.where ?? {}) as Record<string, any>;
    const hit = this.col(name).filter((d) => matches(d, where));
    const skip = opts.skip ?? 0;
    const limit = opts.limit ?? 20;
    return { items: hit.slice(skip, skip + limit), total: hit.length };
  }

  async removeWhere(
    name: string,
    where: Record<string, unknown>,
    limit: number,
  ): Promise<number> {
    const list = this.col(name);
    const doomed = list.filter((d) => matches(d, where as Record<string, any>)).slice(0, limit);
    const doomedIds = new Set(doomed.map((d) => d._id));
    this.cols[name] = list.filter((d) => !doomedIds.has(d._id));
    return doomed.length;
  }

  async upsertDoc(name: string, id: string | undefined, patch: Record<string, unknown>): Promise<string> {
    const list = this.col(name);
    if (id) {
      const i = list.findIndex((d) => d._id === id);
      // 真实 CloudDb 的这个分支走 .update()，文档不存在会失败——这里也照样报错，
      // 免得测试里能过、上了生产才发现（下载页快照第一版就踩过这个）
      if (i < 0) throw new Error(`FakeDb.upsertDoc: 文档 ${name}/${id} 不存在，update 不了`);
      list[i] = { ...list[i], ...patch };
      return id;
    }
    const newId = `gen_${name}_${list.length + 1}`;
    list.push({ _id: newId, ...patch });
    return newId;
  }

  async createDoc(name: string, id: string, doc: Record<string, unknown>): Promise<void> {
    const list = this.col(name);
    const i = list.findIndex((d) => d._id === id);
    const next = { _id: id, ...doc };
    if (i < 0) list.push(next);
    else list[i] = next; // .set() 是整份替换
  }

  async deleteDoc(name: string, id: string): Promise<void> {
    this.cols[name] = this.col(name).filter((d) => d._id !== id);
  }

  async hardDeleteUser(uid: string, account: string): Promise<void> {
    for (const c of ['wishes', 'tasks', 'letters', 'logins', 'events', 'feedback']) {
      this.cols[c] = this.col(c).filter((d) => d.uid !== uid);
    }
    // 崩溃记录只清归属字段，不整条删
    for (const d of this.col('crashes')) if (d.account === account) d.account = '';
    this.cols['deletion_requests'] = this.col('deletion_requests').filter((d) => d.uid !== uid);
    this.cols['users'] = this.col('users').filter((d) => d._id !== uid);
  }

  async softDeleteUser(uid: string): Promise<void> {
    const u = this.col('users').find((d) => d._id === uid);
    if (u) {
      u.deleted = true;
      u.deletedAt = Date.now();
    }
    for (const c of ['wishes', 'tasks', 'letters']) {
      for (const d of this.col(c)) if (d.uid === uid) d.deleted = true;
    }
  }

  // ---- 以下都没被测到，真调到就炸 ----
  getUserByAccount(): any { notImplemented('getUserByAccount'); }
  createUser(): any { notImplemented('createUser'); }
  getProfile(): any { notImplemented('getProfile'); }
  upsertProfile(): any { notImplemented('upsertProfile'); }
  pull(): any { notImplemented('pull'); }
  upsertWishes(): any { notImplemented('upsertWishes'); }
  upsertTasks(): any { notImplemented('upsertTasks'); }
  upsertLetters(): any { notImplemented('upsertLetters'); }
  createFeedback(): any { notImplemented('createFeedback'); }
  createShare(): any { notImplemented('createShare'); }
  getShareByCode(): any { notImplemented('getShareByCode'); }
  bumpShareViews(): any { notImplemented('bumpShareViews'); }
  topUsers(): any { notImplemented('topUsers'); }
  countAbove(): any { notImplemented('countAbove'); }
  topWishTitles(): any { notImplemented('topWishTitles'); }
  topPlaces(): any { notImplemented('topPlaces'); }
  usersWhoCompletedWish(): Promise<PublicUser[]> { notImplemented('usersWhoCompletedWish'); }
  wishTitleStats(): any { notImplemented('wishTitleStats'); }
  usersWhoCheckedIn(): Promise<PublicUser[]> { notImplemented('usersWhoCheckedIn'); }
  recordCrash(): any { notImplemented('recordCrash'); }
  allUsers(): any { notImplemented('allUsers'); }
  allWishes(): any { notImplemented('allWishes'); }
  allTasks(): any { notImplemented('allTasks'); }
  allLetters(): any { notImplemented('allLetters'); }
  allLogins(): any { notImplemented('allLogins'); }
  allEvents(): any { notImplemented('allEvents'); }
  countActive(): any { notImplemented('countActive'); }
  countFeedbackOpen(): any { notImplemented('countFeedbackOpen'); }
}
