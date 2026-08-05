import { getDb } from '../db';
import { bad, ok, Req } from '../http';

const TOP_N = 10;

/** 榜单类型 → 资料上对应的计数字段 */
const BOARDS: Record<string, string> = {
  wish: 'doneCount',   // 心愿实现数
  task: 'taskCount',   // 任务完成数
  achv: 'achvCount',   // 奖杯数
  place: 'placeCount', // 地图点亮数
};

/** GET /api/leaderboard?by=wish|task|achv|place —— 前 10 名 + 我的名次 */
export async function leaderboard(req: Req, uid: string) {
  const by = String(req.query.by ?? 'wish');
  const field = BOARDS[by];
  if (!field) return bad('invalid_board');

  const db = getDb();
  const [top, me] = await Promise.all([db.topUsers(field, TOP_N), db.getProfile(uid)]);
  const mine = (me as any)?.[field] ?? 0;

  // 名次用 count 查「比我多的有几个」，不用把全表拉下来排
  const rank = mine > 0 ? (await db.countAbove(field, mine)) + 1 : null;

  return ok({
    by,
    // 只给昵称和头像：榜单是所有登录用户都能看的，不返回账号名和 uid
    top: top.map((u, i) => ({
      rank: i + 1,
      nickname: u.nickname || '匿名',
      avatarUrl: u.avatarUrl ?? null,
      count: (u as any)[field] ?? 0,
      isMe: u._id === uid,
    })),
    me: { rank, count: mine },
  });
}
