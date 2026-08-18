// 数据留存清理：把过了保留期的记录物理删除。
//
// 这不是可有可无的运维脚本——隐私政策第七节对用户承诺了「保留一段时间后删除」，
// 《个人信息保护法》第十七/十九条也要求告知保存期限、且不得超过必要的最短时间。
// 没有这个任务，那段承诺就是空的。改这里的天数要同步改隐私政策的措辞，两边必须一致。
//
// 每天由定时触发器跑一次（见 index.ts 对 Timer 事件的分发）。
import { COL } from '../config';
import { getDb } from '../db';
import { ok, Req } from '../http';

/** 保留期（天）。跟隐私政策第七节写的数字必须一一对上。 */
export const RETENTION = {
  /** 登录日志（含 IP、设备型号）：安全审计用，过期就没有排查价值了 */
  loginDays: 90,
  /** 行为埋点：看功能使用趋势，不需要更久 */
  eventDays: 90,
  /** 崩溃记录：按末次发生时间算，要留够跨版本对比的历史 */
  crashDays: 180,
  /** 已处理的意见反馈：万一有纠纷要回溯。未处理的不清，留到处理完为止 */
  handledFeedbackDays: 365,
  /** 注销用户的保留期：满了物理删除全部关联数据。
   * 跟网页注销页对外承诺的「30 天内完成」对齐，同时给误操作留后悔余地。 */
  deletedUserGraceDays: 30,
};

const DAY = 86_400_000;

/** 每次运行每类最多删这么多条。云函数超时只有 20 秒，宁可分几天删完，
 * 也不要一次性删爆——清理是天天跑的，积压自然会被追平。 */
const MAX_PER_RUN = 300;
/** 每次最多物理删除几个到期用户（一个用户要连带清好几张表，比单表删贵得多） */
const MAX_USERS_PER_RUN = 20;

export interface CleanupResult {
  logins: number;
  events: number;
  crashes: number;
  feedback: number;
  purgedUsers: number;
  /** 补盖 deletedAt 的老数据条数（早期注销的用户没有这个字段，见下） */
  stampedUsers: number;
}

/** 跑一遍清理。任何一步失败都不抛出——清理任务挂掉不该影响别的，
 * 而且下次还会再跑一遍，漏删的下次补上。 */
export async function runCleanup(): Promise<CleanupResult> {
  const db = getDb();
  const now = Date.now();
  const res: CleanupResult = {
    logins: 0,
    events: 0,
    crashes: 0,
    feedback: 0,
    purgedUsers: 0,
    stampedUsers: 0,
  };

  // ---- 按时间戳过期的四类记录 ----
  res.logins = await db.removeWhere(
    COL.logins,
    { at: db.lt(now - RETENTION.loginDays * DAY) },
    MAX_PER_RUN,
  );
  res.events = await db.removeWhere(
    COL.events,
    { at: db.lt(now - RETENTION.eventDays * DAY) },
    MAX_PER_RUN,
  );
  // 崩溃按 lastAt（末次发生）算：还在持续发生的 bug 不该因为首次很久以前就被清掉
  res.crashes = await db.removeWhere(
    COL.crashes,
    { lastAt: db.lt(now - RETENTION.crashDays * DAY) },
    MAX_PER_RUN,
  );
  // 只清已处理的：没处理完的留着，否则等于把还没回复的用户意见删了
  res.feedback = await db.removeWhere(
    COL.feedback,
    { handled: true, createdAt: db.lt(now - RETENTION.handledFeedbackDays * DAY) },
    MAX_PER_RUN,
  );

  // ---- 注销满保留期的用户：物理删除 ----
  try {
    // 早期注销的记录没有 deletedAt（这个字段是 2026-08-18 才加的）。
    // 不能当成「很久以前删的」直接清掉——那等于跳过保留期。补盖成当下，
    // 让它们从现在开始重新计时，方向上偏保守。
    const legacy = await db.listDocs(COL.users, {
      where: { deleted: true, deletedAt: db.fieldMissing() },
      limit: MAX_PER_RUN,
    });
    for (const u of legacy.items) {
      if (u.deletedAt) continue;
      await db.upsertDoc(COL.users, u._id, { deletedAt: now });
      res.stampedUsers++;
    }
  } catch {}

  try {
    const due = await db.listDocs(COL.users, {
      where: { deleted: true, deletedAt: db.lt(now - RETENTION.deletedUserGraceDays * DAY) },
      limit: MAX_USERS_PER_RUN,
    });
    for (const u of due.items) {
      await db.hardDeleteUser(u._id, String(u.account ?? ''));
      res.purgedUsers++;
    }
  } catch {}

  return res;
}

/** POST /admin/cleanup —— 手动跑一次（定时任务之外的应急/验证入口） */
export async function cleanupNow(_req: Req) {
  const result = await runCleanup();
  return ok({ ...result, retention: RETENTION });
}
