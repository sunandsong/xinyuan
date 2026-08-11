import { loadBlockwords, sanitizeNickname } from '../blockwords';
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
  const [top, me, words] = await Promise.all([
    db.topUsers(field, TOP_N),
    db.getProfile(uid),
    loadBlockwords(),
  ]);
  const mine = (me as any)?.[field] ?? 0;

  // 名次用 count 查「比我多的有几个」，不用把全表拉下来排
  const rank = mine > 0 ? (await db.countAbove(field, mine)) + 1 : null;

  return ok({
    by,
    // 榜单是所有登录用户都能看的，不返回账号名；uid 给出去是为了能点进详情页，
    // 详情接口（GET /users/:id）自己也只吐公开信息，不会因为这个多泄露什么
    top: top.map((u, i) => ({
      rank: i + 1,
      uid: u._id,
      nickname: sanitizeNickname(u.nickname || '匿名', u._id, words),
      avatarUrl: u.avatarUrl ?? null,
      gender: u.gender ?? null,
      count: (u as any)[field] ?? 0,
      isMe: u._id === uid,
    })),
    me: { rank, count: mine },
  });
}
